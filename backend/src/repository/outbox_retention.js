import { requirePool } from './context.js';
import { withSqlTransaction } from '../db.js';
import { lockAuthorizedAdminActor } from './admin_authorization.js';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HOLD_KINDS = new Set(['LEGAL','ADMIN']);
const AGGREGATE_TYPES = new Set(['notification','payment','payout','user','outbox_event']);
const REASON_CODES = new Set([
  'LEGAL_REQUEST',
  'COURT_ORDER',
  'REGULATORY_REQUEST',
  'DISPUTE',
  'FRAUD_REVIEW',
  'SECURITY_INCIDENT',
  'AUDIT_REQUEST',
  'ADMIN_REVIEW',
  'INVESTIGATION',
  'CASE_CLOSED',
  'HOLD_SCOPE_CHANGED',
]);
const FINANCIAL_EVENT_TYPES = new Set([
  'PAYMENT_CREATE_HOLD',
  'PAYMENT_RELEASE',
  'PAYMENT_REFUND',
  'PAYOUT_EXECUTE',
]);

function fail(code, message, status = 400) {
  const error = new Error(message);
  error.code = code;
  error.status = status;
  throw error;
}

function requireUuid(value, field) {
  const normalized = String(value ?? '').trim();
  if (!UUID_PATTERN.test(normalized)) fail('INVALID_RETENTION_TARGET', `${field} must be a UUID`);
  return normalized;
}

function normalizeReasonCode(value) {
  const code = String(value ?? '').trim().toUpperCase();
  if (!REASON_CODES.has(code)) fail('INVALID_RETENTION_REASON_CODE', 'A supported reason code is required');
  return code;
}

function normalizeHoldKind(value) {
  const kind = String(value ?? '').trim().toUpperCase();
  if (!HOLD_KINDS.has(kind)) fail('INVALID_RETENTION_HOLD_KIND', 'Hold kind must be LEGAL or ADMIN');
  return kind;
}

function normalizeTarget(target = {}) {
  const kind = String(target.kind ?? '').trim().toUpperCase();
  if (kind === 'EVENT') {
    return { kind, eventId:requireUuid(target.eventId,'eventId') };
  }
  if (kind === 'AGGREGATE') {
    const aggregateType = String(target.aggregateType ?? '').trim().toLowerCase();
    if (!AGGREGATE_TYPES.has(aggregateType)) fail('INVALID_RETENTION_TARGET', 'Unsupported aggregate type');
    return {
      kind,
      aggregateType,
      aggregateId:requireUuid(target.aggregateId,'aggregateId'),
    };
  }
  fail('INVALID_RETENTION_TARGET', 'Target kind must be EVENT or AGGREGATE');
}

function retentionTargetError() {
  return Object.assign(new Error('OUTBOX_RETENTION_TARGET_NOT_FOUND'), {
    code:'OUTBOX_RETENTION_TARGET_NOT_FOUND',
    status:404,
  });
}

async function acquireOutboxRetentionLocksWithClient(client, {
  eventId = null,
  aggregateType = null,
  aggregateId = null,
} = {}) {
  const keys = [];
  if (aggregateType && aggregateId) {
    keys.push(`hopev2:outbox-retention:aggregate:${aggregateType}:${aggregateId}`);
  }
  if (eventId) keys.push(`hopev2:outbox-retention:event:${eventId}`);
  // Every caller acquires aggregate before event. Transaction-scoped advisory
  // locks serialize new holds with any future archive/purge/tombstone gate.
  for (const key of keys) {
    await client.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [key]);
  }
}

async function findOutboxEventIdentityWithClient(client, eventId) {
  const { rows } = await client.query(
    `SELECT event_type,aggregate_type,aggregate_id
       FROM outbox_events
      WHERE id=$1
     UNION ALL
     SELECT event_type,aggregate_type,aggregate_id
       FROM outbox_dedupe_registry
      WHERE original_event_id=$1
      LIMIT 1`,
    [eventId],
  );
  return rows[0] || null;
}

