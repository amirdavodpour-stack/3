import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('..', import.meta.url);
const read = (file) => fs.readFileSync(new URL(file, root), 'utf8');
const ledger = read('src/wallet_ledger.js');
const payout = read('src/repository/payouts.js');
const payments = read('src/repository/payment_lifecycle.js');
const refunds = read('src/repository/payment_refunds.js');
const outbox = read('src/repository/outbox.js');
const app = read('src/app.js');

const matrix = {
  TOP_UP: {
    sources: [ledger],
    required: ['entry_type', 'TOP_UP', 'financial_operation', 'idempotency'],
  },
  TRANSFER: {
    sources: [ledger],
    required: ['TRANSFER', 'lockWallets', 'financial_operation', 'completeIdempotency'],
  },
  HOLD: {
    sources: [ledger, payments],
    required: ['HOLD', 'wallet_holds', 'journals', 'financial_operations'],
  },
  RELEASE: {
    sources: [ledger, outbox],
    required: ['RELEASE', 'wallet_holds', 'journal', 'outbox'],
  },
  REFUND: {
    sources: [ledger, refunds, outbox],
    required: ['REFUND', 'wallet_holds', 'journals', 'outbox'],
  },
  PAYOUT: {
    sources: [payout, outbox],
    required: ['PAYOUT', 'wallet_holds', 'WORKER_PAYABLE', 'PAYOUT_EXECUTE', 'outbox'],
  },
};

test('financial invariant matrix is closed over the six required operations', () => {
  assert.deepEqual(Object.keys(matrix).sort(), ['HOLD', 'PAYOUT', 'REFUND', 'RELEASE', 'TOP_UP', 'TRANSFER']);
  for (const [operation, spec] of Object.entries(matrix)) {
    const corpus = spec.sources.join('\n');
    for (const token of spec.required) assert.ok(corpus.includes(token), `${operation} missing ${token}`);
  }
});

test('all financial operations use TOMAN/immutable wallet-entry primitives and idempotency infrastructure', () => {
  assert.match(ledger, /INTERNAL_CURRENCY = 'TOMAN'/);
  assert.match(ledger, /INSERT INTO wallet_entries/);
  assert.match(ledger, /beginIdempotency/);
  assert.match(ledger, /completeIdempotency/);
  assert.match(payout, /currency='TOMAN'/);
  assert.match(payout, /idempotency_key/);
});

test('release/refund/payout paths retain durable outbox/audit correlation roots', () => {
  assert.match(outbox, /outbox_events/);
  assert.match(outbox, /audit_logs/);
  assert.match(ledger, /financial_operation_id/);
  assert.match(outbox, /aggregate_id|payload/);
  assert.match(refunds, /postInternalPaymentRefundWithClient/);
  assert.match(payout, /financial_operations/);
  assert.match(app, /repo\.resolvePayoutUnknown/);
});


test('multi-wallet financial mutations use deterministic lock ordering to prevent lock-order deadlocks', () => {
  assert.match(ledger, /function lockWallets\(client, ids\)[\s\S]*?\[\.\.\.new Set\(ids\)\]\.sort\(\)/);
  assert.match(ledger, /lockWallets\(client, \[source\.id, destination\.id\]\)/);
  assert.match(ledger, /lockWallets\(client, \[payer\.id, worker\.id\]\)/);
  const directWalletLocks = ledger.match(/SELECT \* FROM wallet_accounts[\s\S]*?ORDER BY id FOR UPDATE/g) || [];
  assert.equal(directWalletLocks.length, 1, 'wallet row locking must remain centralized in lockWallets');
});

test('idempotency reservation is part of the same transaction boundary as financial mutation', () => {
  for (const fn of ['creditWallet', 'transferAvailable']) {
    const start = ledger.indexOf(`export async function ${fn}`);
    assert.ok(start >= 0, `${fn} must exist`);
    const end = ledger.indexOf('\nexport async function ', start + 1);
    const body = ledger.slice(start, end === -1 ? ledger.length : end);
    assert.match(body, /withSqlTransaction\(/, `${fn} must use a SQL transaction`);
    assert.match(body, /beginIdempotency\(/, `${fn} must reserve idempotency inside the transaction`);
    assert.match(body, /completeIdempotency\(/, `${fn} must complete idempotency inside the transaction`);
  }
});
