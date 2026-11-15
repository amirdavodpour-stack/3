import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { lockAuthorizedAdminActor } from './admin_authorization.js';

const MAX_RECONCILIATION_BATCH = 100;

function limitValue(value, fallback = 50) {
  const n = Number(value ?? fallback);
  if (!Number.isInteger(n) || n < 1) return fallback;
  return Math.min(n, MAX_RECONCILIATION_BATCH);
}

export async function listUnknownPayoutsForReconciliation({ limit = 50 } = {}) {
  const pool = requirePool();
  const bounded = limitValue(limit);
  const { rows } = await pool.query(`
    SELECT id, wallet_id, user_id, amount, currency, status, provider, provider_ref, idempotency_key, created_at, updated_at
    FROM payouts
    WHERE status='UNKNOWN'
    ORDER BY updated_at ASC, id ASC
    LIMIT $1
  `, [bounded]);
  return rows;
}

const RECONCILIATION_CURSOR_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function decodeReconciliationCursor(cursor) {
  if (cursor == null || cursor === '') return null;
  if (typeof cursor !== 'string' || cursor.length > 512 || !/^[A-Za-z0-9_-]+$/.test(cursor)) {
    const error = new Error('INVALID_RECONCILIATION_CURSOR');
    error.code = 'INVALID_RECONCILIATION_CURSOR';
    throw error;
  }
  try {
    const decoded = Buffer.from(cursor, 'base64url').toString('utf8');
    if (Buffer.from(decoded, 'utf8').toString('base64url') !== cursor) throw new Error('non-canonical');
    const value = JSON.parse(decoded);
    const createdAt = String(value?.createdAt ?? '');
    if (
      value?.v !== 1 ||
      !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/.test(createdAt) ||
      !Number.isFinite(Date.parse(createdAt)) ||
      !RECONCILIATION_CURSOR_UUID.test(String(value?.id || ''))
    ) throw new Error('invalid cursor payload');
    return { createdAt, id: value.id };
  } catch {
    const error = new Error('INVALID_RECONCILIATION_CURSOR');
    error.code = 'INVALID_RECONCILIATION_CURSOR';
    throw error;
  }
}

function encodeReconciliationCursor(row) {
  return Buffer.from(JSON.stringify({
    v: 1,
    // Keep PostgreSQL's six fractional digits; JavaScript Date truncates to milliseconds.
    createdAt: String(row.createdAt),
    id: row.id,
  }), 'utf8').toString('base64url');
}

export async function listActiveOutboxEventReconciliationCases({ limit = 50, cursor = null } = {}) {
  const pool = requirePool();
  const bounded = limitValue(limit);
  const decodedCursor = decodeReconciliationCursor(cursor);
  const { rows } = await pool.query(`
    SELECT rc.id,
           rc.case_type AS "caseType",
           rc.resource_type AS "resourceType",
           rc.resource_id AS "resourceId",
           rc.severity,
           rc.status,
           rc.expected,
           rc.observed,
           to_char(rc.created_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS "createdAt",
           rc.updated_at AS "updatedAt",
           oe.event_type AS "eventType",
           oe.status AS "eventStatus",
           oe.aggregate_type AS "aggregateType",
           oe.aggregate_id AS "aggregateId"
      FROM reconciliation_cases rc
      LEFT JOIN outbox_events oe
        ON oe.id=rc.resource_id
     WHERE rc.resource_type='outbox_event'
       AND rc.status IN ('OPEN','INVESTIGATING')
       AND (
         $1::timestamptz IS NULL
         OR (rc.created_at,rc.id)<($1::timestamptz,$2::uuid)
       )
     ORDER BY rc.created_at DESC,rc.id DESC
     LIMIT $3
  `, [decodedCursor?.createdAt ?? null, decodedCursor?.id ?? null, bounded + 1]);

  const hasMore = rows.length > bounded;
  const cases = rows.slice(0, bounded);
  return {
    cases,
    hasMore,
    nextCursor: hasMore && cases.length ? encodeReconciliationCursor(cases[cases.length - 1]) : null,
  };
}



