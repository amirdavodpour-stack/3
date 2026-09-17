import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const migrationPath = path.resolve(process.cwd(), 'src/db/migrations/023_legacy_wallet_transaction_canonical_backfill.js');
const migrationSource = fs.readFileSync(migrationPath, 'utf8');

test('legacy wallet backfill exists as a forward-only migration', () => {
  assert.match(migrationSource, /version:\s*23/);
  assert.match(migrationSource, /FROM wallet_transactions/);
  assert.match(migrationSource, /WHERE currency='HOPE'/);
  assert.match(migrationSource, /legacy-wallet:/);
  assert.match(migrationSource, /wallet_entries/);
  assert.match(migrationSource, /ledger_entries/);
  assert.match(migrationSource, /LEGACY_BACKFILL/);
  assert.match(migrationSource, /forward-only financial data repair/);
});

test('migration runner enforces contiguous migration versions through 23', () => {
  const runner = fs.readFileSync(path.resolve(process.cwd(), 'src/db/migrations.js'), 'utf8');
  const migrationFiles = fs.readdirSync(path.resolve(process.cwd(), 'src/db/migrations'))
    .filter((name) => /^\d+_[a-z0-9_]+\.js$/i.test(name))
    .sort();
  const versions = migrationFiles.map((name) => Number(name.split('_', 1)[0]));
  assert.equal(versions.at(-1), 23);
  assert.equal(new Set(versions).size, versions.length);
  assert.match(runner, /migrations\[i\]\.version !== migrations\[i - 1\]\.version \+ 1/);
});
