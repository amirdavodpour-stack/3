import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

process.env.NODE_ENV = 'test';
process.env.VERCEL_ENV = 'preview';
process.env.VERCEL_URL = 'hopev2-staging-branch.vercel.app';
process.env.HOPE_STAGING_MODE = 'true';
process.env.HOPE_SERVERLESS_MODE = 'true';
process.env.HOPE_MAINTENANCE_HMAC_SECRET = 'TEST_ONLY_MAINTENANCE_HMAC_KEY_123456789';
process.env.RATE_LIMIT_STORE = 'postgres';
process.env.ACCESS_TOKEN_SECRET = 'TEST_ONLY_ACCESS_TOKEN_KEY_12345678901234567890';
process.env.REFRESH_TOKEN_SECRET = 'TEST_ONLY_REFRESH_TOKEN_KEY_98765432109876543210';
process.env.METRICS_TOKEN = 'TEST_ONLY_METRICS_TOKEN_123456789012345';
process.env.GOOGLE_AUTH_ENABLED = 'true';
process.env.GOOGLE_OAUTH_CLIENT_ID = 'hope-preview.apps.googleusercontent.com';
process.env.ADMIN_PANEL_USERNAME = 'hope-admin';
process.env.ADMIN_MFA_REQUIRED = 'true';
process.env.ADMIN_MFA_ENCRYPTION_KEY = 'TEST_ONLY_ADMIN_MFA_KEY_123456789012345678';
process.env.STORAGE_BACKEND = 's3';
process.env.S3_BUCKET = 'v2hope-private';
process.env.S3_REGION = 'eu-west-1';
process.env.S3_ENDPOINT = 'https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3';
process.env.S3_FORCE_PATH_STYLE = 'true';
process.env.AWS_ACCESS_KEY_ID = 'LOCAL_TEST_ONLY_ACCESS';
process.env.AWS_SECRET_ACCESS_KEY = 'LOCAL_TEST_ONLY_SECRET';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'LOCAL_TEST_ONLY_SUPABASE_SERVICE_ROLE_KEY_123456789';
process.env.PAYMENT_PROVIDER = 'internal';
process.env.PAYMENT_CURRENCY = 'TOMAN';
process.env.DATA_FILE ||= '/tmp/hope-serverless-maintenance-postgres.json';
const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const [dbModule, runner, migrationModule, leaseMigrationModule] = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/maintenance_runner.js'),
      import('../src/db/migrations/061_serverless_maintenance_runs.js'),
      import('../src/db/migrations/062_serverless_maintenance_lease.js'),
    ])
  : [null, null, null, null];
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const requestIds = new Set();
const createId = () => { const id = crypto.randomUUID(); requestIds.add(id); return id; };
const jobs = () => ({
  outbox: async () => ({ claimed: 1, processed: 1, failed: 0 }),
  reconciliation: async () => ({ scanned: 1, resolved: 1, pending: 0, cases: 0 }),
  cleanup: async () => ({ scanned: 1, deletedObjects: 1, deletedIntents: 1, failedObjects: 0 }),
});

after(async () => {
  if (enabled && requestIds.size) {
    await pool.query('DELETE FROM maintenance_leases WHERE owner_request_id = ANY($1::uuid[])', [[...requestIds]]).catch(() => {});
    await pool.query('DELETE FROM maintenance_runs WHERE request_id = ANY($1::uuid[])', [[...requestIds]]).catch(() => {});
  }
  if (enabled) await dbModule.db.close();
});

test('migration 061 and 062 create replay history and an atomic maintenance lease', {
  skip: !enabled,
  timeout: 30_000,
}, async () => {
  assert.equal(migrationModule.migration.version, 61);
  assert.equal(migrationModule.migration.name, 'serverless_maintenance_runs');
  assert.equal(leaseMigrationModule.migration.version, 62);
  assert.equal(leaseMigrationModule.migration.name, 'serverless_maintenance_lease');
  const { rows } = await pool.query(
    `SELECT column_name FROM information_schema.columns
      WHERE table_schema=current_schema() AND table_name='maintenance_runs'`,
  );
  const columns = new Set(rows.map((row) => row.column_name));
  for (const name of ['request_id', 'status', 'started_at', 'finished_at', 'result', 'failure_code']) {
    assert.ok(columns.has(name), `maintenance_runs is missing ${name}`);
  }
  const leaseColumns = await pool.query(
    `SELECT column_name FROM information_schema.columns
      WHERE table_schema=current_schema() AND table_name='maintenance_leases'`,
  );
  const leaseNames = new Set(leaseColumns.rows.map((row) => row.column_name));
  for (const name of ['lock_name', 'owner_request_id', 'expires_at', 'updated_at']) {
    assert.ok(leaseNames.has(name), `maintenance_leases is missing ${name}`);
  }
});