const OUTBOX_EVENT_INVESTIGATION_CASE_TYPES = Object.freeze([
  'PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY',
  'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',
]);

const INVESTIGATION_VERIFICATION_FIELDS = Object.freeze({
  eventIdentity: new Set(['MISMATCH_CONFIRMED', 'UNRESOLVED']),
  canonicalPayout: new Set(['MATCHED', 'MISMATCHED', 'NOT_FOUND', 'NOT_VERIFIED']),
  providerOutcome: new Set(['SUCCEEDED_CONFIRMED', 'FAILED_CONFIRMED', 'UNKNOWN', 'NOT_CHECKED']),
});

const UUID_VALUE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const IDEMPOTENCY_KEY_VALUE = /^[A-Za-z0-9._:-]{16,128}$/;

function investigationInputError(code) {
  const error = new Error(code);
  error.code = code;
  error.status = 400;
  return error;
}

function normalizeInvestigationNoteInput(input = {}) {
  const caseId = String(input.caseId || '').trim();
  const actorId = String(input.actorId || '').trim();
  const sessionJti = String(input.sessionJti || '').trim();
  const reason = String(input.reason || '').trim();
  const evidenceReference = String(input.evidenceReference || '').trim();
  const idempotencyKey = String(input.idempotencyKey || '').trim();

  if (!UUID_VALUE.test(caseId)) throw investigationInputError('INVALID_RECONCILIATION_CASE_ID');
  if (!UUID_VALUE.test(actorId)) throw investigationInputError('INVALID_RECONCILIATION_ACTOR_ID');
  if (!sessionJti || sessionJti.length > 200) throw investigationInputError('INVALID_RECONCILIATION_SESSION');
  if (reason.length < 10 || reason.length > 1000) throw investigationInputError('INVALID_RECONCILIATION_REASON');
  if (evidenceReference.length < 8 || evidenceReference.length > 500) throw investigationInputError('INVALID_RECONCILIATION_EVIDENCE_REFERENCE');
  if (!IDEMPOTENCY_KEY_VALUE.test(idempotencyKey)) throw investigationInputError('INVALID_RECONCILIATION_IDEMPOTENCY_KEY');

  const supplied = input.verification;
  if (!supplied || typeof supplied !== 'object' || Array.isArray(supplied)) {
    throw investigationInputError('INVALID_RECONCILIATION_VERIFICATION');
  }
  const requiredKeys = Object.keys(INVESTIGATION_VERIFICATION_FIELDS).sort();
  const suppliedKeys = Object.keys(supplied).sort();
  if (
    suppliedKeys.length !== requiredKeys.length ||
    suppliedKeys.some((key, index) => key !== requiredKeys[index]) ||
    requiredKeys.some((key) => !INVESTIGATION_VERIFICATION_FIELDS[key].has(String(supplied[key] || '').toUpperCase()))
  ) {
    throw investigationInputError('INVALID_RECONCILIATION_VERIFICATION');
  }

  const verification = Object.freeze({
    eventIdentity: String(supplied.eventIdentity).toUpperCase(),
    canonicalPayout: String(supplied.canonicalPayout).toUpperCase(),
    providerOutcome: String(supplied.providerOutcome).toUpperCase(),
  });
  const requestHash = crypto.createHash('sha256').update(JSON.stringify({
    caseId,
    actorId,
    sessionJti,
    reason,
    evidenceReference,
    verification,
  })).digest('hex');

  return {
    caseId,
    actorId,
    sessionJti,
    verificationMinutes: Math.min(120, Math.max(1, Number(input.verificationMinutes) || 5)),
    reason,
    evidenceReference,
    verification,
    idempotencyKey,
    requestHash,
  };
}

/**
 * Append an operator-reported evidence note to one exact, active Outbox event
 * reconciliation case. This is deliberately non-financial: it never resolves
 * or dismisses a case and never changes payouts, wallets, holds, journals,
 * ledger entries, or Outbox event state.
 */
