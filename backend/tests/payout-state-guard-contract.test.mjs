import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration = fs.readFileSync(new URL('../src/db/migrations/012_payout_state_guards.js', import.meta.url), 'utf8');
const payouts = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
const pkg = JSON.parse(fs.readFileSync(new URL('../package.json', import.meta.url), 'utf8'));

test('payout database guard covers every lifecycle transition used by the repository', () => {
  for (const status of ['REQUESTED', 'RESERVED', 'PROCESSING', 'UNKNOWN', 'SUCCEEDED', 'FAILED']) {
    assert.match(migration, new RegExp(`WHEN '${status}'`));
  }
  assert.match(migration, /RESERVED.*PROCESSING.*SUCCEEDED.*FAILED.*UNKNOWN/s);
  assert.match(migration, /PROCESSING.*SUCCEEDED.*FAILED.*UNKNOWN/s);
  assert.match(migration, /UNKNOWN.*SUCCEEDED.*FAILED/s);
});

test('payout identity and terminal timestamp invariants are database-enforced', () => {
  assert.match(migration, /payout_identity_immutable_trigger/);
  assert.match(migration, /payouts_terminal_timestamp_chk/);
  assert.match(migration, /SUCCEEDED.*FAILED.*completed_at/s);
});

test('migration checker includes payout state guard migration', () => {
  assert.match(pkg.scripts['check:migrations'], /012_payout_state_guards\.js/);
});


test('unknown payout marks the financial operation referenced by the payout hold', () => {
  assert.match(
    payouts,
    /UPDATE financial_operations SET status='UNKNOWN',completed_at=NULL WHERE id=\$1\`, \[payout\.financial_operation_id\]\);/,
  );
  assert.equal(
    payouts.includes(
      "WHERE id=(SELECT id FROM wallet_holds WHERE reference_id=$1 AND hold_type='PAYOUT_RESERVATION' LIMIT 1)",
    ),
    false,
  )
});
