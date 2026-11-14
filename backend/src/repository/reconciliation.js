import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';

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