async function aggregateTargetExistsWithClient(client, aggregateType, aggregateId) {
  const { rows } = await client.query(
    `SELECT EXISTS(
       SELECT 1 FROM outbox_events
        WHERE aggregate_type=$1 AND aggregate_id=$2
       UNION ALL
       SELECT 1 FROM outbox_dedupe_registry
        WHERE aggregate_type=$1 AND aggregate_id=$2
     ) AS exists`,
    [aggregateType,aggregateId],
  );
  return rows[0]?.exists === true;
}

/**
 * Resolve immutable target identity, acquire aggregate then event advisory
 * locks, and revalidate after waiting. Hold creation and every future
 * candidate/archive/purge caller must use this same gate.
 */
async function requireReadCommittedRetentionGate(client) {
  const { rows } = await client.query(
    "SELECT current_setting('transaction_isolation') AS isolation_level",
  );
  if (String(rows[0]?.isolation_level || '').toLowerCase() !== 'read committed') {
    fail(
      'OUTBOX_RETENTION_GATE_REQUIRES_READ_COMMITTED',
      'Outbox hold candidate gates require READ COMMITTED so advisory-lock waits cannot reuse a stale snapshot',
      409,
    );
  }
}

export async function lockOutboxRetentionTargetWithClient(client, target) {
  await requireReadCommittedRetentionGate(client);
  const normalized = normalizeTarget(target);
  if (normalized.kind === 'EVENT') {
    const before = await findOutboxEventIdentityWithClient(client,normalized.eventId);
    if (!before) throw retentionTargetError();
    const aggregateType = String(before.aggregate_type || '');
    const aggregateId = before.aggregate_id == null ? null : String(before.aggregate_id);
    await acquireOutboxRetentionLocksWithClient(client,{
      eventId:normalized.eventId,
      aggregateType,
      aggregateId,
    });
    const after = await findOutboxEventIdentityWithClient(client,normalized.eventId);
    if (
      !after
      || String(after.event_type) !== String(before.event_type)
      || String(after.aggregate_type) !== aggregateType
      || String(after.aggregate_id ?? '') !== String(aggregateId ?? '')
    ) {
      throw retentionTargetError();
    }
    return {
      kind:'EVENT',
      eventId:normalized.eventId,
      eventType:String(after.event_type),
      aggregateType,
      aggregateId,
    };
  }

  const existsBefore = await aggregateTargetExistsWithClient(
    client,normalized.aggregateType,normalized.aggregateId,
  );
  if (!existsBefore) throw retentionTargetError();
  await acquireOutboxRetentionLocksWithClient(client,{
    aggregateType:normalized.aggregateType,
    aggregateId:normalized.aggregateId,
  });
  const existsAfter = await aggregateTargetExistsWithClient(
    client,normalized.aggregateType,normalized.aggregateId,
  );
  if (!existsAfter) throw retentionTargetError();
  return normalized;
}

async function requireWriteAdminWithClient(client, { actorId, sessionJti } = {}) {
  const actor = requireUuid(actorId,'actorId');
  await lockAuthorizedAdminActor(client,{
    actorId:actor,
    sessionJti,
    verificationMinutes:5,
    requiredScope:'WRITE',
    requireStepUp:true,
  });
  return actor;
}

function holdView(row) {
  return {
    id:String(row.id),
    targetKind:row.target_kind,
    holdKind:row.hold_kind,
    reasonCode:row.reason_code,
    createdAt:row.created_at?.toISOString?.() ?? row.created_at,
  };
}

export async function createOutboxRetentionHoldWithClient(client, {
  actorId,
  sessionJti,
  target,
  holdKind,
  reasonCode,
} = {}) {
  const actor = await requireWriteAdminWithClient(client,{actorId,sessionJti});
  const kind = normalizeHoldKind(holdKind);
  const reason = normalizeReasonCode(reasonCode);
  const identity = await lockOutboxRetentionTargetWithClient(client,target);
  const { rows } = await client.query(
    `INSERT INTO outbox_retention_holds(
       id,target_kind,event_id,aggregate_type,aggregate_id,hold_kind,reason_code,created_by,created_at
     )
     VALUES(
       gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,NOW()
     )
     RETURNING id,target_kind,hold_kind,reason_code,created_at`,
    [
      identity.kind,
      identity.kind === 'EVENT' ? identity.eventId : null,
      identity.aggregateType,
      identity.aggregateId,
      kind,
      reason,
      actor,
    ],
  );
  return holdView(rows[0]);
}

