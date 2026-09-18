import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';

const enabled = Boolean(process.env.DATABASE_URL);
const pool = enabled ? new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 3 }) : null;

async function query(sql) {
  return (await pool.query(sql)).rows;
}

test('financial schema invariants hold in PostgreSQL', { skip: !enabled }, async () => {
  const required = ['payments', 'provider_events', 'wallet_accounts', 'wallet_entries', 'financial_operations', 'journals', 'ledger_entries', 'payouts', 'refunds'];
  const rows = await query(`SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name = ANY($1::text[])`, [required]);
  assert.deepEqual(new Set(rows.map((r) => r.table_name)), new Set(required));

  const unbalanced = await query(`
    SELECT j.id
    FROM journals j
    LEFT JOIN ledger_entries e ON e.journal_id=j.id
    WHERE j.status='POSTED'
    GROUP BY j.id
    HAVING COUNT(e.id)=0 OR COALESCE(SUM(e.debit),0) <> COALESCE(SUM(e.credit),0)
  `);
  assert.equal(unbalanced.length, 0);

  const negativeWallets = await query(`
    SELECT id FROM wallet_accounts
    WHERE available_balance < 0 OR locked_balance < 0
  `);
  assert.equal(negativeWallets.length, 0);

  const orphanWalletEntries = await query(`
    SELECT e.id
    FROM wallet_entries e
    LEFT JOIN financial_operations o ON o.id=e.financial_operation_id
    WHERE o.id IS NULL
  `);
  assert.equal(orphanWalletEntries.length, 0);

  const invalidTerminalOperations = await query(`
    SELECT id FROM financial_operations
    WHERE status IN ('SUCCEEDED','FAILED','CANCELLED') AND completed_at IS NULL
  `);
  assert.equal(invalidTerminalOperations.length, 0);

  const badPaymentIdempotency = await query(`
    SELECT payer_id,idempotency_key,COUNT(*)::int AS count
    FROM payments
    WHERE idempotency_key IS NOT NULL AND idempotency_key <> ''
    GROUP BY payer_id,idempotency_key
    HAVING COUNT(*) > 1
  `);
  assert.equal(badPaymentIdempotency.length, 0);

  const duplicateProviderEvents = await query(`
    SELECT provider,provider_event_id,COUNT(*)::int AS count
    FROM provider_events
    GROUP BY provider,provider_event_id
    HAVING COUNT(*) > 1
  `);
  assert.equal(duplicateProviderEvents.length, 0);

  const badPaymentRefs = await query(`
    SELECT id
    FROM payments
    WHERE provider_ref IS NULL OR provider_ref=''
  `);
  assert.equal(badPaymentRefs.length, 0);
});

after(async () => {
  if (pool) await pool.end();
});
