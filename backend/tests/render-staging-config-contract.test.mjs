import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const moduleUrl = new URL('../src/config.js', import.meta.url).href;
const baseEnv = {
  NODE_ENV: 'production',
  RENDER: 'true',
  HOPE_STAGING_MODE: 'true',
  HOPE_STAGING_PROVIDER: 'render',
  HOPE_STAGING_READONLY_STARTUP: 'true',
  RENDER_EXTERNAL_URL: 'https://hopev2-staging.onrender.com',
  RENDER_SERVICE_ID: 'srv-render-hope-stage-123',
  STAGING_RENDER_SERVICE_ID: 'srv-render-hope-stage-123',
  TRUST_PROXY: 'true',
  TRUST_PROXY_HEADER: 'cf-connecting-ip',
  DATABASE_URL: 'postgresql://hope:secret@ep-preview.neon.tech/hope?sslmode=require',
  RATE_LIMIT_STORE: 'postgres',
  ACCESS_TOKEN_SECRET: 'a'.repeat(48),
  REFRESH_TOKEN_SECRET: 'b'.repeat(48),
  METRICS_TOKEN: 'm'.repeat(32),
  GOOGLE_AUTH_ENABLED: 'true',
  GOOGLE_OAUTH_CLIENT_ID: 'hope-preview.apps.googleusercontent.com',
  ADMIN_PANEL_USERNAME: 'hope-admin',
  ADMIN_PANEL_ALLOWED_EMAIL: 'owner@example.com',
  ADMIN_MFA_REQUIRED: 'true',
  ADMIN_MFA_ENCRYPTION_KEY: 'k'.repeat(40),
  HOPE_MAINTENANCE_HMAC_SECRET: 'h'.repeat(48),
  MAINTENANCE_LEASE_SECONDS: '120',
  STORAGE_BACKEND: 's3',
  S3_BUCKET: 'v2hope-private',
  S3_PREFIX: 'hope-staging',
  S3_REGION: 'eu-west-1',
  S3_ENDPOINT: 'https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3',
  S3_FORCE_PATH_STYLE: 'true',
  AWS_ACCESS_KEY_ID: 'supabase-test-access-key',
  AWS_SECRET_ACCESS_KEY: 'supabase-test-secret-key',
  SUPABASE_SERVICE_ROLE_KEY: 'supabase-preview-server-side-key-with-at-least-32-bytes',
  PAYMENT_PROVIDER: 'internal',
  PAYMENT_CURRENCY: 'TOMAN',
  UPLOAD_INTENT_TTL_SECONDS: '300',
};

function loadConfig(overrides = {}) {
  const env = { ...process.env };
  for (const key of [...Object.keys(baseEnv), 'VERCEL_ENV', 'HOPE_SERVERLESS_MODE', 'RENDER', 'RENDER_EXTERNAL_URL', 'HOPE_STAGING_PROVIDER', 'HOPE_STAGING_READONLY_STARTUP']) delete env[key];
  for (const key of ['PUBLIC_BASE_URL', 'ALLOWED_CORS_ORIGINS', 'TRUST_PROXY', 'TRUST_PROXY_HEADER', 'ALERT_WEBHOOK_URL', 'NOTIFICATION_EMAIL_URL', 'NOTIFICATION_PUSH_URL']) delete env[key];
  Object.assign(env, baseEnv, overrides);
  return spawnSync(process.execPath, ['--input-type=module', '-e', `import(${JSON.stringify(moduleUrl)}).then(({config}) => console.log(JSON.stringify({adminMfaRequired:config.adminMfaRequired,publicBaseUrl:config.publicBaseUrl,allowedCorsOrigins:config.allowedCorsOrigins,s3Prefix:config.s3Prefix}))).catch((error) => { console.error(error.message); process.exit(2) })`], {
    env, encoding: 'utf8', timeout: 5000,
  });
}

