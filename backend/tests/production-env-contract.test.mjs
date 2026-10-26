import test from 'node:test';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const workflow = fs.readFileSync(path.join(root, '.github', 'workflows', 'production-release.yml'), 'utf8');
const releaseValidationWorkflow = fs.readFileSync(path.join(root, '.github', 'workflows', 'release-validation.yml'), 'utf8');
const validator = fs.readFileSync(path.join(root, 'backend', 'scripts', 'validate-production-env.sh'), 'utf8');

test('production release env validation uses production data-store secrets', () => {
  const block = workflow.match(/name: Validate production environment contract[\s\S]*?\n      - name: Backend quality gates/)?.[0] || '';
  assert.match(block, /DATABASE_URL:\s*\$\{\{ secrets\.DATABASE_URL_PRODUCTION \}\}/);
  assert.match(block, /S3_BUCKET:\s*\$\{\{ secrets\.S3_BUCKET_PRODUCTION \}\}/);
  assert.match(block, /S3_REGION:\s*\$\{\{ secrets\.S3_REGION_PRODUCTION \}\}/);
  assert.doesNotMatch(block, /STAGING_DATABASE_URL|STAGING_S3_BUCKET/);
});

test('production env validator enforces canonical production storage and payment policy', () => {
  assert.match(validator, /case "\$STORAGE_BACKEND" in s3\)/);
  assert.match(validator, /DATABASE_URL/);
  assert.match(validator, /S3_BUCKET/);
  assert.match(validator, /PUBLIC_BASE_URL/);
  assert.match(validator, /case "\$PAYMENT_PROVIDER" in webhook\|internal\)/);
});


test('production environment rejects wildcard CORS entries and insecure custom S3 endpoints', () => {
  assert.match(validator, /some|wildcard/i);
  assert.match(validator, /S3_ENDPOINT must use HTTPS when set in production/);
  const config = fs.readFileSync(path.join(root, 'backend', 'src', 'config.js'), 'utf8');
  assert.match(config, /allowedCorsOrigins\.some/);
  assert.match(config, /s3Endpoint.*https:\/\//);
});

test('production reset delivery policy matches runtime configuration', () => {
  assert.match(validator, /RESET_TOKEN_DELIVERY_MODE=webhook is required in production/);
  assert.match(validator, /RESET_TOKEN_DELIVERY_SECRET must be at least 32 characters/);
  assert.doesNotMatch(validator, /console\|webhook/);
});


const validProductionEnv = {
  NODE_ENV: 'production',
  ACCESS_TOKEN_SECRET: 'ci-access-token-secret-012345678901234567890123',
  REFRESH_TOKEN_SECRET: 'ci-refresh-token-secret-012345678901234567890123',
  DATABASE_URL: 'postgres://ci:ci@example.invalid/hope',
  PUBLIC_BASE_URL: 'https://example.invalid',
  METRICS_TOKEN: 'ci-metrics-token-0123456789012345',
  S3_BUCKET: 'hope-ci',
  PAYMENT_PROVIDER: 'internal',
  PAYMENT_CURRENCY: 'TOMAN',
  ALLOWED_CORS_ORIGINS: 'https://example.invalid',
  STORAGE_BACKEND: 's3',
  RESET_TOKEN_DELIVERY_MODE: 'webhook',
  RESET_TOKEN_DELIVERY_URL: 'https://example.invalid/reset',
  RESET_TOKEN_DELIVERY_SECRET: 'ci-reset-delivery-secret-012345678901234567890123456789',
};

function runProductionEnvValidator(overrides = {}) {
  const env = { PATH: process.env.PATH || '/usr/bin:/bin', ...validProductionEnv, ...overrides };
  return spawnSync('sh', ['scripts/validate-production-env.sh'], {
    cwd: path.join(root, 'backend'),
    env,
    encoding: 'utf8',
  });
}

test('production env validator fails closed when runtime-required admin username is missing', () => {
  const result = runProductionEnvValidator();
  assert.notEqual(result.status, 0, 'missing ADMIN_PANEL_USERNAME must block production validation');
  assert.match(result.stdout + '\n' + result.stderr, /ADMIN_PANEL_USERNAME/);
});

test('production env validator accepts a complete admin identity configuration', () => {
  const result = runProductionEnvValidator({ ADMIN_PANEL_USERNAME: 'hope-admin' });
  assert.equal(result.status, 0, result.stdout + '\n' + result.stderr);
  assert.match(result.stdout, /Production environment contract PASS/);
});

test('production-release workflow provides all runtime-required validator inputs', () => {
  const block = workflow.match(/name: Validate production environment contract[\s\S]*?run: bash scripts\/validate-production-env\.sh/)?.[0] || '';
  for (const name of [
    'PUBLIC_BASE_URL',
    'METRICS_TOKEN',
    'PAYMENT_PROVIDER',
    'PAYMENT_CURRENCY',
    'STORAGE_BACKEND',
    'RESET_TOKEN_DELIVERY_MODE',
    'RESET_TOKEN_DELIVERY_URL',
    'ADMIN_PANEL_USERNAME',
  ]) {
    assert.match(block, new RegExp('^\\s*' + name + ':', 'm'), name + ' must be supplied to the production validator step');
  }
});


test('release-validation passes the configured admin username through to production validation', () => {
  assert.match(releaseValidationWorkflow, /ADMIN_PANEL_USERNAME:\s*\$\{\{\s*secrets\.ADMIN_PANEL_USERNAME_PRODUCTION\s*\}\}/);
  const block = releaseValidationWorkflow.match(/name: Validate production environment contract[\s\S]*?run: bash scripts\/validate-production-env\.sh/)?.[0] || '';
  assert.match(block, /ADMIN_PANEL_USERNAME:\s*\$\{\{\s*env\.ADMIN_PANEL_USERNAME\s*\}\}/);
});

[executed on device: localhost (ad4940fb-3108-4ab5-af41-ee34669dd70c)]
