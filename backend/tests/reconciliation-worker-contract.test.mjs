import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const worker = fs.readFileSync(new URL('../src/reconciliation_worker.js', import.meta.url), 'utf8');
const repo = fs.readFileSync(new URL('../src/repository/reconciliation.js', import.meta.url), 'utf8');
const provider = fs.readFileSync(new URL('../src/payment_provider.js', import.meta.url), 'utf8');
const server = fs.readFileSync(new URL('../src/server.js', import.meta.url), 'utf8');
const migration = fs.readFileSync(new URL('../src/db/migrations/011_reconciliation_case_dedupe.js', import.meta.url), 'utf8');
const pkg = JSON.parse(fs.readFileSync(new URL('../package.json', import.meta.url), 'utf8'));



test('reconciliation scans UNKNOWN payouts and never retries provider execution blindly', () => {
  assert.match(worker, /listUnknownPayoutsForReconciliation/);
  assert.match(worker, /getPayoutStatus/);
  assert.doesNotMatch(worker, /createPayout\(/);
  assert.match(worker, /resolvePayoutUnknown/);
});

test('reconciliation persists deduplicated active cases before/around recovery', () => {
  assert.match(repo, /INSERT INTO reconciliation_cases/);
  assert.match(repo, /ON CONFLICT \(case_type,resource_type,resource_id\)/);
  assert.match(repo, /WHERE status IN \('OPEN','INVESTIGATING'\)/);
  assert.match(migration, /reconciliation_cases_active_resource_uq/);
});

test('reconciliation requires authoritative terminal provider evidence for automatic recovery', () => {
  assert.match(worker, /status === 'SUCCEEDED' \|\| status === 'FAILED'/);
  assert.match(worker, /status === 'SUCCEEDED' && !result\.providerRef/);
  assert.match(worker, /PAYOUT_SUCCESS_MISSING_PROVIDER_REF/);
});

test('provider boundary exposes payout status lookup for internal recovery and server starts reconciliation worker', () => {
  assert.match(provider, /async getPayoutStatus/);
  assert.match(server, /startReconciliationWorker/);
  assert.match(pkg.scripts['check:migrations'], /011_reconciliation_case_dedupe\.js/);
});


test('internal provider status lookup can resolve a previously UNKNOWN payout without re-executing it', async () => {
  const previous = process.env.INTERNAL_PROVIDER_PAYOUT_OUTCOME;
  process.env.INTERNAL_PROVIDER_PAYOUT_OUTCOME = 'SUCCEEDED';
  try {
    const { createPaymentProvider } = await import('../src/payment_provider.js');
    const provider = createPaymentProvider('internal');
    const result = await provider.getPayoutStatus({ payoutId:'payout-1', amount:1200, currency:'TOMAN', idempotencyKey:'reconcile:payout-1' });
    assert.equal(result.status, 'SUCCEEDED');
    assert.match(result.providerRef, /^INT-PAY-/);
  } finally {
    if (previous == null) delete process.env.INTERNAL_PROVIDER_PAYOUT_OUTCOME;
    else process.env.INTERNAL_PROVIDER_PAYOUT_OUTCOME = previous;
  }
});
