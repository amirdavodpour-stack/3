import test from 'node:test';
import assert from 'node:assert/strict';
import { initializeDatabaseForRuntime } from '../src/db/startup.js';

function makeDependencies() {
  const calls = [];
  const client = { release() { calls.push('release'); } };
  const pool = { async connect() { calls.push('connect'); return client; } };
  return {
    calls,
    pool,
    client,
    initDatabase: async () => calls.push('initDatabase'),
    seedBaseData: async () => calls.push('seedBaseData'),
    assertSchemaCurrent: async (connection) => { assert.equal(connection, client); calls.push('assertSchemaCurrent'); },
  };
}

test('Render Staging startup verifies the existing Neon schema read-only and never migrates or seeds', async () => {
  const deps = makeDependencies();
  const result = await initializeDatabaseForRuntime({
    env: { RENDER: 'true', HOPE_STAGING_MODE: 'true', HOPE_STAGING_PROVIDER: 'render', HOPE_STAGING_READONLY_STARTUP: 'true' },
    ...deps,
  });
  assert.deepEqual(result, { mode: 'render-staging-readonly' });
  assert.deepEqual(deps.calls, ['connect', 'assertSchemaCurrent', 'release']);
});

test('Render read-only startup fails closed outside the identified Render Staging service', async () => {
  for (const env of [
    { RENDER: 'false', HOPE_STAGING_MODE: 'true', HOPE_STAGING_PROVIDER: 'render', HOPE_STAGING_READONLY_STARTUP: 'true' },
    { RENDER: 'true', HOPE_STAGING_MODE: 'false', HOPE_STAGING_PROVIDER: 'render', HOPE_STAGING_READONLY_STARTUP: 'true' },
    { RENDER: 'true', HOPE_STAGING_MODE: 'true', HOPE_STAGING_PROVIDER: 'vercel', HOPE_STAGING_READONLY_STARTUP: 'true' },
  ]) {
    const deps = makeDependencies();
    await assert.rejects(
      () => initializeDatabaseForRuntime({ env, ...deps }),
      /only permitted in the identified Render Staging service/,
    );
    assert.deepEqual(deps.calls, []);
  }
});
