import { requirePool } from './context.js';

const SUPPORT_WINDOW_DAYS = 30;
const CONTENT_RETENTION_MONTHS = 24;
const MAX_DRY_RUN_LIMIT = 1000;
const TERMINAL_JOB_STATUSES = new Set(['COMPLETED','CANCELLED']);

const iso = (value) => value == null
  ? null
  : (value instanceof Date ? value : new Date(value)).toISOString();

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
  const pool = requirePool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    const { rows } = await client.query(`
      SELECT
        c.id AS conversation_id,
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
      ORDER BY c.created_at ASC,c.id ASC
      LIMIT $1
    `, [safeLimit]);

    const items = rows.map((row) => classifyConversation(row, asOfDate));
    const summary = {};
    for (const item of items) {
      summary[item.action] = (summary[item.action] || 0) + 1;
    }

    await client.query('COMMIT');
    return {
      mode: 'DRY_RUN',
      asOf: asOfDate.toISOString(),
      limit: safeLimit,
      scanned: items.length,
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
