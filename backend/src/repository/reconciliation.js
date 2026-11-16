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

function canonicalJson(value) {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map((item) => canonicalJson(item)).join(',')}]`;
  if (value instanceof Date) return JSON.stringify(value.toISOString());
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

function outboxEventCaseEvidenceDigest(row) {
  const event = row.eventId ? {
    id: row.eventId,
    eventType: row.eventType,
    aggregateType: row.aggregateType,
    aggregateId: row.aggregateId,
    payloadSha256: sha256(canonicalJson(row.eventPayload)),
    status: row.eventStatus,
    attempts: Number(row.eventAttempts ?? 0),
    processedAt: row.eventProcessedAt ?? null,
    lastErrorSha256: row.eventLastError == null ? null : sha256(row.eventLastError),
  } : null;
  return sha256(canonicalJson({
    version: 1,
    case: {
      id: row.id,
      caseType: row.caseType,
      resourceType: row.resourceType,
      resourceId: row.resourceId,
      severity: row.severity,
      expected: row.expected,
      observed: row.observed,
    },
    event,
  }));
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
           oe.id AS "eventId",
           oe.event_type AS "eventType",
           oe.status AS "eventStatus",
           oe.aggregate_type AS "aggregateType",
           oe.aggregate_id AS "aggregateId",
           oe.payload AS "eventPayload",
           oe.attempts AS "eventAttempts",
           to_char(oe.processed_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS "eventProcessedAt",
           oe.last_error AS "eventLastError",
           latest.action AS "latestAction",
           reviewed.reviewed_case_digest AS "lastAttestedCaseDigest"
      FROM reconciliation_cases rc
      LEFT JOIN outbox_events oe
        ON oe.id=rc.resource_id
      LEFT JOIN LATERAL (
        SELECT n.action
          FROM reconciliation_case_events n
         WHERE n.case_id=rc.id
         ORDER BY n.created_at DESC,n.id DESC
         LIMIT 1
      ) latest ON true
      LEFT JOIN LATERAL (
        SELECT n.reviewed_case_digest
          FROM reconciliation_case_events n
         WHERE n.case_id=rc.id
           AND n.reviewed_case_digest IS NOT NULL
         ORDER BY n.created_at DESC,n.id DESC
         LIMIT 1
      ) reviewed ON true
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
  const cases = rows.slice(0, bounded).map((row) => {
    const caseEvidenceDigest = outboxEventCaseEvidenceDigest(row);
    const investigationStatus = row.latestAction === 'INVESTIGATION_CLOSED_UNRESOLVED'
      ? 'CLOSED_UNRESOLVED'
      : row.latestAction
        ? 'IN_PROGRESS'
        : 'NOT_STARTED';
    const result = {
      ...row,
      caseEvidenceDigest,
      investigationStatus,
      reReviewRequired: Boolean(
        row.lastAttestedCaseDigest && row.lastAttestedCaseDigest !== caseEvidenceDigest,
      ),
      hasCurrentDigestAttestation: Boolean(
        row.lastAttestedCaseDigest && row.lastAttestedCaseDigest === caseEvidenceDigest,
      ),
    };
    for (const field of [
      'eventId','eventPayload','eventAttempts','eventProcessedAt','eventLastError',
      'latestAction','lastAttestedCaseDigest',
    ]) delete result[field];
    return result;
  });
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

const OUTBOX_EVENT_ATTESTATION_ACTIONS = new Set([
  'INVESTIGATION_ATTESTATION_RECORDED',
  'INVESTIGATION_CLOSED_UNRESOLVED',
  'INVESTIGATION_REOPENED',
]);
const OUTBOX_EVENT_EVIDENCE_SOURCES = new Set([
  'BANK_STATEMENT',
  'INTERNAL_LEDGER',
  'OUTBOX_EVENT',
  'OPERATOR_REPORT',
  'PROVIDER_ARTIFACT',
  'SUPPORT_TICKET',
  'OTHER',
]);
const ATTESTATION_VERIFICATION_LEVELS = new Set([
  'OPERATOR_REPORTED',
  'SOURCE_ARTIFACT_REVIEWED',
  'INDEPENDENTLY_CORROBORATED',
  'CONFLICTING',
  'INCONCLUSIVE',
  'NOT_CHECKED',
]);
const ATTESTATION_RESULT_FIELDS = Object.freeze({
  eventIdentity: new Set(['MATCHED','MISMATCH_CONFIRMED','UNRESOLVED','NOT_CHECKED']),
  canonicalPayout: new Set(['MATCHED','MISMATCHED','NOT_FOUND','NOT_VERIFIED','NOT_CHECKED']),
  providerOutcome: new Set(['SUCCEEDED_CONFIRMED','FAILED_CONFIRMED','UNKNOWN','NOT_CHECKED']),
});

function commandError(code, status = 409) {
  const error = new Error(code);
  error.code = code;
  error.status = status;
  return error;
}

function normalizeOutboxEventAttestationInput(input = {}) {
  const allowedFields = new Set([
    'caseId','actorId','sessionJti','verificationMinutes','action','reason',
    'sourceType','issuer','evidenceReference','artifactSha256','sourceObservedAt',
    'reviewedCaseDigest','verification','idempotencyKey',
  ]);
  if (
    !input
    || typeof input !== 'object'
    || Array.isArray(input)
    || Object.keys(input).some((key) => !allowedFields.has(key))
  ) throw investigationInputError('INVALID_RECONCILIATION_ATTESTATION_FIELDS');

  const caseId = String(input.caseId || '').trim();
  const actorId = String(input.actorId || '').trim();
  const sessionJti = String(input.sessionJti || '').trim();
  const action = String(input.action || '').trim().toUpperCase();
  const reason = String(input.reason || '').trim();
  const sourceType = String(input.sourceType || '').trim().toUpperCase();
  const issuer = String(input.issuer || '').trim();
  const evidenceReference = String(input.evidenceReference || '').trim();
  const artifactSha256 = input.artifactSha256 == null || input.artifactSha256 === ''
    ? null
    : String(input.artifactSha256).trim().toLowerCase();
  const sourceObservedAt = input.sourceObservedAt == null || input.sourceObservedAt === ''
    ? null
    : String(input.sourceObservedAt).trim();
  const reviewedCaseDigest = String(input.reviewedCaseDigest || '').trim().toLowerCase();
  const idempotencyKey = String(input.idempotencyKey || '').trim();

  if (!UUID_VALUE.test(caseId)) throw investigationInputError('INVALID_RECONCILIATION_CASE_ID');
  if (!UUID_VALUE.test(actorId)) throw investigationInputError('INVALID_RECONCILIATION_ACTOR_ID');
  if (!sessionJti || sessionJti.length > 200) throw investigationInputError('INVALID_RECONCILIATION_SESSION');
  if (!OUTBOX_EVENT_ATTESTATION_ACTIONS.has(action)) throw investigationInputError('INVALID_RECONCILIATION_ACTION');
  if (reason.length < 10 || reason.length > 1000) throw investigationInputError('INVALID_RECONCILIATION_REASON');
  if (!OUTBOX_EVENT_EVIDENCE_SOURCES.has(sourceType)) throw investigationInputError('INVALID_RECONCILIATION_SOURCE_TYPE');
  if (issuer.length < 2 || issuer.length > 160) throw investigationInputError('INVALID_RECONCILIATION_EVIDENCE_ISSUER');
  if (evidenceReference.length < 8 || evidenceReference.length > 500) throw investigationInputError('INVALID_RECONCILIATION_EVIDENCE_REFERENCE');
  if (artifactSha256 && !/^[a-f0-9]{64}$/.test(artifactSha256)) throw investigationInputError('INVALID_RECONCILIATION_ARTIFACT_DIGEST');
  if (sourceObservedAt && (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/.test(sourceObservedAt)
    || !Number.isFinite(Date.parse(sourceObservedAt))
  )) throw investigationInputError('INVALID_RECONCILIATION_SOURCE_OBSERVED_AT');
  if (!/^[a-f0-9]{64}$/.test(reviewedCaseDigest)) throw investigationInputError('INVALID_RECONCILIATION_REVIEWED_DIGEST');
  if (!IDEMPOTENCY_KEY_VALUE.test(idempotencyKey)) throw investigationInputError('INVALID_RECONCILIATION_IDEMPOTENCY_KEY');

  const supplied = input.verification;
  const requiredKeys = Object.keys(ATTESTATION_RESULT_FIELDS).sort();
  const suppliedKeys = supplied && typeof supplied === 'object' && !Array.isArray(supplied)
    ? Object.keys(supplied).sort()
    : [];
  if (
    suppliedKeys.length !== requiredKeys.length
    || suppliedKeys.some((key, index) => key !== requiredKeys[index])
  ) throw investigationInputError('INVALID_RECONCILIATION_VERIFICATION');

  const verification = {};
  for (const field of requiredKeys) {
    const entry = supplied[field];
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
      throw investigationInputError('INVALID_RECONCILIATION_VERIFICATION');
    }
    const keys = Object.keys(entry).sort();
    if (
      keys.length !== 2
      || keys[0] !== 'result'
      || keys[1] !== 'verificationLevel'
    ) throw investigationInputError('INVALID_RECONCILIATION_VERIFICATION');
    const result = String(entry.result || '').trim().toUpperCase();
    const verificationLevel = String(entry.verificationLevel || '').trim().toUpperCase();
    if (
      !ATTESTATION_RESULT_FIELDS[field].has(result)
      || !ATTESTATION_VERIFICATION_LEVELS.has(verificationLevel)
    ) throw investigationInputError('INVALID_RECONCILIATION_VERIFICATION');
    verification[field] = { result, verificationLevel };
  }

  return {
    caseId,
    actorId,
    sessionJti,
    verificationMinutes: Math.min(120, Math.max(1, Number(input.verificationMinutes) || 5)),
    action,
    reason,
    sourceType,
    issuer,
    evidenceReference,
    artifactSha256,
    sourceObservedAt,
    reviewedCaseDigest,
    verification,
    idempotencyKey,
  };
}

function outboxEventAttestationRequestHash(command, eventId) {
  return sha256(canonicalJson({
    version: 1,
    action: command.action,
    caseId: command.caseId,
    eventId,
    actorId: command.actorId,
    reason: command.reason,
    sourceType: command.sourceType,
    issuer: command.issuer,
    evidenceReference: command.evidenceReference,
    artifactSha256: command.artifactSha256,
    sourceObservedAt: command.sourceObservedAt,
    verification: command.verification,
    reviewedCaseDigest: command.reviewedCaseDigest,
  }));
}

async function loadOutboxEventCaseEvidenceSnapshot(client, caseId) {
  const { rows } = await client.query(
    `SELECT rc.id,
            rc.case_type AS "caseType",
            rc.resource_type AS "resourceType",
            rc.resource_id AS "resourceId",
            rc.severity,
            rc.status,
            rc.expected,
            rc.observed,
            oe.id AS "eventId",
            oe.event_type AS "eventType",
            oe.status AS "eventStatus",
            oe.aggregate_type AS "aggregateType",
            oe.aggregate_id AS "aggregateId",
            oe.payload AS "eventPayload",
            oe.attempts AS "eventAttempts",
            to_char(oe.processed_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS "eventProcessedAt",
            oe.last_error AS "eventLastError"
       FROM reconciliation_cases rc
       LEFT JOIN outbox_events oe ON oe.id=rc.resource_id
      WHERE rc.id=$1
        AND rc.resource_type='outbox_event'
        AND rc.case_type=ANY($2::text[])`,
    [caseId, OUTBOX_EVENT_INVESTIGATION_CASE_TYPES],
  );
  if (!rows[0]) throw commandError('RECONCILIATION_CASE_NOT_ACTIVE');
  return {
    ...rows[0],
    caseEvidenceDigest: outboxEventCaseEvidenceDigest(rows[0]),
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
    const latestActionResult = await client.query(
      `SELECT action
         FROM reconciliation_case_events
        WHERE case_id=$1
        ORDER BY created_at DESC,id DESC
        LIMIT 1`,
      [note.caseId],
    );
    if (latestActionResult.rows[0]?.action === 'INVESTIGATION_CLOSED_UNRESOLVED') {
      throw commandError('INVESTIGATION_CLOSED');
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

/**
 * Record a source-backed event attestation or an investigation-only disposition.
 * All actions append evidence; CLOSED_UNRESOLVED never resolves the financial
 * reconciliation case and never touches payout, wallet, Hold, ledger or Outbox state.
 */
export async function recordOutboxEventReconciliationAttestation(input = {}) {
  const command = normalizeOutboxEventAttestationInput(input);

  return withSqlTransaction(async (client) => {
    await lockAuthorizedAdminActor(client, {
      actorId: command.actorId,
      sessionJti: command.sessionJti,
      verificationMinutes: command.verificationMinutes,
      requiredScope: 'WRITE',
      requireStepUp: true,
      requirePrimaryAdmin: true,
    });

    const existing = await client.query(
      `SELECT n.id,n.case_id,n.event_id,n.action,n.request_hash,rc.status AS case_status
         FROM reconciliation_case_events n
         JOIN reconciliation_cases rc ON rc.id=n.case_id
        WHERE n.actor_id=$1 AND n.idempotency_key=$2`,
      [command.actorId, command.idempotencyKey],
    );
    if (existing.rows[0]) {
      const row = existing.rows[0];
      const expectedHash = outboxEventAttestationRequestHash(command, row.event_id);
      if (
        row.request_hash !== expectedHash
        || String(row.case_id) !== command.caseId
      ) throw commandError('IDEMPOTENCY_CONFLICT');
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
      `SELECT id,resource_id,status
         FROM reconciliation_cases
        WHERE id=$1
          AND resource_type='outbox_event'
          AND case_type=ANY($2::text[])
          AND status IN ('OPEN','INVESTIGATING')`,
      [command.caseId, OUTBOX_EVENT_INVESTIGATION_CASE_TYPES],
    );
    if (!candidate.rows[0]) throw commandError('RECONCILIATION_CASE_NOT_FOUND', 404);
    const eventId = candidate.rows[0].resource_id;
    if (!eventId) throw commandError('OUTBOX_EVENT_NOT_FOUND');

    // Lock order is deliberately actor → referenced Outbox event → exact case.
    const event = await client.query(
      'SELECT id FROM outbox_events WHERE id=$1 FOR SHARE',
      [eventId],
    );
    if (!event.rows[0]) throw commandError('OUTBOX_EVENT_NOT_FOUND');

    const lockedCase = await client.query(
      `SELECT id,resource_id,status
         FROM reconciliation_cases
        WHERE id=$1
          AND resource_type='outbox_event'
          AND case_type=ANY($2::text[])
          AND status IN ('OPEN','INVESTIGATING')
        FOR UPDATE`,
      [command.caseId, OUTBOX_EVENT_INVESTIGATION_CASE_TYPES],
    );
    const caseRow = lockedCase.rows[0];
    if (!caseRow || String(caseRow.resource_id) !== String(eventId)) {
      throw commandError('RECONCILIATION_CASE_NOT_ACTIVE');
    }

    const snapshot = await loadOutboxEventCaseEvidenceSnapshot(client, command.caseId);
    if (
      String(snapshot.eventId) !== String(eventId)
      || snapshot.caseEvidenceDigest !== command.reviewedCaseDigest
    ) throw commandError('RECONCILIATION_EVIDENCE_STALE');

    const latestResult = await client.query(
      `SELECT action
         FROM reconciliation_case_events
        WHERE case_id=$1
        ORDER BY created_at DESC,id DESC
        LIMIT 1`,
      [command.caseId],
    );
    const latestAction = latestResult.rows[0]?.action ?? null;

    if (
      latestAction === 'INVESTIGATION_CLOSED_UNRESOLVED'
      && command.action !== 'INVESTIGATION_REOPENED'
    ) throw commandError('INVESTIGATION_CLOSED');

    if (
      command.action === 'INVESTIGATION_REOPENED'
      && latestAction !== 'INVESTIGATION_CLOSED_UNRESOLVED'
    ) throw commandError('INVESTIGATION_NOT_CLOSED');

    if (
      command.action === 'INVESTIGATION_CLOSED_UNRESOLVED'
      && latestAction === 'INVESTIGATION_CLOSED_UNRESOLVED'
    ) throw commandError('INVESTIGATION_ALREADY_CLOSED');

    if (command.action === 'INVESTIGATION_CLOSED_UNRESOLVED') {
      if (caseRow.status !== 'INVESTIGATING') {
        throw commandError('RECONCILIATION_INVESTIGATION_NOT_STARTED');
      }
      const latestAttestation = await client.query(
        `SELECT reviewed_case_digest
           FROM reconciliation_case_events
          WHERE case_id=$1
            AND action IN ('INVESTIGATION_ATTESTATION_RECORDED','INVESTIGATION_REOPENED')
          ORDER BY created_at DESC,id DESC
          LIMIT 1`,
        [command.caseId],
      );
      if (latestAttestation.rows[0]?.reviewed_case_digest !== snapshot.caseEvidenceDigest) {
        throw commandError('RECONCILIATION_ATTESTATION_REQUIRED');
      }
    }

    const inserted = await client.query(
      `INSERT INTO reconciliation_case_events(
         case_id,event_id,actor_id,actor_session_jti,action,reason,
         evidence_reference,verification,idempotency_key,request_hash,
         evidence_source_type,evidence_issuer,artifact_sha256,source_observed_at,
         reviewed_case_digest
       ) VALUES($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,$10,$11,$12,$13,$14::timestamptz,$15)
       ON CONFLICT (actor_id,idempotency_key) DO NOTHING
       RETURNING id,case_id,event_id,action`,
      [
        command.caseId,
        eventId,
        command.actorId,
        command.sessionJti,
        command.action,
        command.reason,
        command.evidenceReference,
        JSON.stringify(command.verification),
        command.idempotencyKey,
        outboxEventAttestationRequestHash(command, eventId),
        command.sourceType,
        command.issuer,
        command.artifactSha256,
        command.sourceObservedAt,
        command.reviewedCaseDigest,
      ],
    );

    if (!inserted.rows[0]) {
      const replay = await client.query(
        `SELECT n.id,n.case_id,n.event_id,n.action,n.request_hash,rc.status AS case_status
           FROM reconciliation_case_events n
           JOIN reconciliation_cases rc ON rc.id=n.case_id
          WHERE n.actor_id=$1 AND n.idempotency_key=$2`,
        [command.actorId, command.idempotencyKey],
      );
      const row = replay.rows[0];
      if (
        !row
        || row.request_hash !== outboxEventAttestationRequestHash(command, row.event_id)
        || String(row.case_id) !== command.caseId
      ) throw commandError('IDEMPOTENCY_CONFLICT');
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
    if (command.action === 'INVESTIGATION_ATTESTATION_RECORDED' && caseStatus === 'OPEN') {
      const updated = await client.query(
        `UPDATE reconciliation_cases
            SET status='INVESTIGATING',updated_at=NOW()
          WHERE id=$1 AND status='OPEN'
          RETURNING status`,
        [command.caseId],
      );
      caseStatus = updated.rows[0]?.status || 'INVESTIGATING';
    }

    const auditAction = {
      INVESTIGATION_ATTESTATION_RECORDED: 'OUTBOX_EVENT_RECONCILIATION_ATTESTED',
      INVESTIGATION_CLOSED_UNRESOLVED: 'OUTBOX_EVENT_RECONCILIATION_CLOSED_UNRESOLVED',
      INVESTIGATION_REOPENED: 'OUTBOX_EVENT_RECONCILIATION_REOPENED',
    }[command.action];
    await client.query(
      `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
       VALUES(gen_random_uuid(),$1,$2,'reconciliation_case',$3,$4::jsonb,NOW())`,
      [
        auditAction,
        command.actorId,
        command.caseId,
        JSON.stringify({
          eventId,
          eventRecordId: inserted.rows[0].id,
          action: command.action,
          sourceType: command.sourceType,
          issuer: command.issuer,
          evidenceReference: command.evidenceReference,
          artifactSha256: command.artifactSha256,
          sourceObservedAt: command.sourceObservedAt,
          reviewedCaseDigest: command.reviewedCaseDigest,
          verification: command.verification,
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

/**
 * Read the append-only investigation history for one exact Outbox event case.
 * Session JTI, idempotency keys, request hashes and provider payloads are
 * intentionally not exposed to the Admin client.
 */
export async function listOutboxEventReconciliationNotes({
  caseId,
  limit = 25,
  cursor = null,
} = {}) {
  const normalizedCaseId = String(caseId || '').trim();
  if (!UUID_VALUE.test(normalizedCaseId)) {
    throw investigationInputError('INVALID_RECONCILIATION_CASE_ID');
  }

  const pool = requirePool();
  const bounded = limitValue(limit, 25);
  const decodedCursor = decodeReconciliationCursor(cursor);
  const { rows: cases } = await pool.query(
    `SELECT id
       FROM reconciliation_cases
      WHERE id=$1
        AND resource_type='outbox_event'
        AND case_type=ANY($2::text[])`,
    [normalizedCaseId, OUTBOX_EVENT_INVESTIGATION_CASE_TYPES],
  );
  if (!cases[0]) {
    const error = new Error('RECONCILIATION_CASE_NOT_FOUND');
    error.code = 'RECONCILIATION_CASE_NOT_FOUND';
    error.status = 404;
    throw error;
  }

  const { rows } = await pool.query(
    `SELECT n.id,
            n.case_id AS "caseId",
            n.event_id AS "eventId",
            n.actor_id AS "actorId",
            n.action,
            n.reason,
            n.evidence_reference AS "evidenceReference",
            n.evidence_source_type AS "sourceType",
            n.evidence_issuer AS "issuer",
            n.artifact_sha256 AS "artifactSha256",
            to_char(n.source_observed_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS "sourceObservedAt",
            n.reviewed_case_digest AS "reviewedCaseDigest",
            n.verification,
            COALESCE(NULLIF(BTRIM(u.display_name),''),'Administrator') AS "actorDisplayName",
            to_char(n.created_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS "createdAt"
       FROM reconciliation_case_events n
       JOIN users u ON u.id=n.actor_id
      WHERE n.case_id=$1
        AND (
          $2::timestamptz IS NULL
          OR (n.created_at,n.id)<($2::timestamptz,$3::uuid)
        )
      ORDER BY n.created_at DESC,n.id DESC
      LIMIT $4`,
    [
      normalizedCaseId,
      decodedCursor?.createdAt ?? null,
      decodedCursor?.id ?? null,
      bounded + 1,
    ],
  );

  const hasMore = rows.length > bounded;
  const notes = rows.slice(0, bounded);
  return {
    notes,
    hasMore,
    nextCursor: hasMore && notes.length
      ? encodeReconciliationCursor(notes[notes.length - 1])
      : null,
  };
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