test('PostgreSQL runner persists one completion and rejects a duplicate request UUID', {
  skip: !enabled,
  timeout: 30_000,
}, async () => {
  const requestId = createId();
  let calls = 0;
  const work = {
    outbox: async () => { calls += 1; return { claimed: 1 }; },
    reconciliation: async () => { calls += 1; return { scanned: 1 }; },
    cleanup: async () => { calls += 1; return { scanned: 1 }; },
  };
  const first = await runner.runMaintenanceOnce({ pool, requestId, jobs: work });
  const replay = await runner.runMaintenanceOnce({ pool, requestId, jobs: work });
  assert.equal(first.status, 'completed');
  assert.equal(replay.status, 'replay');
  assert.equal(calls, 3);
  const { rows } = await pool.query('SELECT status,result FROM maintenance_runs WHERE request_id=$1', [requestId]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].status, 'COMPLETED');
  assert.deepEqual(rows[0].result, { outbox: { claimed: 1 }, reconciliation: { scanned: 1 }, cleanup: { scanned: 1 } });
});

test('PostgreSQL lease prevents overlapping maintenance runs through transaction pooling', {
  skip: !enabled,
  timeout: 30000,
}, async () => {
  const firstId = createId();
  const secondId = createId();
  let signalStarted;
  let finishFirst;
  const started = new Promise((resolve) => { signalStarted = resolve; });
  const gate = new Promise((resolve) => { finishFirst = resolve; });
  let firstCalls = 0;
  const first = runner.runMaintenanceOnce({
    pool,
    requestId: firstId,
    jobs: {
      outbox: async () => { firstCalls += 1; signalStarted(); await gate; return {}; },
      reconciliation: async () => { firstCalls += 1; return {}; },
      cleanup: async () => { firstCalls += 1; return {}; },
    },
  });
  await started;
  let secondCalls = 0;
  const second = await runner.runMaintenanceOnce({
    pool,
    requestId: secondId,
    jobs: {
      outbox: async () => { secondCalls += 1; return {}; },
      reconciliation: async () => { secondCalls += 1; return {}; },
      cleanup: async () => { secondCalls += 1; return {}; },
    },
  });
  assert.equal(second.status, 'busy');
  assert.equal(secondCalls, 0);
  finishFirst();
  assert.equal((await first).status, 'completed');
  assert.equal(firstCalls, 3);
  const leases = await pool.query('SELECT lock_name FROM maintenance_leases');
  assert.equal(leases.rows.length, 0);
});

test('PostgreSQL runner stores a bounded failure code and never persists the raw error message', {
  skip: !enabled,
  timeout: 30_000,
}, async () => {
  const requestId = createId();
  const error = Object.assign(new Error('private token must never be stored'), { code: 'PROVIDER_UNAVAILABLE' });
  await assert.rejects(
    () => runner.runMaintenanceOnce({
      pool,
      requestId,
      jobs: { outbox: async () => { throw error; }, reconciliation: async () => ({}), cleanup: async () => ({}) },
    }),
    /private token/,
  );
  const { rows } = await pool.query('SELECT status,failure_code,result::text AS result FROM maintenance_runs WHERE request_id=$1', [requestId]);
  assert.equal(rows[0].status, 'FAILED');
  assert.equal(rows[0].failure_code, 'PROVIDER_UNAVAILABLE');
  assert.equal(rows[0].result, null);
});


test('PostgreSQL maintenance runner marks an abandoned request failed after a crashed invocation', {
  skip: !enabled,
  timeout: 30000,
}, async () => {
  const abandonedId = createId();
  const currentId = createId();
  await pool.query(
    "INSERT INTO maintenance_runs(request_id,status,started_at) VALUES($1,'RUNNING',NOW()-INTERVAL '20 minutes')",
    [abandonedId],
  );
  await runner.runMaintenanceOnce({ pool, requestId: currentId, jobs: jobs() });
  const { rows } = await pool.query('SELECT status,failure_code FROM maintenance_runs WHERE request_id=$1', [abandonedId]);
  assert.equal(rows[0].status, 'FAILED');
  assert.equal(rows[0].failure_code, 'RUN_ABANDONED');
});


test('Vercel serverless startup verifies PostgreSQL migration checksums without running DDL', {
  skip: !enabled,
  timeout: 30000,
}, async () => {
  const { initializeDatabaseForRuntime } = await import('../src/db/startup.js');
  const { assertDatabaseSchemaCurrent } = await import('../src/db/migrations.js');
  const result = await initializeDatabaseForRuntime({
    env: { HOPE_SERVERLESS_MODE: 'true', VERCEL_ENV: 'preview', HOPE_STAGING_MODE: 'true' },
    pool,
    initDatabase: async () => { throw new Error('serverless startup must not run migrations'); },
    seedBaseData: async () => { throw new Error('serverless startup must not write seed data'); },
    assertSchemaCurrent: assertDatabaseSchemaCurrent,
  });
  assert.deepEqual(result, { mode: 'serverless-preview' });
});