export async function appendOutboxEventReconciliationNote(input = {}) {
  const note = normalizeInvestigationNoteInput(input);

  return withSqlTransaction(async (client) => {
    // Lock and revalidate the administrator before acquiring any domain-row lock.
    await lockAuthorizedAdminActor(client, {
      actorId: note.actorId,
      sessionJti: note.sessionJti,
      verificationMinutes: note.verificationMinutes,
      requiredScope: 'WRITE',
      requireStepUp: true,
      requirePrimaryAdmin: true,
    });

    // Same-actor retries are serialized by the administrator row lock. Resolve
    // an existing idempotency key before checking current case activity so a
    // retry can safely replay the original append without reopening a case.
    const existing = await client.query(
      `SELECT n.id,n.case_id,n.event_id,n.action,n.request_hash,rc.status AS case_status
         FROM reconciliation_case_events n
         JOIN reconciliation_cases rc ON rc.id=n.case_id
        WHERE n.actor_id=$1 AND n.idempotency_key=$2`,
      [note.actorId, note.idempotencyKey],
    );
    if (existing.rows[0]) {
      const row = existing.rows[0];
      if (row.request_hash !== note.requestHash || String(row.case_id) !== note.caseId) {
        const error = new Error('IDEMPOTENCY_CONFLICT');
        error.code = 'IDEMPOTENCY_CONFLICT';
        error.status = 409;
        throw error;
      }
      return {
        id: row.id,
        caseId: row.case_id,
        eventId: row.event_id,
        action: row.action,
        caseStatus: row.case_status,
        replayed: true,
      };
    }

    const candidate = await client.query(
      `SELECT id,resource_id
         FROM reconciliation_cases
        WHERE id=$1
          AND resource_type='outbox_event'
          AND case_type=ANY($2::text[])
          AND status IN ('OPEN','INVESTIGATING')`,
      [note.caseId, OUTBOX_EVENT_INVESTIGATION_CASE_TYPES],
    );
    if (!candidate.rows[0]) {
      const error = new Error('RECONCILIATION_CASE_NOT_FOUND');
      error.code = 'RECONCILIATION_CASE_NOT_FOUND';
      error.status = 404;
      throw error;
    }
    const eventId = candidate.rows[0].resource_id;
    if (!eventId) {
      const error = new Error('OUTBOX_EVENT_NOT_FOUND');
      error.code = 'OUTBOX_EVENT_NOT_FOUND';
      error.status = 409;
      throw error;
    }

    // Lock order: administrator → referenced Outbox event → exact case.
    const event = await client.query(
      'SELECT id FROM outbox_events WHERE id=$1 FOR SHARE',
      [eventId],
    );
    if (!event.rows[0]) {
      const error = new Error('OUTBOX_EVENT_NOT_FOUND');
      error.code = 'OUTBOX_EVENT_NOT_FOUND';
      error.status = 409;
      throw error;
    }

    const lockedCase = await client.query(
      `SELECT id,resource_id,status
         FROM reconciliation_cases
        WHERE id=$1
          AND resource_type='outbox_event'
          AND case_type=ANY($2::text[])
          AND status IN ('OPEN','INVESTIGATING')
        FOR UPDATE`,
      [note.caseId, OUTBOX_EVENT_INVESTIGATION_CASE_TYPES],
    );
    const caseRow = lockedCase.rows[0];
    if (!caseRow || String(caseRow.resource_id) !== String(eventId)) {
      const error = new Error('RECONCILIATION_CASE_NOT_ACTIVE');
      error.code = 'RECONCILIATION_CASE_NOT_ACTIVE';
      error.status = 409;
      throw error;
    }

    const inserted = await client.query(
      `INSERT INTO reconciliation_case_events(
         case_id,event_id,actor_id,actor_session_jti,action,reason,
         evidence_reference,verification,idempotency_key,request_hash
       ) VALUES($1,$2,$3,$4,'INVESTIGATION_NOTE_ADDED',$5,$6,$7::jsonb,$8,$9)
       ON CONFLICT (actor_id,idempotency_key) DO NOTHING
       RETURNING id,case_id,event_id,action`,
      [
        note.caseId,
        eventId,
        note.actorId,
        note.sessionJti,
        note.reason,
        note.evidenceReference,
        JSON.stringify(note.verification),
        note.idempotencyKey,
        note.requestHash,
      ],
    );

    if (!inserted.rows[0]) {
      const replay = await client.query(
        `SELECT n.id,n.case_id,n.event_id,n.action,n.request_hash,rc.status AS case_status
           FROM reconciliation_case_events n
           JOIN reconciliation_cases rc ON rc.id=n.case_id
          WHERE n.actor_id=$1 AND n.idempotency_key=$2`,
        [note.actorId, note.idempotencyKey],
      );
      const row = replay.rows[0];
      if (!row || row.request_hash !== note.requestHash || String(row.case_id) !== note.caseId) {
        const error = new Error('IDEMPOTENCY_CONFLICT');
        error.code = 'IDEMPOTENCY_CONFLICT';
        error.status = 409;
        throw error;
      }
      return {
        id: row.id,
        caseId: row.case_id,
        eventId: row.event_id,
        action: row.action,
        caseStatus: row.case_status,
        replayed: true,
      };
    }

    let caseStatus = caseRow.status;
    if (caseStatus === 'OPEN') {
      const updated = await client.query(
        `UPDATE reconciliation_cases
            SET status='INVESTIGATING',updated_at=NOW()
          WHERE id=$1 AND status='OPEN'
          RETURNING status`,
        [note.caseId],
      );
      caseStatus = updated.rows[0]?.status || 'INVESTIGATING';
    }

    await client.query(
      `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
       VALUES(gen_random_uuid(),'OUTBOX_EVENT_RECONCILIATION_NOTE_ADDED',$1,'reconciliation_case',$2,$3::jsonb,NOW())`,
      [
        note.actorId,
        note.caseId,
        JSON.stringify({
          eventId,
          noteId: inserted.rows[0].id,
          evidenceReference: note.evidenceReference,
          verification: note.verification,
        }),
      ],
    );

    return {
      id: inserted.rows[0].id,
      caseId: inserted.rows[0].case_id,
      eventId: inserted.rows[0].event_id,
      action: inserted.rows[0].action,
      caseStatus,
      replayed: false,
    };
  });
}

