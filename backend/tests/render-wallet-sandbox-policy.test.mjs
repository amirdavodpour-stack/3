import test from 'node:test';
import assert from 'node:assert/strict';
import { isInternalWalletUserTopUpEnabled } from '../src/wallet_topup_policy.js';
import { isInternalWalletPayoutEnabled } from '../src/wallet_payout_policy.js';
import { isInternalWalletAdminCreditEnabled } from '../src/wallet_admin_credit_policy.js';
import { PRODUCTION_RAILWAY_PROJECT_ID, STAGING_RAILWAY_PROJECT_ID } from '../src/railway_project_ids.js';

const renderStage = {
  NODE_ENV: 'production',
  RENDER: 'true',
  HOPE_STAGING_MODE: 'true',
  HOPE_STAGING_PROVIDER: 'render',
  RENDER_SERVICE_ID: 'srv-render-hope-stage-123',
  STAGING_RENDER_SERVICE_ID: 'srv-render-hope-stage-123',
  STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
  STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'true',
};

test('Render Staging permits internal TOMAN top-up and payout only with explicit exact-service identity', () => {
  assert.equal(isInternalWalletUserTopUpEnabled({ paymentProvider: 'internal', enabled: true, env: renderStage }), true);
  assert.equal(isInternalWalletPayoutEnabled({ paymentProvider: 'internal', env: renderStage }), true);
  assert.equal(isInternalWalletPayoutEnabled({ paymentProvider: 'webhook', env: renderStage }), false);
});

test('Render Staging admin sandbox credit requires the exact service identity and explicit feature setting', () => {
  assert.equal(isInternalWalletAdminCreditEnabled({ enabled: true, env: renderStage }), true);
  assert.equal(isInternalWalletAdminCreditEnabled({ enabled: false, env: renderStage }), false);
});

test('Render Staging financial sandbox features fail closed on missing, mismatched, or non-Render identity', () => {
  for (const patch of [
    { STAGING_RENDER_SERVICE_ID: undefined },
    { STAGING_RENDER_SERVICE_ID: 'srv-another-service' },
    { RENDER: 'false' },
    { HOPE_STAGING_MODE: 'false' },
    { HOPE_STAGING_PROVIDER: 'vercel' },
    { STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'false' },
    { STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'false' },
  ]) {
    const env = { ...renderStage, ...patch };
    if (patch.STAGING_RENDER_SERVICE_ID === undefined) delete env.STAGING_RENDER_SERVICE_ID;
    assert.equal(isInternalWalletUserTopUpEnabled({ paymentProvider: 'internal', enabled: true, env }), false);
    assert.equal(isInternalWalletPayoutEnabled({ paymentProvider: 'internal', env }), false);
    assert.equal(isInternalWalletAdminCreditEnabled({ enabled: true, env }), false);
  }
});

test('Railway Production denial remains dominant even if Render staging switches and exact IDs are spoofed', () => {
  const env = {
    ...renderStage,
    RAILWAY_PROJECT_ID: PRODUCTION_RAILWAY_PROJECT_ID,
    STAGING_RENDER_SERVICE_ID: renderStage.RENDER_SERVICE_ID,
  };
  assert.equal(isInternalWalletUserTopUpEnabled({ paymentProvider: 'internal', enabled: true, env }), false);
  assert.equal(isInternalWalletPayoutEnabled({ paymentProvider: 'internal', env }), false);
  assert.equal(isInternalWalletAdminCreditEnabled({ enabled: true, env }), false);
});

test('Existing Railway Staging exact-project behavior remains intact', () => {
  const env = {
    NODE_ENV: 'production',
    RAILWAY_PROJECT_ID: STAGING_RAILWAY_PROJECT_ID,
    STAGING_ALLOW_INTERNAL_WALLET_TOPUP: 'true',
    STAGING_ALLOW_INTERNAL_WALLET_PAYOUT: 'true',
  };
  assert.equal(isInternalWalletUserTopUpEnabled({ paymentProvider: 'internal', enabled: true, env }), true);
  assert.equal(isInternalWalletPayoutEnabled({ paymentProvider: 'internal', env }), true);
});
