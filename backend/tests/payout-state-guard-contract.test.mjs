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


test('unknown payout resolves its financial operation through the active reservation hold', () => {
  const markUnknown = payouts
    .split('export async function markPayoutUnknown')[1]
    ?.split('export async function resolvePayoutUnknown')[0] || '';

  assert.match(
    markUnknown,
    /SELECT \* FROM wallet_holds[\s\S]*?reference_id=\$1[\s\S]*?hold_type='PAYOUT_RESERVATION'[\s\S]*?status='ACTIVE'[\s\S]*?FOR UPDATE/,
  );
  assert.match(markUnknown, /PAYOUT_RESERVATION_NOT_FOUND/);
  assert.match(markUnknown, /event\.payload\?\.operationId/);
  assert.match(markUnknown, /PAYOUT_OPERATION_MISMATCH/);
  const operationUpdate = markUnknown.slice(markUnknown.indexOf('UPDATE financial_operations'));
  assert.ok(operationUpdate.includes("status='UNKNOWN'"));
  assert.ok(operationUpdate.includes('completed_at=NULL'));
  assert.ok(operationUpdate.includes("WHERE id=$1 AND status IN ('PROCESSING','UNKNOWN')"));
  assert.ok(operationUpdate.includes('RETURNING id'));
  assert.match(markUnknown, /\[hold\.financial_operation_id\]/);
  assert.doesNotMatch(markUnknown, /payout\.financial_operation_id/);
});
