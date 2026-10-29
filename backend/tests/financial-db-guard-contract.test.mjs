import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration = fs.readFileSync(new URL('../src/db/migrations/013_financial_amount_and_journal_guards.js', import.meta.url), 'utf8');
const pkg = JSON.parse(fs.readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
const externalLedgerMigration = fs.readFileSync(new URL('../src/db/migrations/035_external_ledger_journals_and_currency_precision.js', import.meta.url), 'utf8');

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

test('external ledger preserves exact currency precision and canonical journal linkage', () => {
  assert.ok(externalLedgerMigration.includes('NUMERIC(18,2)'));
  assert.ok(externalLedgerMigration.includes('ledger_entries_toman_integer_chk'));
  assert.ok(externalLedgerMigration.includes('journals_currency_supported_chk'));
  assert.ok(externalLedgerMigration.includes('financial_operations_provider_idempotency_uq'));
  assert.ok(externalLedgerMigration.includes('ledger_entries_journal_id_fk'));
  assert.ok(externalLedgerMigration.includes('hope_validate_ledger_entry_currency'));
  assert.ok(externalLedgerMigration.includes('ledger_entries_currency_matches_journal_trigger'));
  assert.ok(externalLedgerMigration.includes('hope_reject_journal_currency_mismatch'));
  assert.ok(externalLedgerMigration.includes('Cannot enforce ledger currency matching'));
  assert.ok(externalLedgerMigration.includes('DROP TRIGGER IF EXISTS ledger_journal_balance_deferred'));
  assert.ok(externalLedgerMigration.includes('CREATE CONSTRAINT TRIGGER ledger_journal_balance_deferred'));
  assert.ok(externalLedgerMigration.includes('Cannot canonicalize invalid legacy ledger groups'));
});

test('migration checker includes financial amount and journal guards', () => {
  assert.match(pkg.scripts['check:migrations'], /013_financial_amount_and_journal_guards\.js/);
  assert.ok(pkg.scripts['check:migrations'].includes('035_external_ledger_journals_and_currency_precision.js'));
});