export async function createOutboxRetentionHold(input = {}) {
  return withSqlTransaction((client) => createOutboxRetentionHoldWithClient(client,input));
}

export async function releaseOutboxRetentionHoldWithClient(client, {
  actorId,
  sessionJti,
  holdId,
  reasonCode,
} = {}) {
  const actor = await requireWriteAdminWithClient(client,{actorId,sessionJti});
  const id = requireUuid(holdId,'holdId');
  const reason = normalizeReasonCode(reasonCode);
  const { rows: references } = await client.query(
    `SELECT target_kind,event_id,aggregate_type,aggregate_id
       FROM outbox_retention_holds
      WHERE id=$1`,
    [id],
  );
  const reference = references[0];
  if (!reference) return null;

  // Stored aggregate identity means a hold can still be released after a
  // future archival operation removes the original Outbox row.
  await acquireOutboxRetentionLocksWithClient(client,{
    eventId:reference.event_id,
    aggregateType:reference.aggregate_type,
    aggregateId:reference.aggregate_id,
  });
  const { rows: lockedRows } = await client.query(
    `SELECT id,target_kind,event_id,aggregate_type,aggregate_id
       FROM outbox_retention_holds
      WHERE id=$1
      FOR UPDATE`,
    [id],
  );
  const hold = lockedRows[0];
  if (!hold) return null;
  const { rows: existingRelease } = await client.query(
    'SELECT hold_id FROM outbox_retention_hold_releases WHERE hold_id=$1',
    [id],
  );
  if (existingRelease[0]) {
    fail('OUTBOX_RETENTION_HOLD_ALREADY_RELEASED', 'The Outbox retention hold is already released', 409);
  }
  const { rows } = await client.query(
    `INSERT INTO outbox_retention_hold_releases(hold_id,released_by,reason_code,released_at)
     VALUES($1,$2,$3,NOW())
     RETURNING hold_id,released_by,reason_code,released_at`,
    [id,actor,reason],
  );
  return {
    id:String(rows[0].hold_id),
    released:true,
    releasedBy:String(rows[0].released_by),
    reasonCode:rows[0].reason_code,
    releasedAt:rows[0].released_at?.toISOString?.() ?? rows[0].released_at,
  };
}

export async function releaseOutboxRetentionHold(input = {}) {
  return withSqlTransaction((client) => releaseOutboxRetentionHoldWithClient(client,input));
}

/**
 * Candidate gate for a future retention/archive/purge worker. This method
 * only reports active blockers; it never changes an Outbox event or registry.
 */
export async function checkOutboxRetentionTargetHoldsWithClient(client, target) {
  const identity = await lockOutboxRetentionTargetWithClient(client,target);
  const { rows } = await client.query(
    `SELECT h.hold_kind
       FROM outbox_retention_holds h
      WHERE (
        (h.target_kind='EVENT' AND h.event_id=$1)
        OR
        (
          h.target_kind='AGGREGATE'
          AND h.aggregate_type=$2
          AND h.aggregate_id IS NOT DISTINCT FROM $3::uuid
        )
      )
        AND NOT EXISTS (
          SELECT 1 FROM outbox_retention_hold_releases r WHERE r.hold_id=h.id
        )
      ORDER BY h.created_at,h.id`,
    [
      identity.kind === 'EVENT' ? identity.eventId : null,
      identity.aggregateType,
      identity.aggregateId,
    ],
  );
  const holdKinds = [...new Set(rows.map((row) => row.hold_kind))];
  return {
    blocked:rows.length > 0,
    activeHoldCount:rows.length,
    activeHoldKinds:holdKinds,
  };
}

