export async function initializeDatabaseForRuntime({
  env = process.env,
  pool,
  initDatabase,
  seedBaseData,
  assertSchemaCurrent,
} = {}) {
  const serverlessMode = env.HOPE_SERVERLESS_MODE === 'true';
  const renderReadonlyMode = env.HOPE_STAGING_READONLY_STARTUP === 'true';
  if (serverlessMode && renderReadonlyMode) throw new Error('Only one read-only staging startup mode may be enabled');
  if (serverlessMode || renderReadonlyMode) {
    if (serverlessMode && (env.VERCEL_ENV !== 'preview' || env.HOPE_STAGING_MODE !== 'true')) {
      throw new Error('HOPE_SERVERLESS_MODE is only permitted in Vercel Preview Staging');
    }
    if (renderReadonlyMode && (env.RENDER !== 'true' || env.HOPE_STAGING_MODE !== 'true' || env.HOPE_STAGING_PROVIDER !== 'render')) {
      throw new Error('Read-only startup is only permitted in the identified Render Staging service');
    }
    if (!pool || typeof pool.connect !== 'function') {
      throw new Error('A PostgreSQL pool is required for serverless Staging startup');
    }
    if (typeof assertSchemaCurrent !== 'function') throw new TypeError('assertSchemaCurrent must be a function');
    const client = await pool.connect();
    try {
      await assertSchemaCurrent(client);
    } finally {
      client.release();
    }
    return { mode: serverlessMode ? 'serverless-preview' : 'render-staging-readonly' };
  }

  if (typeof initDatabase !== 'function' || typeof seedBaseData !== 'function') {
    throw new TypeError('Managed startup requires initDatabase and seedBaseData functions');
  }
  await initDatabase();
  await seedBaseData();
  return { mode: 'managed-startup' };
}
