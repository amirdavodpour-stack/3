import { requirePool } from './context.js';
import { withSqlTransaction } from '../db.js';

const SUPPORT_WINDOW_DAYS = 30;
const CONTENT_RETENTION_MONTHS = 24;
const MAX_DRY_RUN_LIMIT = 1000;
const RETENTION_CURSOR_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TERMINAL_JOB_STATUSES = new Set(['COMPLETED','CANCELLED']);

const iso = (value) => value == null
  ? null
  : (value instanceof Date ? value : new Date(value)).toISOString();

function decodeRetentionCursor(value) {
  if (value == null || value === '') return null;
  const invalid = () => {
    const error = new TypeError('cursor must be a valid retention cursor token');
    error.code = 'INVALID_RETENTION_CURSOR';
    return error;
  };
  if (typeof value !== 'string' || value.length > 1024 || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw invalid();
  }
  try {
    const bytes = Buffer.from(value,'base64url');
    if (bytes.toString('base64url') !== value) throw invalid();
    const parsed = JSON.parse(bytes.toString('utf8'));
    if (!parsed || typeof parsed.createdAt !== 'string' || !Number.isFinite(Date.parse(parsed.createdAt)) ||
        typeof parsed.id !== 'string' || !RETENTION_CURSOR_UUID.test(parsed.id)) throw invalid();
    return { createdAt: parsed.createdAt, id: parsed.id };
  } catch (error) {
    if (error?.code === 'INVALID_RETENTION_CURSOR') throw error;
    throw invalid();
  }
}