test('Render Staging derives its HTTPS public origin and enforces the private isolated storage prefix', () => {
  const result = loadConfig();
  assert.equal(result.status, 0, result.stderr || result.stdout);
  const config = JSON.parse(result.stdout.trim());
  assert.equal(config.publicBaseUrl, 'https://hopev2-staging.onrender.com');
  assert.deepEqual(config.allowedCorsOrigins, ['https://hopev2-staging.onrender.com']);
  assert.equal(config.s3Prefix, 'hope-staging');
  assert.equal(config.adminMfaRequired, true);
});

test('Render Staging refuses a missing Render runtime identity', () => {
  const result = loadConfig({ RENDER: 'false' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /Render Staging requires RENDER=true/);
});

test('Render Staging refuses public-bucket or non-isolated object prefixes', () => {
  const publicBucket = loadConfig({ S3_BUCKET: 'v2hope-public' });
  assert.notEqual(publicBucket.status, 0);
  assert.match(publicBucket.stderr, /v2hope-private/);
  const sharedPrefix = loadConfig({ S3_PREFIX: 'uploads' });
  assert.notEqual(sharedPrefix.status, 0);
  assert.match(sharedPrefix.stderr, /S3_PREFIX=hope-staging/);
});

test('Render Staging rejects non-HTTPS, foreign-host, or path-bearing external URLs', () => {
  for (const url of ['http://hopev2-staging.onrender.com', 'https://example.com', 'https://hopev2-staging.onrender.com/path']) {
    const result = loadConfig({ RENDER_EXTERNAL_URL: url, PUBLIC_BASE_URL: url });
    assert.notEqual(result.status, 0, `unexpectedly accepted ${url}`);
  }
});

test('Render Staging cannot relax Production configuration outside the explicit Render deployment', () => {
  const result = loadConfig({ HOPE_STAGING_PROVIDER: 'vercel', RENDER: 'false', TRUST_PROXY: 'false', PUBLIC_BASE_URL: 'https://hope-production.example.com' });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /ALERT_WEBHOOK_URL must be set in production/);
});

test('Render Staging preserves the internal TOMAN-only payment ledger', () => {
  const simulator = loadConfig({ PAYMENT_PROVIDER: 'simulator', PAYMENT_CURRENCY: 'USD' });
  assert.notEqual(simulator.status, 0);
  assert.match(simulator.stderr, /PAYMENT_PROVIDER=internal and PAYMENT_CURRENCY=TOMAN/);
});


test('Render Staging rejects an untrusted or unsafe proxy identity configuration', () => {
  const disabled = loadConfig({ TRUST_PROXY: 'false' });
  assert.notEqual(disabled.status, 0);
  assert.match(disabled.stderr, /TRUST_PROXY=true and TRUST_PROXY_HEADER=cf-connecting-ip/);
  const forwarded = loadConfig({ TRUST_PROXY_HEADER: 'x-forwarded-for' });
  assert.notEqual(forwarded.status, 0);
  assert.match(forwarded.stderr, /TRUST_PROXY=true and TRUST_PROXY_HEADER=cf-connecting-ip/);
});


test('Render Staging requires a bounded transaction-pooler-compatible maintenance lease', () => {
  const tooShort = loadConfig({ MAINTENANCE_LEASE_SECONDS: '30' });
  assert.notEqual(tooShort.status, 0);
  assert.match(tooShort.stderr, /MAINTENANCE_LEASE_SECONDS/);
  const tooLong = loadConfig({ MAINTENANCE_LEASE_SECONDS: '601' });
  assert.notEqual(tooLong.status, 0);
  assert.match(tooLong.stderr, /MAINTENANCE_LEASE_SECONDS/);
});


test('Render Staging refuses to start without its exact approved Render service identity', () => {
  const missing = loadConfig({ STAGING_RENDER_SERVICE_ID: undefined });
  assert.notEqual(missing.status, 0);
  assert.match(missing.stderr, /STAGING_RENDER_SERVICE_ID.*RENDER_SERVICE_ID/);
  const mismatch = loadConfig({ STAGING_RENDER_SERVICE_ID: 'srv-another-service' });
  assert.notEqual(mismatch.status, 0);
  assert.match(mismatch.stderr, /STAGING_RENDER_SERVICE_ID.*RENDER_SERVICE_ID/);
});
