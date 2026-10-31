import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateIdempotencyPair, paymentAmountForJob, assertFundingReplayMatches, mapPaymentMutationError } from '../src/application/payment_policy.js';

test('payment policy accepts matching and normalizes header/body idempotency keys consistently', () => {
  assert.equal(validateIdempotencyPair({ headerKey: ' abc-123 ', bodyKey: 'abc-123', maxLength: 64 }), 'abc-123');
  assert.throws(() => validateIdempotencyPair({ headerKey: 'x'.repeat(65), maxLength: 64 }), /too long/i);
});

test('payment policy rejects unsafe and oversized idempotency keys', () => {
  assert.throws(() => validateIdempotencyPair({ bodyKey: 'bad key', maxLength: 64 }), /unsupported characters/i);
  assert.throws(() => validateIdempotencyPair({ bodyKey: 'x'.repeat(65), maxLength: 64 }), /too long/i);
});

test('payment policy rejects header/body mismatch', () => {
  assert.throws(() => validateIdempotencyPair({ headerKey: 'a', bodyKey: 'b', maxLength: 64 }), /must match/i);
});

test('payment amount selection is deterministic by job kind', () => {
  assert.equal(paymentAmountForJob({ kind: 'JOB', monthlySalary: 1200, budgetMax: 900 }), '1200');
  assert.equal(paymentAmountForJob({ kind: 'MISSION', budgetMax: 800, budgetMin: 500 }), '800');
  assert.equal(paymentAmountForJob({ kind: 'MISSION', budgetMax: '8999999999999999', budgetMin: '1' }), '8999999999999999');
  assert.throws(() => paymentAmountForJob({ kind: 'JOB', monthlySalary: 0, budgetMax: 0, budgetMin: 0 }), /budget is invalid/i);
});

test('payment mutation errors map to stable HTTP contracts', () => {
  const mapped = mapPaymentMutationError(Object.assign(new Error('x'), { code: 'INVALID_OFFER_STATE' }));
  assert.equal(mapped.status, 409);
  assert.equal(mapped.code, 'INVALID_OFFER_STATE');
  const unknown = Object.assign(new Error('unexpected'), { code: 'UNKNOWN' });
  assert.equal(mapPaymentMutationError(unknown), unknown);
});


test('funding replay accepts only the same payer, payee, currency and exact amount', () => {
  const existing = {
    id:'payment-1', idempotencyKey:'same-key', payerId:'payer-1', payeeId:'payee-1',
    amount:'100.00', currency:'TOMAN',
  };
  const valid = {
    existing, idempotencyKey:'same-key', payerId:'payer-1', payeeId:'payee-1',
    requestedAmount:'100', requestedCurrency:'TOMAN',
  };
  assert.doesNotThrow(() => assertFundingReplayMatches(valid));

  for (const change of [
    { requestedAmount:'101' },
    { payerId:'payer-2' },
    { payeeId:'payee-2' },
    { requestedCurrency:'USD' },
  ]) {
    assert.throws(
      () => assertFundingReplayMatches({ ...valid, ...change }),
      (error) => error?.code === 'IDEMPOTENCY_CONFLICT' && error?.status === 409,
    );
  }
});

test('funding replay validation is wired before early responses in PostgreSQL and legacy route branches', () => {
  const routes = readFileSync(new URL('../src/routes/payment_routes.js', import.meta.url), 'utf8');
  const start = routes.indexOf("if (req.method === 'POST' && parts[1] === 'fund'");
  const end = routes.indexOf("if (req.method === 'POST' && parts[1] === 'refund'", start);
  const fundRoute = routes.slice(start, end);
  const dbBranch = fundRoute.slice(fundRoute.indexOf("if (process.env.DATABASE_URL)"), fundRoute.indexOf("} else {"));
  const legacyBranch = fundRoute.slice(fundRoute.indexOf("} else {"), fundRoute.indexOf("enforceJobState"));
  assert.ok(dbBranch.includes('assertExistingFundingReplay('));
  assert.ok(legacyBranch.includes('assertExistingFundingReplay('));
});
