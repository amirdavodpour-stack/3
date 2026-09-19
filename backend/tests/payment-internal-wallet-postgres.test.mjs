import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import pg from 'pg';

const enabled = Boolean(process.env.DATABASE_URL);
const pool = enabled ? new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 4 }) : null;

const { creditWallet, postInternalPaymentHoldWithClient, postInternalPaymentReleaseWithClient, postInternalPaymentRefundWithClient, getWalletByUserId } =
  await import('../src/wallet_ledger.js');
const { getPool } = await import('../src/db.js');

async function insertUser(prefix) {
  const id = crypto.randomUUID();
  const email = `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}@example.test`;
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES($1,$2,'test','Payment Integration Test','USER','ACTIVE',0,NOW())`,
    [id, email],
  );
  return id;
}

async function tx(fn) {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

test('internal payment hold and release update wallet and double-entry ledger atomically', { skip: !enabled }, async () => {
  const payerId = await insertUser('payment-payer');
  const workerId = await insertUser('payment-worker');

  await creditWallet({
    userId: payerId,
    amount: '1000000',
    idempotencyKey: `seed-${payerId}`,
    referenceType: 'TEST_SEED',
    referenceId: crypto.randomUUID(),
  });

  const paymentId = crypto.randomUUID();
  await tx((client) => postInternalPaymentHoldWithClient(client, {
    paymentId,
    payerId,
    employerCharge: '110000',
    providerPayout: '100000',
    platformFee: '10000',
    idempotencyKey: `hold-${paymentId}`,
  }));

  const afterHold = await getWalletByUserId(payerId);
  assert.equal(String(afterHold.available_balance), '890000');
  assert.equal(String(afterHold.locked_balance), '100000');

  await tx((client) => postInternalPaymentReleaseWithClient(client, {
    paymentId,
    payerId,
    workerId,
    providerPayout: '100000',
    idempotencyKey: `release-${paymentId}`,
  }));

  const payerAfterRelease = await getWalletByUserId(payerId);
  const workerAfterRelease = await getWalletByUserId(workerId);
  assert.equal(String(payerAfterRelease.available_balance), '890000');
  assert.equal(String(payerAfterRelease.locked_balance), '0');
  assert.equal(String(workerAfterRelease.available_balance), '100000');

  const journalRows = await pool.query(
    `SELECT j.id, COALESCE(SUM(e.debit),0)::numeric AS debit, COALESCE(SUM(e.credit),0)::numeric AS credit
       FROM journals j
       JOIN ledger_entries e ON e.journal_id=j.id
      WHERE j.operation_id IN (
        SELECT id FROM financial_operations WHERE idempotency_key IN ($1,$2)
      )
      GROUP BY j.id`,
    [`hold-${paymentId}`, `release-${paymentId}`],
  );
  assert.equal(journalRows.rows.length, 2);
  for (const row of journalRows.rows) assert.equal(String(row.debit), String(row.credit));
});

test('internal payment refund restores the employer charge exactly once', { skip: !enabled }, async () => {
  const payerId = await insertUser('refund-payer');
  await creditWallet({
    userId: payerId,
    amount: '500000',
    idempotencyKey: `seed-refund-${payerId}`,
    referenceType: 'TEST_SEED',
    referenceId: crypto.randomUUID(),
  });

  const paymentId = crypto.randomUUID();
  await tx((client) => postInternalPaymentHoldWithClient(client, {
    paymentId,
    payerId,
    employerCharge: '110000',
    providerPayout: '100000',
    platformFee: '10000',
    idempotencyKey: `hold-refund-${paymentId}`,
  }));

  await tx((client) => postInternalPaymentRefundWithClient(client, {
    paymentId,
    payerId,
    providerPayout: '100000',
    platformFee: '10000',
    employerCharge: '110000',
    idempotencyKey: `refund-${paymentId}`,
  }));

  const wallet = await getWalletByUserId(payerId);
  assert.equal(String(wallet.available_balance), '500000');
  assert.equal(String(wallet.locked_balance), '0');

  await tx((client) => postInternalPaymentRefundWithClient(client, {
    paymentId,
    payerId,
    providerPayout: '100000',
    platformFee: '10000',
    employerCharge: '110000',
    idempotencyKey: `refund-replay-${paymentId}`,
  })).catch((error) => {
    assert.equal(error.code, 'ACTIVE_HOLD_NOT_FOUND');
  });
});

after(async () => {
  if (pool) await pool.end();
});
