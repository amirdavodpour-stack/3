import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeDatabaseForRuntime } from '../src/db/startup.js';

function spies() {
  const calls = [];
  const client = { release() { calls.push('release'); } };
  const pool = { async connect() { calls.push('connect'); return client; } };
  return {
    calls,
    client,
    pool,
    initDatabase: async () => { calls.push('initDatabase'); },
    seedBaseData: async () => { calls.push('seedBaseData'); },
    assertSchemaCurrent: async (connection) => { assert.equal(connection, client); calls.push('assertSchemaCurrent'); },
  };
}

test('Vercel Preview startup verifies schema read-only and skips migrations and seed writes', async () => {
  const f = spies();
  const result = await initializeDatabaseForRuntime({
    env: { HOPE_SERVERLESS_MODE: 'true', VERCEL_ENV: 'preview', HOPE_STAGING_MODE: 'true' },
    pool: f.pool,
    initDatabase: f.initDatabase,
    seedBaseData: f.seedBaseData,
    assertSchemaCurrent: f.assertSchemaCurrent,
  });
  assert.deepEqual(result, { mode: 'serverless-preview' });
  assert.deepEqual(f.calls, ['connect', 'assertSchemaCurrent', 'release']);
});

test('ordinary managed startup keeps the existing migration and seed behavior', async () => {
  const f = spies();
  const result = await initializeDatabaseForRuntime({
    env: { HOPE_SERVERLESS_MODE: 'false' },
    pool: f.pool,
    initDatabase: f.initDatabase,
    seedBaseData: f.seedBaseData,
    assertSchemaCurrent: f.assertSchemaCurrent,
  });
  assert.deepEqual(result, { mode: 'managed-startup' });
  assert.deepEqual(f.calls, ['initDatabase', 'seedBaseData']);
});

test('serverless mode fails closed outside Vercel Staging and never falls back to auto-migration', async () => {
  const f = spies();
  await assert.rejects(
    () => initializeDatabaseForRuntime({
      env: { HOPE_SERVERLESS_MODE: 'true', VERCEL_ENV: 'production', HOPE_STAGING_MODE: 'true' },
      pool: f.pool,
      initDatabase: f.initDatabase,
      seedBaseData: f.seedBaseData,
      assertSchemaCurrent: f.assertSchemaCurrent,
    }),
    /only permitted in Vercel Preview/,
  );
  assert.deepEqual(f.calls, []);
});

test('serverless mode fails closed when the read-only database connection is unavailable', async () => {
  const f = spies();
  await assert.rejects(
    () => initializeDatabaseForRuntime({
      env: { HOPE_SERVERLESS_MODE: 'true', VERCEL_ENV: 'preview', HOPE_STAGING_MODE: 'true' },
      pool: null,
      initDatabase: f.initDatabase,
      seedBaseData: f.seedBaseData,
      assertSchemaCurrent: f.assertSchemaCurrent,
    }),
    /PostgreSQL pool/,
  );
  assert.deepEqual(f.calls, []);
});


test('app.js wires the serverless schema verifier before composing application routes', async () => {
  const fs = await import('node:fs');
  const source = fs.readFileSync(new URL('../src/app.js', import.meta.url), 'utf8');
  assert.match(source, /initializeDatabaseForRuntime\(/);
  assert.match(source, /assertSchemaCurrent: assertDatabaseSchemaCurrent/);
  assert.doesNotMatch(source, /await initDatabase\(\);\s*await seedBaseData\(\);/);
});
