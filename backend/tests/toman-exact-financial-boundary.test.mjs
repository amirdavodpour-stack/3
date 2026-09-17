import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import { calculatePaymentBreakdown, fundingJournal, releaseJournal, payoutJournal, refundJournal } from '../src/financial.js';
import { fromDbRow } from '../src/db/serialization.js';
import { paymentFromRow, jobFromRow } from '../src/repository/mappers.js';

test('TOMAN fee math stays integer-exact and does not use cents conversion', () => {
  const b = calculatePaymentBreakdown('MISSION', '6000000000000000', 'TOMAN');
  assert.equal(b.baseAmount, '6000000000000000');
  assert.equal(b.employerFee, '600000000000000');
  assert.equal(b.workerFee, '600000000000000');
  assert.equal(b.platformFee, '1200000000000000');
  assert.equal(b.employerCharge, '6600000000000000');
  assert.equal(b.providerPayout, '5400000000000000');
  assert.equal(b.currency, 'TOMAN');
  assert.doesNotThrow(() => fundingJournal(b));
  assert.doesNotThrow(() => releaseJournal(b));
  assert.doesNotThrow(() => payoutJournal(b));
  assert.doesNotThrow(() => refundJournal(b));
});

test('TOMAN serializer and mapper preserve PostgreSQL numeric/bigint strings', () => {
  const row = {
    id: 'p1', job_id: 'j1', payer_id: 'u1', payee_id: 'u2',
    amount: '6000000000000000', currency: 'TOMAN', status: 'HELD',
    provider_ref: null, idempotency_key: 'k', funding_previous_job_status: null,
    base_amount: '6000000000000000', employer_fee: '600000000000000', worker_fee: '600000000000000',
    platform_fee: '1200000000000000', employer_charge: '6600000000000000',
    provider_payout: '5400000000000000', fee_policy_version: '2026-08-v1',
    created_at: '2026-01-01T00:00:00.000Z', updated_at: '2026-01-01T00:00:00.000Z',
    debit: '0', credit: '0'
  };
  const mapped = paymentFromRow(row);
  assert.equal(mapped.amount, row.amount);
  assert.equal(mapped.baseAmount, row.base_amount);
  assert.equal(mapped.employerFee, row.employer_fee);
  assert.equal(mapped.workerFee, row.worker_fee);
  assert.equal(mapped.platformFee, row.platform_fee);
  assert.equal(mapped.employerCharge, row.employer_charge);
  assert.equal(mapped.providerPayout, row.provider_payout);
  assert.equal(mapped.feePolicyVersion, row.fee_policy_version);
  assert.equal(mapped.currency, row.currency);
  const serialized = fromDbRow('payments', row);
  assert.equal(serialized.amount, row.amount);
  assert.equal(serialized.providerPayout, row.provider_payout);
  assert.equal(serialized.employerCharge, row.employer_charge);
});

test('wallet and payout TOMAN projections stay string-backed at the API boundary', () => {
  const walletRepo = fs.readFileSync(new URL('../src/repository/wallet.js', import.meta.url), 'utf8');
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  assert.match(walletRepo, /availableBalance: String\(r\.currency \|\| INTERNAL_CURRENCY\).*TOMAN/);
  assert.match(walletRepo, /lockedBalance: String\(r\.currency \|\| INTERNAL_CURRENCY\).*TOMAN/);
  assert.match(payoutRepo, /BigInt\(String\(wallet\.locked_balance\)\)/);
});

test('refund persistence contract includes explicit currency and wallet empty-state uses TOMAN strings', () => {
  const serialization = fs.readFileSync(new URL('../src/db/serialization.js', import.meta.url), 'utf8');
  const walletRoute = fs.readFileSync(new URL('../src/application/wallet_routes.js', import.meta.url), 'utf8');
  assert.match(serialization, /refunds: \['payment_id','amount','currency','status','provider_ref','idempotency_key','created_at','updated_at'\]/);
  assert.match(serialization, /case 'refunds': return \[row\.id,row\.paymentId,row\.amount,row\.currency \|\| config\.paymentCurrency/);
  assert.match(walletRoute, /availableBalance: '0', lockedBalance: '0'/);
});

test('TOMAN rejects fractional/scientific/negative/zero values', () => {
  for (const value of ['0', '-1', '1.5', '1e3', '9007199254740991.1']) {
    assert.throws(() => calculatePaymentBreakdown('JOB', value, 'TOMAN'), /INVALID_AMOUNT/);
  }
});


test('job PostgreSQL NUMERIC TOMAN amounts remain exact strings into payment selection', () => {
  const job = jobFromRow({
    id: 'j1', owner_id: 'u1', provider_id: 'u2', title: 'Exact', description: 'Exact amount',
    category_id: 'c1', job_type: 'FIXED', budget_type: 'FIXED',
    budget_min: '6000000000000000', budget_max: '6000000000000000', duration: 1,
    acceptance_criteria: 'done', status: 'PUBLISHED', city: null, kind: 'MISSION',
    visibility: 'PUBLIC', schedule: null, monthly_salary: null,
    application_deadline: null, created_at: null, updated_at: null, published_at: null,
  });
  assert.equal(job.budgetMax, '6000000000000000');
  assert.equal(typeof job.budgetMax, 'string');
});
