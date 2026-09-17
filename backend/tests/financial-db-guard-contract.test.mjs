import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration = fs.readFileSync(new URL('../src/db/migrations/013_financial_amount_and_journal_guards.js', import.meta.url), 'utf8');
const pkg = JSON.parse(fs.readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

test('database caps TOMAN financial amounts to the application safety ceiling', () => {
  assert.match(migration, /9000000000000000/g);
  assert.match(migration, /wallet_accounts_available_max_chk/);
  assert.match(migration, /wallet_accounts_locked_max_chk/);
  assert.match(migration, /wallet_holds_amount_max_chk/);
  assert.match(migration, /wallet_entries_amount_max_chk/);
  assert.match(migration, /payouts_amount_max_chk/);
  assert.match(migration, /ledger_entries_amount_max_chk/);
});

test('posted journals are database-validated as non-empty and balanced', () => {
  assert.match(migration, /hope_validate_posted_journal_balance/);
  assert.match(migration, /debit_total <> credit_total/);
  assert.match(migration, /entry_count = 0/);
  assert.match(migration, /journals_posted_balance_trigger/);
  assert.match(migration, /DEFERRABLE INITIALLY DEFERRED/);
});

test('migration checker includes financial amount and journal guards', () => {
  assert.match(pkg.scripts['check:migrations'], /013_financial_amount_and_journal_guards\.js/);
});