async function requireReadOnlyAdminWithClient(client, { actorId, sessionJti } = {}) {
  const actor = requireUuid(actorId,'actorId');
  const jti = String(sessionJti ?? '').trim();
  if (!jti) fail('ADMIN_PANEL_LOCKED', 'Current-session READ verification is required', 403);
  const { rows } = await client.query(
    `SELECT id,role,status,
            admin_panel_verified_session_jti,
            admin_panel_verified_scope,
            (
              admin_panel_verified_at >= NOW() - INTERVAL '15 minutes'
              AND admin_panel_verified_at <= NOW() + INTERVAL '5 seconds'
            ) AS step_up_valid
       FROM users
      WHERE id=$1`,
    [actor],
  );
  const admin = rows[0];
  if (!admin || admin.role !== 'ADMIN' || admin.status !== 'ACTIVE') {
    fail('ADMIN_REQUIRED', 'An active administrator account is required', 403);
  }
  const scope = String(admin.admin_panel_verified_scope || '').toUpperCase();
  if (
    String(admin.admin_panel_verified_session_jti || '') !== jti
    || !['READ','WRITE'].includes(scope)
    || admin.step_up_valid !== true
  ) {
    fail('ADMIN_PANEL_LOCKED', 'Current-session READ verification is required', 403);
  }
  return actor;
}

function retentionClassFor(eventType, aggregateType) {
  if (FINANCIAL_EVENT_TYPES.has(eventType) || ['payment','payout'].includes(aggregateType)) return 'FINANCIAL';
  if (eventType.startsWith('AUTH_') || eventType.startsWith('SECURITY_')) return 'SECURITY';
  if (eventType === 'NOTIFICATION_DISPATCH') return 'NOTIFICATION';
  return 'OPERATIONAL';
}

function classifyOutboxRow(row) {
  const eventType = String(row.event_type || '');
  const aggregateType = String(row.aggregate_type || '');
  const status = String(row.status || '').toUpperCase();
  const holdCount = Number(row.active_hold_count || 0);
  const holdKinds = Array.isArray(row.active_hold_kinds) ? row.active_hold_kinds : [];
  const retentionClass = retentionClassFor(eventType,aggregateType);
  const blockers = ['RETENTION_PERIOD_NOT_APPROVED'];
  if (retentionClass === 'FINANCIAL') blockers.push('FINANCIAL_RECORDS_EXCLUDED');
  if (holdCount > 0) blockers.push('ACTIVE_HOLD');
  if (!['DONE','FAILED','CANCELLED'].includes(status)) blockers.push('EVENT_NOT_TERMINAL');
  if (['DONE','FAILED','CANCELLED'].includes(status) && !row.terminal_at) blockers.push('MISSING_TERMINAL_CLOCK');
  return {
    eventType,
    aggregateType,
    status,
    createdAt:row.created_at?.toISOString?.() ?? row.created_at,
    terminalAt:row.terminal_at?.toISOString?.() ?? row.terminal_at ?? null,
    retentionClass,
    activeHoldCount:holdCount,
    activeHoldKinds:holdKinds,
    eligible:false,
    blockers,
  };
}

/**
 * Sanitized inventory only. The single repeatable-read read-only transaction
 * freezes both Outbox rows and hold-release evidence for the entire keyset scan.
 * No retention duration is assumed and no candidate is marked eligible.
 */
