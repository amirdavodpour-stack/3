import test from 'node:test';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = '';
process.env.PAYMENT_PROVIDER = 'simulator';

const { getPool } = await import('../src/db.js');
const { creditWallet, transferAvailable, ensureWalletForUserPublic } = await import('../src/wallet_ledger.js');

test('public SQL wallet mutations fail with an explicit PostgreSQL prerequisite in file mode', async () => {
  assert.equal(getPool(), null, 'this contract test must run without a PostgreSQL pool');

  await assert.rejects(
    () => creditWallet({ userId: 'user-a', amount: '100', idempotencyKey: 'runtime-contract-credit' }),
    /SQL repository requires PostgreSQL/,
  );
  await assert.rejects(
    () => transferAvailable({ sourceUserId: 'user-a', destinationUserId: 'user-b', amount: '10', idempotencyKey: 'runtime-contract-transfer' }),
    /SQL repository requires PostgreSQL/,
  );
  await assert.rejects(
    () => ensureWalletForUserPublic('user-a'),
    /SQL repository requires PostgreSQL/,
  );
});
