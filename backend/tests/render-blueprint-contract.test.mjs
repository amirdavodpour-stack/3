import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const blueprint = fs.readFileSync(path.join(root, 'render.yaml'), 'utf8');
const workerConfig = fs.readFileSync(new URL('../cloudflare-render-keepalive/wrangler.jsonc', import.meta.url), 'utf8');

test('Render blueprint pins an isolated Free Staging branch and disables automatic deployment', () => {
  assert.match(blueprint, /name: hopev2-staging-preview/);
  assert.match(blueprint, /plan: free/);
  assert.match(blueprint, /branch: integration\/hopev2-free-staging-serverless-20261119/);
  assert.match(blueprint, /rootDir: backend/);
  assert.match(blueprint, /autoDeploy: false/);
  assert.match(blueprint, /healthCheckPath: \/ready/);
  assert.match(blueprint, /HOPE_STAGING_PROVIDER[\s\S]*value: render/);
  assert.match(blueprint, /HOPE_STAGING_READONLY_STARTUP[\s\S]*value: "true"/);
  assert.match(blueprint, /S3_PREFIX[\s\S]*value: hope-staging/);
});

test('Render blueprint keeps financial sandbox features disabled and secrets unsynced', () => {
  for (const key of ['INTERNAL_WALLET_USER_TOPUP_ENABLED', 'INTERNAL_WALLET_ADMIN_CREDIT_ENABLED', 'STAGING_ALLOW_INTERNAL_WALLET_TOPUP', 'STAGING_ALLOW_INTERNAL_WALLET_PAYOUT']) {
    const index = blueprint.indexOf(`key: ${key}`);
    assert.notEqual(index, -1, `missing ${key}`);
    assert.match(blueprint.slice(index, index + 100), /value: "false"/);
  }
  for (const key of ['DATABASE_URL', 'ACCESS_TOKEN_SECRET', 'REFRESH_TOKEN_SECRET', 'AWS_SECRET_ACCESS_KEY', 'SUPABASE_SERVICE_ROLE_KEY', 'STAGING_RENDER_SERVICE_ID']) {
    const index = blueprint.indexOf(`key: ${key}`);
    assert.notEqual(index, -1, `missing ${key}`);
    assert.match(blueprint.slice(index, index + 80), /sync: false/);
  }
  assert.doesNotMatch(blueprint, /postgresql:\/\/[^\s]+|sb_secret_[A-Za-z0-9]+|eyJ[A-Za-z0-9._-]{20,}/);
  assert.doesNotMatch(blueprint, /key: HOPE_MAINTENANCE_HMAC_SECRET|key: MAINTENANCE_LEASE_SECONDS/);
});

test('Cloudflare keepalive remains unscheduled and not publicly addressable by default', () => {
  assert.doesNotMatch(workerConfig, /"crons"/);
  assert.match(workerConfig, /"workers_dev"\s*:\s*false/);
  assert.match(workerConfig, /"preview_urls"\s*:\s*false/);
});


test('Render Free caps background polling to bounded low-frequency intervals', () => {
  for (const [key, value] of [
    ['OUTBOX_POLL_MS', '30000'],
    ['OUTBOX_WORKER_CONCURRENCY', '1'],
    ['RECONCILIATION_POLL_MS', '300000'],
    ['RECONCILIATION_BATCH_SIZE', '1'],
    ['UPLOAD_CLEANUP_INTERVAL_MS', '3600000'],
    ['UPLOAD_CLEANUP_BATCH_SIZE', '10'],
  ]) {
    const index = blueprint.indexOf('key: ' + key);
    assert.notEqual(index, -1, 'missing ' + key);
    assert.ok(blueprint.slice(index, index + 120).includes('value: ' + JSON.stringify(value)), key + ' has an unexpected value');
  }
});