export async function buildOutboxRetentionDryRun({
  actorId,
  sessionJti,
  pageSize = 100,
  maxRows = 500,
} = {}) {
  // This inventory intentionally remains blocked by RETENTION_PERIOD_NOT_APPROVED;
  // financial record classes additionally carry FINANCIAL_RECORDS_EXCLUDED.

  const safePageSize = Number(pageSize);
  const safeMaxRows = Number(maxRows);
  if (!Number.isInteger(safePageSize) || safePageSize < 1 || safePageSize > 100) {
    fail('INVALID_RETENTION_PAGE_SIZE', 'pageSize must be an integer between 1 and 100');
  }
  if (!Number.isInteger(safeMaxRows) || safeMaxRows < 1 || safeMaxRows > 1000) {
    fail('INVALID_RETENTION_MAX_ROWS', 'maxRows must be an integer between 1 and 1000');
  }

  const client = await requirePool().connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    await requireReadOnlyAdminWithClient(client,{actorId,sessionJti});
    const { rows: clockRows } = await client.query(
      'SELECT transaction_timestamp() AS as_of',
    );
    const asOf = clockRows[0].as_of?.toISOString?.() ?? clockRows[0].as_of;
    const { rows: watermarkRows } = await client.query(
      `SELECT o.created_at::text AS created_at,o.id::text AS id
         FROM outbox_events o
        ORDER BY o.created_at DESC,o.id DESC
        LIMIT 1`,
    );
    const snapshot = {
      createdAt:watermarkRows[0]?.created_at ?? null,
      id:watermarkRows[0]?.id ?? null,
    };
    const { rows: totalRows } = await client.query(
      `SELECT COUNT(*)::int AS total
         FROM outbox_events o
        WHERE ($1::timestamptz IS NULL OR (o.created_at,o.id) <= ($1::timestamptz,$2::uuid))`,
      [snapshot.createdAt,snapshot.id],
    );

    const items = [];
    let pagesRead = 0;
    let lastCreatedAt = null;
    let lastId = null;
    let truncated = false;
    while (items.length < safeMaxRows && snapshot.createdAt !== null) {
      const limit = Math.min(safePageSize,safeMaxRows-items.length);
      const { rows } = await client.query(
        `SELECT
           o.event_type,
           o.aggregate_type,
           o.status,
           o.created_at,
           o.terminal_at,
           (
             SELECT COUNT(*)::int
               FROM outbox_retention_holds h
              WHERE (
                (h.target_kind='EVENT' AND h.event_id=o.id)
                OR
                (
                  h.target_kind='AGGREGATE'
                  AND h.aggregate_type=o.aggregate_type
                  AND h.aggregate_id IS NOT DISTINCT FROM o.aggregate_id
                )
              )
                AND NOT EXISTS (
                  SELECT 1 FROM outbox_retention_hold_releases r WHERE r.hold_id=h.id
                )
           ) AS active_hold_count,
           COALESCE((
             SELECT array_agg(DISTINCT h.hold_kind ORDER BY h.hold_kind)
               FROM outbox_retention_holds h
              WHERE (
                (h.target_kind='EVENT' AND h.event_id=o.id)
                OR
                (
                  h.target_kind='AGGREGATE'
                  AND h.aggregate_type=o.aggregate_type
                  AND h.aggregate_id IS NOT DISTINCT FROM o.aggregate_id
                )
              )
                AND NOT EXISTS (
                  SELECT 1 FROM outbox_retention_hold_releases r WHERE r.hold_id=h.id
                )
           ),ARRAY[]::text[]) AS active_hold_kinds
         FROM outbox_events o
        WHERE ($1::timestamptz IS NULL OR (o.created_at, o.id) > ($1::timestamptz,$2::uuid))
          AND ($3::timestamptz IS NULL OR (o.created_at,o.id) <= ($3::timestamptz,$4::uuid))
        ORDER BY o.created_at ASC,o.id ASC
        LIMIT $5`,
        [lastCreatedAt,lastId,snapshot.createdAt,snapshot.id,limit],
      );
      if (!rows.length) break;
      pagesRead += 1;
      items.push(...rows.map(classifyOutboxRow));
      const last = rows[rows.length-1];
      lastCreatedAt = last.created_at;
      lastId = last.id;
    }

    if (items.length >= safeMaxRows && snapshot.createdAt !== null) {
      const { rows: moreRows } = await client.query(
        `SELECT EXISTS(
           SELECT 1
             FROM outbox_events o
            WHERE (o.created_at,o.id) > ($1::timestamptz,$2::uuid)
              AND (o.created_at,o.id) <= ($3::timestamptz,$4::uuid)
         ) AS has_more`,
        [lastCreatedAt,lastId,snapshot.createdAt,snapshot.id],
      );
      truncated = moreRows[0]?.has_more === true;
    }

    await client.query('COMMIT');
    return {
      mode:'DRY_RUN',
      asOf,
      limit:safePageSize,
      maxRows:safeMaxRows,
      totalCount:Number(totalRows[0]?.total || 0),
      scanned:items.length,
      pagesRead,
      truncated,
      retentionPolicyConfigured:false,
      wouldMutate:false,
      mutationCount:0,
      providerCalls:0,
      payloadIncluded:false,
      piiIncluded:false,
      items,
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}