function encodeRetentionCursor(row) {
  return Buffer.from(JSON.stringify({
    createdAt: row.cursor_created_at,
    id: row.conversation_id,
  }), 'utf8').toString('base64url');
}
function classifyConversation(row, asOf) {
  const terminalAt = row.terminal_at ? new Date(row.terminal_at) : null;
  const supportWindowEndsAt = row.support_window_ends_at
    ? new Date(row.support_window_ends_at)
    : null;
  const closedAt = row.closed_at ? new Date(row.closed_at) : null;
  const contentPurgeAfter = row.content_purge_after
    ? new Date(row.content_purge_after)
    : null;
  const jobStatus = String(row.job_status || '').toUpperCase();
  const conversationStatus = String(row.conversation_status || '').toUpperCase();
  const activeDisputeCount = Number(row.active_dispute_count || 0);
  const activeLegalHoldCount = Number(row.active_legal_hold_count || 0);
  const chatAttachmentCount = Number(row.chat_attachment_count || 0);
  const purgeableChatAttachmentCount = Number(row.purgeable_chat_attachment_count || 0);
  const evidenceReferencedAttachmentCount = Number(row.evidence_referenced_attachment_count || 0);

  let action;
  let reason;

  if (conversationStatus === 'OPEN') {
    if (!terminalAt) {
      action = 'BLOCKED_MISSING_TERMINAL_TIMESTAMP';
      reason = 'A real COMPLETED/CANCELLED transition timestamp is missing; updated_at is not used as a substitute.';
    } else if (!TERMINAL_JOB_STATUSES.has(jobStatus)) {
      action = 'BLOCKED_JOB_NOT_TERMINAL';
      reason = 'The linked job is not in a terminal status.';
    } else if (row.terminal_event !== jobStatus) {
      action = 'BLOCKED_TERMINAL_EVENT_MISMATCH';
      reason = 'The recorded terminal event does not match the linked job status.';
    } else if (activeDisputeCount > 0) {
      action = 'BLOCKED_OPEN_DISPUTE';
      reason = 'At least one linked dispute is not finally resolved.';
    } else if (activeLegalHoldCount > 0) {
      action = 'BLOCKED_LEGAL_HOLD';
      reason = 'At least one active legal or administrator preservation hold exists.';
    } else if (asOf < supportWindowEndsAt) {
      action = 'SUPPORT_WINDOW_ACTIVE';
      reason = 'The 30-calendar-day post-terminal support window has not elapsed.';
    } else {
      action = 'WOULD_CLOSE';
      reason = 'The terminal timestamp is explicit, the support window elapsed, and no dispute or legal hold blocks closure.';
    }
  } else if (conversationStatus === 'CLOSED') {
    if (!closedAt) {
      action = 'BLOCKED_MISSING_CLOSED_AT';
      reason = 'The closed conversation has no authoritative closed_at timestamp.';
    } else if (activeDisputeCount > 0) {
      action = 'BLOCKED_OPEN_DISPUTE';
      reason = 'At least one linked dispute is not finally resolved.';
    } else if (activeLegalHoldCount > 0) {
      action = 'BLOCKED_LEGAL_HOLD';
      reason = 'At least one active legal or administrator preservation hold exists.';
    } else if (!contentPurgeAfter) {
      action = 'BLOCKED_MISSING_RETENTION_CLOCK';
      reason = 'The content-retention clock cannot be calculated from authoritative closure, dispute-resolution and hold-release timestamps.';
    } else if (asOf < contentPurgeAfter) {
      action = 'CONTENT_RETENTION_ACTIVE';
      reason = 'The 24-month content-retention period after the latest closure, final dispute resolution or legal-hold release event has not elapsed.';
    } else {
      action = 'WOULD_PURGE_CONTENT';
      reason = 'The 24-month content-retention period elapsed. Message bodies and unreferenced chat attachments are candidates; evidence-linked attachment objects remain protected.';
    }
  } else {
    action = 'BLOCKED_UNSUPPORTED_CONVERSATION_STATE';
    reason = 'Only OPEN and CLOSED job conversations participate in this retention policy.';
  }

  return {
    conversationId: row.conversation_id,
    jobId: row.job_id,
    conversationStatus,
    jobStatus,
    terminalAt: iso(terminalAt),
    terminalEvent: row.terminal_event || null,
    supportWindowEndsAt: iso(supportWindowEndsAt),
    closedAt: iso(closedAt),
    contentPurgeAfter: iso(contentPurgeAfter),
    activeDisputeCount,
    latestDisputeResolvedAt: iso(row.latest_dispute_resolved_at),
    activeLegalHoldCount,
    latestLegalHoldReleasedAt: iso(row.latest_legal_hold_released_at),
    chatAttachmentCount,
    purgeableChatAttachmentCount,
    evidenceReferencedAttachmentCount,
    evidenceObjectPurgeBlocked: evidenceReferencedAttachmentCount > 0,
    messageBodiesWouldBePurged: action === 'WOULD_PURGE_CONTENT',
    unreferencedChatAttachmentsWouldBePurged: action === 'WOULD_PURGE_CONTENT'
      ? purgeableChatAttachmentCount
      : 0,
    action,
    reason,
  };
}

/**
 * Read-only retention planner. It never closes a conversation, mutates a row,
 * claims work, or calls an object-storage provider.
 */
