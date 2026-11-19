import crypto from 'node:crypto';

export const MAINTENANCE_LOCK_NAME = 'serverless-maintenance';
export const DEFAULT_MAINTENANCE_LEASE_SECONDS = 120;
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FAILURE_CODE = /^[A-Z0-9_]{1,80}$/;

function safeFailureCode(error) {
  const candidate = String(error?.code || 'MAINTENANCE_FAILED').toUpperCase();
  return FAILURE_CODE.test(candidate) ? candidate : 'MAINTENANCE_FAILED';
}

async function renewLease(pool, requestId, leaseSeconds) {
  const { rows } = await pool.query(
    `UPDATE maintenance_leases
        SET expires_at=NOW() + ($3 * INTERVAL '1 second'), updated_at=NOW()
      WHERE lock_name=$1 AND owner_request_id=$2 AND expires_at > NOW()
      RETURNING owner_request_id`,
    [MAINTENANCE_LOCK_NAME, requestId, leaseSeconds],
  );
  if (!rows?.[0]) {
    const error = new Error('Maintenance lease was lost before the next bounded batch');
    error.code = 'MAINTENANCE_LEASE_LOST';
    throw error;
  }
}

export async function runMaintenanceOnce({
  pool,
  requestId,
  jobs,
  leaseSeconds = DEFAULT_MAINTENANCE_LEASE_SECONDS,
} = {}) {
  if (!pool || typeof pool.query !== 'function') throw new TypeError('pool must provide query()');
  if (typeof requestId !== 'string' || !UUID_V4.test(requestId)) throw new TypeError('requestId must be a UUID v4');
  if (!Number.isSafeInteger(leaseSeconds) || leaseSeconds < 60 || leaseSeconds > 600) {
    throw new RangeError('leaseSeconds must be an integer between 60 and 600');
  }
  if (!jobs || ['outbox', 'reconciliation', 'cleanup'].some((name) => typeof jobs[name] !== 'function')) {
    throw new TypeError('jobs must provide outbox, reconciliation, and cleanup functions');
  }

  // A single atomic upsert acquires a durable lease. Unlike session advisory
  // locks, this works through Neon/PgBouncer transaction pooling and does not
  // hold a database connection while bounded jobs perform their own queries.
  const lease = await pool.query(
    `INSERT INTO maintenance_leases(lock_name,owner_request_id,expires_at,updated_at)
     VALUES($1,$2,NOW() + ($3 * INTERVAL '1 second'),NOW())
     ON CONFLICT(lock_name) DO UPDATE SET
       owner_request_id=EXCLUDED.owner_request_id,
       expires_at=EXCLUDED.expires_at,
       updated_at=NOW()
     WHERE maintenance_leases.expires_at <= NOW()
     RETURNING owner_request_id`,
    [MAINTENANCE_LOCK_NAME, requestId, leaseSeconds],
  );
  if (!lease.rows?.[0]) return { status: 'busy' };

  let runInserted = false;
  try {
    const inserted = await pool.query(
      `INSERT INTO maintenance_runs(request_id,status)
       VALUES($1,'RUNNING')
       ON CONFLICT(request_id) DO NOTHING
       RETURNING request_id`,
      [requestId],
    );
    runInserted = Boolean(inserted.rows?.[0]);
    if (!runInserted) return { status: 'replay' };

    // A previous process can leave a durable RUNNING record after its lease
    // expires. Since this invocation now owns the singleton lease, older
    // RUNNING records beyond the lease grace period are abandoned.
    await pool.query(
      `UPDATE maintenance_runs
          SET status='FAILED', finished_at=NOW(), failure_code='RUN_ABANDONED'
        WHERE status='RUNNING' AND started_at < NOW() - (($1 + 30) * INTERVAL '1 second')`,
      [leaseSeconds],
    );
    await pool.query(
      `DELETE FROM maintenance_runs
        WHERE status IN ('COMPLETED','FAILED')
          AND started_at < NOW() - INTERVAL '30 days'`,
    );

    let result;
    try {
      const outbox = await jobs.outbox();
      await renewLease(pool, requestId, leaseSeconds);
      const reconciliation = await jobs.reconciliation();
      await renewLease(pool, requestId, leaseSeconds);
      const cleanup = await jobs.cleanup();
      await renewLease(pool, requestId, leaseSeconds);
      result = { outbox, reconciliation, cleanup };
    } catch (error) {
      await pool.query(
        `UPDATE maintenance_runs
            SET status='FAILED', finished_at=NOW(), failure_code=$2
          WHERE request_id=$1`,
        [requestId, safeFailureCode(error)],
      ).catch(() => {});
      throw error;
    }

    await pool.query(
      `UPDATE maintenance_runs
          SET status='COMPLETED', finished_at=NOW(), result=$2::jsonb
        WHERE request_id=$1`,
      [requestId, JSON.stringify(result)],
    );
    return { status: 'completed', requestId, ...result };
  } finally {
    // Owner matching is the fencing condition: an old invocation can never
    // release a lease acquired by a newer one after expiry.
    await pool.query(
      'DELETE FROM maintenance_leases WHERE lock_name=$1 AND owner_request_id=$2',
      [MAINTENANCE_LOCK_NAME, requestId],
    ).catch(() => {});
  }
}

export function maintenanceRequestId() {
  return crypto.randomUUID();
}
