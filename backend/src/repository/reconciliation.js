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