export async function buildChatRetentionDryRun({
  asOf = new Date(),
  limit = 200,
  cursor = null,
} = {}) {
  const asOfDate = asOf instanceof Date ? new Date(asOf.getTime()) : new Date(asOf);
  if (!Number.isFinite(asOfDate.getTime())) {
    throw new TypeError('asOf must be a valid Date or ISO-8601 timestamp');
  }

  const requestedLimit = Number(limit);
  if (!Number.isFinite(requestedLimit) || requestedLimit < 1) {
    throw new TypeError('limit must be a positive integer');
  }
  const safeLimit = Math.min(MAX_DRY_RUN_LIMIT, Math.floor(requestedLimit));
  const decodedCursor = decodeRetentionCursor(cursor);
  const pool = requirePool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    const { rows: totalRows } = await client.query(`
      SELECT COUNT(*)::int AS total
        FROM chat_conversations c
        JOIN jobs j ON j.id=c.job_id
       WHERE c.kind='JOB'
    `);
    const totalCount = Number(totalRows[0]?.total || 0);
    const { rows } = await client.query(`
      SELECT
        c.id AS conversation_id,
        c.created_at::text AS cursor_created_at,
        c.job_id,
        c.status AS conversation_status,
        c.terminal_at,
        c.terminal_event,
        c.closed_at,
        j.status AS job_status,
        CASE
          WHEN c.terminal_at IS NULL THEN NULL
          ELSE c.terminal_at + INTERVAL '30 days'
        END AS support_window_ends_at,
        CASE
          WHEN c.closed_at IS NULL THEN NULL
          ELSE GREATEST(
            c.closed_at,
            COALESCE(disputes.latest_resolved_at,c.closed_at),
            COALESCE(holds.latest_released_at,c.closed_at)
          ) + INTERVAL '24 months'
        END AS content_purge_after,
        COALESCE(disputes.active_dispute_count,0)::int AS active_dispute_count,
        disputes.latest_resolved_at AS latest_dispute_resolved_at,
        COALESCE(holds.active_legal_hold_count,0)::int AS active_legal_hold_count,
        holds.latest_released_at AS latest_legal_hold_released_at,
        COALESCE(attachments.chat_attachment_count,0)::int AS chat_attachment_count,
        COALESCE(attachments.purgeable_chat_attachment_count,0)::int
          AS purgeable_chat_attachment_count,
        COALESCE(attachments.evidence_referenced_attachment_count,0)::int
          AS evidence_referenced_attachment_count
      FROM chat_conversations c
      JOIN jobs j ON j.id=c.job_id
      LEFT JOIN LATERAL (
        SELECT
          COUNT(*) FILTER (
            WHERE status <> 'RESOLVED' OR resolved_at IS NULL
          ) AS active_dispute_count,
          MAX(resolved_at) FILTER (
            WHERE status='RESOLVED' AND resolved_at IS NOT NULL
          ) AS latest_resolved_at
        FROM job_disputes
        WHERE job_id=c.job_id
      ) disputes ON TRUE
      LEFT JOIN LATERAL (
        SELECT
          COUNT(*) FILTER (WHERE released_at IS NULL) AS active_legal_hold_count,
          MAX(released_at) AS latest_released_at
        FROM chat_conversation_legal_holds
        WHERE conversation_id=c.id
      ) holds ON TRUE
      LEFT JOIN LATERAL (
        SELECT
          COUNT(DISTINCT a.id) AS chat_attachment_count,
          COUNT(DISTINCT a.id) FILTER (WHERE e.id IS NULL)
            AS purgeable_chat_attachment_count,
          COUNT(DISTINCT a.id) FILTER (WHERE e.id IS NOT NULL)
            AS evidence_referenced_attachment_count
        FROM chat_messages m
        JOIN chat_message_attachments a ON a.message_id=m.id
        LEFT JOIN evidence e ON e.uri=('storage://' || a.storage_key)
        WHERE m.conversation_id=c.id
      ) attachments ON TRUE
      WHERE c.kind='JOB'
        AND ($2::timestamptz IS NULL OR (c.created_at,c.id) > ($2::timestamptz,$3::uuid))
      ORDER BY c.created_at ASC,c.id ASC
      LIMIT $1
    `, [safeLimit + 1, decodedCursor?.createdAt ?? null, decodedCursor?.id ?? null]);

    const hasMore = rows.length > safeLimit;
    const pageRows = hasMore ? rows.slice(0,safeLimit) : rows;
    const items = pageRows.map((row) => classifyConversation(row, asOfDate));
    const summary = {};
    for (const item of items) {
      summary[item.action] = (summary[item.action] || 0) + 1;
    }
    const nextCursor = hasMore && pageRows.length
      ? encodeRetentionCursor(pageRows[pageRows.length - 1])
      : null;

    await client.query('COMMIT');
    return {
      mode: 'DRY_RUN',
      asOf: asOfDate.toISOString(),
      limit: safeLimit,
      scanned: items.length,
      totalCount,
      hasMore,
      nextCursor,
      pageComplete: !hasMore,
      inventoryComplete: !decodedCursor && !hasMore,
      cursorProvided: Boolean(decodedCursor),
      policy: {
        supportWindowDays: SUPPORT_WINDOW_DAYS,
        contentRetentionMonths: CONTENT_RETENTION_MONTHS,
      },
      wouldMutate: false,
      mutationCount: 0,
      providerDeleteCalls: 0,
      summary,
      items,
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

const CHAT_RETENTION_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function legalHoldView(row) {
  if (!row) return null;
  return {
    id: row.id,
    conversationId: row.conversation_id,
    holdKind: row.hold_kind,
    reason: row.reason,
    createdBy: row.created_by,
    createdAt: iso(row.created_at),
    releasedBy: row.released_by,
    releasedAt: iso(row.released_at),
    releaseReason: row.release_reason,
  };
}

/**
 * Create a durable preservation hold on a JOB conversation.
 * Lock order is conversation first, then its hold rows; future close/purge
 * workers must use the same order before making any retention transition.
 */
export async function createChatConversationLegalHold({
  conversationId,
  holdKind,
  reason,
  createdBy,
} = {}) {
  const id = String(conversationId ?? '').trim();
  const kind = String(holdKind ?? '').trim().toUpperCase();
  const why = String(reason ?? '').trim();
  const actor = String(createdBy ?? '').trim();
  if (!CHAT_RETENTION_UUID.test(id)) throw new TypeError('conversationId must be a UUID');
  if (!['LEGAL','ADMIN'].includes(kind)) throw new TypeError('holdKind must be LEGAL or ADMIN');
  if (!why || why.length > 1000) throw new TypeError('reason must contain between 1 and 1000 characters');
  if (!CHAT_RETENTION_UUID.test(actor)) throw new TypeError('createdBy must be a UUID');

  return withSqlTransaction(async (client) => {
    const { rows: conversations } = await client.query(
      `SELECT id FROM chat_conversations
        WHERE id=$1 AND kind='JOB'
        FOR UPDATE`,
      [id],
    );
    if (!conversations[0]) return null;

    const { rows } = await client.query(
      `INSERT INTO chat_conversation_legal_holds(
         id,conversation_id,hold_kind,reason,created_by
       )
       VALUES(gen_random_uuid(),$1,$2,$3,$4)
       RETURNING *`,
      [id,kind,why,actor],
    );
    return legalHoldView(rows[0]);
  });
}

/**
 * Release a preservation hold with an auditable actor and reason.
 * The initial lookup is deliberately unlocked; the transaction then locks
 * conversation -> hold, matching creation and future lifecycle workers.
 */
export async function releaseChatConversationLegalHold({
  holdId,
  releasedBy,
  releaseReason,
} = {}) {
  const id = String(holdId ?? '').trim();
  const actor = String(releasedBy ?? '').trim();
  const why = String(releaseReason ?? '').trim();
  if (!CHAT_RETENTION_UUID.test(id)) throw new TypeError('holdId must be a UUID');
  if (!CHAT_RETENTION_UUID.test(actor)) throw new TypeError('releasedBy must be a UUID');
  if (!why || why.length > 1000) throw new TypeError('releaseReason must contain between 1 and 1000 characters');

  return withSqlTransaction(async (client) => {
    const { rows: references } = await client.query(
      'SELECT conversation_id FROM chat_conversation_legal_holds WHERE id=$1',
      [id],
    );
    const conversationId = references[0]?.conversation_id;
    if (!conversationId) return null;

    const { rows: conversations } = await client.query(
      `SELECT id FROM chat_conversations
        WHERE id=$1 AND kind='JOB'
        FOR UPDATE`,
      [conversationId],
    );
    if (!conversations[0]) return null;

    const { rows: holds } = await client.query(
      `SELECT * FROM chat_conversation_legal_holds
        WHERE id=$1 AND conversation_id=$2
        FOR UPDATE`,
      [id,conversationId],
    );
    const hold = holds[0];
    if (!hold) return null;
    if (hold.released_at) {
      const error = new Error('CHAT_LEGAL_HOLD_ALREADY_RELEASED');
      error.code = 'CHAT_LEGAL_HOLD_ALREADY_RELEASED';
      error.status = 409;
      throw error;
    }

    const { rows } = await client.query(
      `UPDATE chat_conversation_legal_holds
          SET released_by=$2,
              released_at=NOW(),
              release_reason=$3
        WHERE id=$1 AND released_at IS NULL
        RETURNING *`,
      [id,actor,why],
    );
    return legalHoldView(rows[0]);
  });
}
