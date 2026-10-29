import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { isInternalWalletUserTopUpEnabled, STAGING_RAILWAY_PROJECT_ID } from '../src/wallet_topup_policy.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

function policy(overrides = {}) {
  return isInternalWalletUserTopUpEnabled({
    paymentProvider: 'internal',
    enabled: true,
    env: { NODE_ENV: 'test' },
    ...overrides,
  });
}

test('internal user top-up remains available in non-production test/staging mode when explicitly enabled', () => {
  assert.equal(policy(), true);
  assert.equal(policy({ env: { NODE_ENV: 'development', INTERNAL_WALLET_USER_TOPUP_ENABLED: 'true' } }), true);
});

test('production top-up stays disabled without an explicit staging override', () => {
  assert.equal(policy({ env: { NODE_ENV: 'production' } }), false);
});

test('production staging override fails closed without Railway project identity', () => {
  assert.equal(policy({ env: { NODE_ENV: 'production', STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true' } }), false);
});

test('production staging override fails closed on the real production Railway project', () => {
  assert.equal(policy({ env: {
    NODE_ENV: 'production',
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
    RAILWAY_PROJECT_ID: 'b12b7c1e-4dcc-470e-b87a-c63035c6e342',
  } }), false);
});

test('production staging override is accepted only for the designated staging Railway project', () => {
  assert.equal(policy({ env: {
    NODE_ENV: 'production',
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
    RAILWAY_PROJECT_ID: STAGING_RAILWAY_PROJECT_ID,
  } }), true);
});

test('top-up requires both the internal provider and the explicit feature flag', () => {
  assert.equal(policy({ paymentProvider: 'webhook' }), false);
  assert.equal(policy({ enabled: false }), false);
});

test('wallet route and capability surface use the shared policy instead of duplicate flag logic', () => {
  const wallet = fs.readFileSync(path.join(root, 'backend/src/application/wallet_routes.js'), 'utf8');
  const capabilities = fs.readFileSync(path.join(root, 'backend/src/routes/config_routes.js'), 'utf8');
  assert.match(wallet, /isInternalWalletUserTopUpEnabled/);
  assert.match(capabilities, /isInternalWalletUserTopUpEnabled/);
  assert.doesNotMatch(wallet, /STAGING_ALLOW_INTERNAL_WALLET_TOPUP === 'true'/);
  assert.doesNotMatch(capabilities, /STAGING_ALLOW_INTERNAL_WALLET_TOPUP === 'true'/);
});


import {
  isInternalWalletAdminCreditEnabled,
  PRODUCTION_RAILWAY_PROJECT_ID,
  STAGING_RAILWAY_PROJECT_ID,
} from '../src/wallet_admin_credit_policy.js';

function adminCreditPolicy(overrides = {}) {
  return isInternalWalletAdminCreditEnabled({
    enabled: true,
    env: { NODE_ENV: 'test' },
    ...overrides,
  });
}

test('admin sandbox credit is denied on the real production Railway project even if NODE_ENV is misconfigured', () => {
  for (const nodeEnv of ['production', 'test', 'development', undefined]) {
    const env = { RAILWAY_PROJECT_ID: PRODUCTION_RAILWAY_PROJECT_ID };
    if (nodeEnv !== undefined) env.NODE_ENV = nodeEnv;
    assert.equal(adminCreditPolicy({ enabled: true, env }), false);
  }
});

test('production-named staging enables admin sandbox credit only with the explicit flag and staging project identity', () => {
  assert.equal(adminCreditPolicy({
    enabled: true,
    env: { NODE_ENV: 'production', RAILWAY_PROJECT_ID: STAGING_RAILWAY_PROJECT_ID },
  }), true);
  assert.equal(adminCreditPolicy({
    enabled: false,
    env: { NODE_ENV: 'production', RAILWAY_PROJECT_ID: STAGING_RAILWAY_PROJECT_ID },
  }), false);
  assert.equal(adminCreditPolicy({
    enabled: true,
    env: { NODE_ENV: 'production', STAGING_RAILWAY_PROJECT_ID },
  }), false);
});

test('non-production retains the existing admin sandbox-credit behavior unless running in the real production project', () => {
  assert.equal(adminCreditPolicy({ enabled: false, env: { NODE_ENV: 'test' } }), true);
  assert.equal(adminCreditPolicy({
    enabled: true,
    env: { NODE_ENV: 'test', RAILWAY_PROJECT_ID: PRODUCTION_RAILWAY_PROJECT_ID },
  }), false);
});

test('admin sandbox-credit route delegates to the shared fail-closed project policy', async () => {
  const route = await import('../src/application/wallet_routes.js');
  const source = route.createWalletRoutes.toString();
  assert.match(source, /isInternalWalletAdminCreditEnabled/);
});