export async function openReconciliationCase({
  caseType,
  resourceType,
  resourceId,
  severity = 'HIGH',
  expected = {},
  observed = {},
}) {
  const normalizedSeverity = String(severity || 'HIGH').toUpperCase();
  if (!['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].includes(normalizedSeverity)) throw new Error('INVALID_RECONCILIATION_SEVERITY');
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(`
      INSERT INTO reconciliation_cases(
        id,case_type,resource_type,resource_id,severity,expected,observed,status,created_at,updated_at
      ) VALUES(gen_random_uuid(),$1,$2,$3,$4,$5::jsonb,$6::jsonb,'OPEN',NOW(),NOW())
      ON CONFLICT (case_type,resource_type,resource_id) WHERE status IN ('OPEN','INVESTIGATING')
      DO UPDATE SET severity=EXCLUDED.severity,expected=EXCLUDED.expected,observed=EXCLUDED.observed,updated_at=NOW()
      RETURNING *
    `, [
      String(caseType),
      String(resourceType),
      resourceId || null,
      normalizedSeverity,
      JSON.stringify(expected || {}),
      JSON.stringify(observed || {}),
    ]);
    return rows[0];
  });
}

export async function resolveLatestReconciliationCase({ resourceType, resourceId, resolutionReference, status = 'RESOLVED' }) {
  const nextStatus = String(status || 'RESOLVED').toUpperCase();
  if (!['RESOLVED', 'DISMISSED'].includes(nextStatus)) throw new Error('INVALID_RECONCILIATION_RESOLUTION_STATUS');
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(`
      UPDATE reconciliation_cases
      SET status=$3,resolution_reference=$4,resolved_at=NOW(),updated_at=NOW()
      WHERE id=(
        SELECT id FROM reconciliation_cases
        WHERE resource_type=$1 AND resource_id=$2 AND status IN ('OPEN','INVESTIGATING')
        ORDER BY created_at DESC,id DESC
        LIMIT 1
      )
      RETURNING *
    `, [String(resourceType), resourceId || null, nextStatus, resolutionReference ? String(resolutionReference).slice(0, 200) : null]);
    return rows[0] || null;
  });
}
