import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const moduleUrl = new URL('../src/config.js', import.meta.url).href;
const baseEnv = {
  NODE_ENV: 'production',
  VERCEL_ENV: 'preview',
  HOPE_STAGING_MODE: 'true',
  HOPE_SERVERLESS_MODE: 'true',
  VERCEL_URL: 'hopev2-staging-branch.vercel.app',
  DATABASE_URL: 'postgresql://hope:secret@ep-test.neon.tech/hope?sslmode=require',
  RATE_LIMIT_STORE: 'postgres',
  ACCESS_TOKEN_SECRET: 'a'.repeat(48),
  REFRESH_TOKEN_SECRET: 'b'.repeat(48),
  METRICS_TOKEN: 'm'.repeat(32),
  GOOGLE_AUTH_ENABLED: 'true',
  GOOGLE_OAUTH_CLIENT_ID: 'hope-preview.apps.googleusercontent.com',
  ADMIN_PANEL_USERNAME: 'hope-admin',
  ADMIN_MFA_ENCRYPTION_KEY: 'k'.repeat(40),
  HOPE_MAINTENANCE_HMAC_SECRET: 'h'.repeat(48),
  STORAGE_BACKEND: 's3',
  S3_BUCKET: 'v2hope-private',
  S3_REGION: 'eu-west-1',
  S3_ENDPOINT: 'https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3',
  S3_FORCE_PATH_STYLE: 'true',
  AWS_ACCESS_KEY_ID: 'supabase-test-access-key',
  AWS_SECRET_ACCESS_KEY: 'supabase-test-secret-key',
  SUPABASE_SERVICE_ROLE_KEY: 'supabase-preview-server-side-key-with-at-least-32-bytes',
  PAYMENT_PROVIDER: 'internal',
  PAYMENT_CURRENCY: 'TOMAN',
};

function loadConfig(overrides = {}) {
  const env = { ...process.env };
  for (const key of [
    'DATABASE_URL','VERCEL_URL','PUBLIC_BASE_URL','ALLOWED_CORS_ORIGINS','ACCESS_TOKEN_SECRET','REFRESH_TOKEN_SECRET',
    'METRICS_TOKEN','GOOGLE_AUTH_ENABLED','GOOGLE_OAUTH_CLIENT_ID','ADMIN_PANEL_USERNAME','ADMIN_MFA_ENCRYPTION_KEY',
    'HOPE_MAINTENANCE_HMAC_SECRET','STORAGE_BACKEND','S3_BUCKET','S3_REGION','S3_ENDPOINT','S3_FORCE_PATH_STYLE',
    'AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','SUPABASE_SERVICE_ROLE_KEY','PAYMENT_PROVIDER','PAYMENT_CURRENCY','ALERT_WEBHOOK_URL',
    'NOTIFICATION_EMAIL_URL','NOTIFICATION_PUSH_URL','RESET_TOKEN_DELIVERY_MODE','RESET_TOKEN_DELIVERY_URL',
  ]) delete env[key];
  Object.assign(env, baseEnv, overrides);
  return spawnSync(process.execPath, ['--input-type=module', '-e', `import(${JSON.stringify(moduleUrl)}).then(({config}) => { if (!config.adminMfaRequired) process.exit(3); console.log('HOPE_STAGING_PREVIEW_CONFIG_OK PUBLIC_BASE_URL=' + config.publicBaseUrl) }).catch((error) => { console.error(error.message); process.exit(2) })`], {
    env,
    encoding: 'utf8',
    timeout: 5000,
  });
}

test('Vercel Preview staging mode validates core controls without requiring real Production webhooks', () => {
  const result = loadConfig();
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /HOPE_STAGING_PREVIEW_CONFIG_OK/);
});

test('Preview staging mode still rejects a Production Supabase bucket', () => {
  const result = loadConfig({ S3_BUCKET: 'v2hope-production-private' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /v2hope-private/);
});

test('Preview staging mode still rejects external payment providers', () => {
  const result = loadConfig({ PAYMENT_PROVIDER: 'webhook' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /PAYMENT_PROVIDER=internal and PAYMENT_CURRENCY=TOMAN/);
});

test('HOPE_STAGING_MODE never relaxes the real Vercel Production environment', () => {
  const result = loadConfig({ VERCEL_ENV: 'production', HOPE_STAGING_MODE: 'true' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /ALERT_WEBHOOK_URL must be set in production/);
});


test('Preview staging rejects simulator/USD payment configuration and preserves the TOMAN internal ledger', () => {
  const simulator = loadConfig({ PAYMENT_PROVIDER: 'simulator', PAYMENT_CURRENCY: 'USD' });
  assert.notEqual(simulator.status, 0);
  assert.match(simulator.stderr, /PAYMENT_PROVIDER=internal and PAYMENT_CURRENCY=TOMAN/);
  const wrongCurrency = loadConfig({ PAYMENT_PROVIDER: 'internal', PAYMENT_CURRENCY: 'USD' });
  assert.notEqual(wrongCurrency.status, 0);
  assert.match(wrongCurrency.stderr, /PAYMENT_PROVIDER=internal and PAYMENT_CURRENCY=TOMAN/);
});

test('VERCEL_URL does not implicitly change PUBLIC_BASE_URL outside explicit HOPE Staging Preview mode', () => {
  const result = loadConfig({ NODE_ENV: 'test', ADMIN_MFA_REQUIRED: 'true', HOPE_STAGING_MODE: 'false', VERCEL_ENV: 'development', VERCEL_URL: 'hopev2-preview.vercel.app' });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /HOPE_STAGING_PREVIEW_CONFIG_OK|CONFIG_IMPORTED/);
  assert.doesNotMatch(result.stdout, /PUBLIC_BASE_URL=https/);
});
