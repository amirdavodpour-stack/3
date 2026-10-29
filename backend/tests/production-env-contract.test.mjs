import test from 'node:test';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { isInternalWalletPayoutEnabled } from '../src/wallet_payout_policy.js';

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

test('production validator keeps the service bootable when only the user-top-up flag is set; runtime policy disables the feature', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    INTERNAL_WALLET_USER_TOPUP_ENABLED: 'true',
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'false',
  });
  assert.equal(result.status, 0, result.stdout + '\n' + result.stderr);
  assert.match(result.stdout, /Production environment contract PASS/);
});

test('production validator keeps the service bootable when only the staging override is set; runtime policy disables the feature', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    INTERNAL_WALLET_USER_TOPUP_ENABLED: 'false',
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
  });
  assert.equal(result.status, 0, result.stdout + '\n' + result.stderr);
  assert.match(result.stdout, /Production environment contract PASS/);
});

test('production validator rejects the staging top-up override without exact Railway project identity', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    INTERNAL_WALLET_USER_TOPUP_ENABLED: 'true',
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + '\n' + result.stderr, /designated Staging Railway project/);
});

test('production validator rejects staging top-up flags on the actual Production Railway project', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    INTERNAL_WALLET_USER_TOPUP_ENABLED: 'true',
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
    RAILWAY_PROJECT_ID: 'b12b7c1e-4dcc-470e-b87a-c63035c6e342',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + '\n' + result.stderr, /designated Staging Railway project/);
});

test('production validator permits paired staging top-up flags only for the designated Staging Railway project', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    INTERNAL_WALLET_USER_TOPUP_ENABLED: 'true',
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
    RAILWAY_PROJECT_ID: '8c686259-09c6-4609-bbe7-4ea25e769e18',
  });
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


test('release-validation scopes the configured admin username to the production validator step', () => {
  const job = releaseValidationWorkflow.match(/  production_artifact:[\s\S]*?(?=  release_gate:)/)?.[0] || '';
  assert.ok(job, 'production artifact job must exist');
  assert.doesNotMatch(job, /^    env:\s*$/m, 'production credentials must not be configured at job scope');
  const block = job.match(/name: Validate production environment contract[\s\S]*?run: bash scripts\/validate-production-env\.sh/)?.[0] || '';
  assert.match(block, /ADMIN_PANEL_USERNAME:\s*\$\{\{\s*secrets\.ADMIN_PANEL_USERNAME_PRODUCTION\s*\}\}/);
  assert.doesNotMatch(job, /ADMIN_PANEL_USERNAME:\s*\$\{\{\s*env\.ADMIN_PANEL_USERNAME\s*\}\}/);
});

test('production env validator rejects identical access and refresh token secrets', () => {
  const identicalSecret = 'ci-identical-access-refresh-secret-0123456789';
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    ACCESS_TOKEN_SECRET: identicalSecret,
    REFRESH_TOKEN_SECRET: identicalSecret,
  });
  assert.notEqual(result.status, 0, 'identical token secrets must fail production validation');
  assert.match(result.stdout + '\n' + result.stderr, /ACCESS_TOKEN_SECRET and REFRESH_TOKEN_SECRET must be different/);
});

for (const variableName of ['ACCESS_TOKEN_SECRET', 'REFRESH_TOKEN_SECRET']) {
  test(`production env validator rejects placeholder-prefixed ${variableName}`, () => {
    const result = runProductionEnvValidator({
      ADMIN_PANEL_USERNAME: 'hope-admin',
      [variableName]: 'change-this-placeholder-secret-0123456789',
    });
    assert.notEqual(result.status, 0, `${variableName} must reject the runtime-forbidden placeholder prefix`);
    assert.match(result.stdout + '\n' + result.stderr, /must not use placeholder secrets/);
  });
}

for (const origin of [
  'not-an-origin',
  'https://example.invalid/path',
  'https://example.invalid?query=1',
  'https://user:pass@example.invalid',
  'ftp://example.invalid',
  'http://example.invalid',
]) {
  test(`production env validator rejects invalid CORS origin: ${origin}`, () => {
    const result = runProductionEnvValidator({
      ADMIN_PANEL_USERNAME: 'hope-admin',
      ALLOWED_CORS_ORIGINS: origin,
    });
    assert.notEqual(result.status, 0, `invalid production CORS origin must be rejected: ${origin}`);
    assert.match(result.stdout + '\n' + result.stderr, /ALLOWED_CORS_ORIGINS|Non-local production CORS origins/);
  });
}

test('production env validator allows the runtime-supported local HTTP origin', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    ALLOWED_CORS_ORIGINS: 'http://localhost:3000',
  });
  assert.equal(result.status, 0, result.stdout + '\n' + result.stderr);
  assert.match(result.stdout, /Production environment contract PASS/);
});


test('production validator rejects synthetic internal cash-out override without exact Railway project identity', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'true',
  });
  assert.notEqual(result.status, 0, 'the internal payout override must not be accepted without the dedicated staging project id');
  assert.match(result.stdout + '\n' + result.stderr, /Staging internal wallet payout is permitted only for the designated Staging Railway project/);
});

test('production validator rejects synthetic internal cash-out override on the actual production project', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'true',
    RAILWAY_PROJECT_ID: 'b12b7c1e-4dcc-470e-b87a-c63035c6e342',
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stdout + '\n' + result.stderr, /Staging internal wallet payout is permitted only for the designated Staging Railway project/);
});

test('production validator allows the synthetic internal cash-out override only in the designated staging project', () => {
  const result = runProductionEnvValidator({
    ADMIN_PANEL_USERNAME: 'hope-admin',
    STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'true',
    RAILWAY_PROJECT_ID: '8c686259-09c6-4609-bbe7-4ea25e769e18',
  });
  assert.equal(result.status, 0, result.stdout + '\n' + result.stderr);
  assert.match(result.stdout, /Production environment contract PASS/);
});


test('internal payout policy fails closed on the real production project even if NODE_ENV is misconfigured', () => {
  assert.equal(isInternalWalletPayoutEnabled({
    paymentProvider: 'internal',
    env: {
      NODE_ENV: 'test',
      RAILWAY_PROJECT_ID: 'b12b7c1e-4dcc-470e-b87a-c63035c6e342',
      STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'true',
    },
  }), false);

  assert.equal(isInternalWalletPayoutEnabled({
    paymentProvider: 'internal',
    env: {
      NODE_ENV: 'production',
      RAILWAY_PROJECT_ID: '8c686259-09c6-4609-bbe7-4ea25e769e18',
      STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'true',
    },
  }), true);

  assert.equal(isInternalWalletPayoutEnabled({
    paymentProvider: 'internal',
    env: {
      NODE_ENV: 'production',
      RAILWAY_PROJECT_ID: '8c686259-09c6-4609-bbe7-4ea25e769e18',
      STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'false',
    },
  }), false);
});
