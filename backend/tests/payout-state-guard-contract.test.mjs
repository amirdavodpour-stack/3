import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migration = fs.readFileSync(new URL('../src/db/migrations/012_payout_state_guards.js', import.meta.url), 'utf8');
const payouts = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
const outboxHandlers = fs.readFileSync(new URL('../src/outbox_handlers.js', import.meta.url), 'utf8');
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


test('unknown payout resolves its financial operation through the canonical active reservation hold', () => {
  const settlementLinkage = payouts
    .split('async function validatePayoutSettlementLinkage')[1]
    ?.split('async function validatePayoutUnknownResolutionLinkage')[0] || '';
  const unknownResolutionLinkage = payouts
    .split('async function validatePayoutUnknownResolutionLinkage')[1]
    ?.split('export async function validatePayoutOutboxEvent')[0] || '';
  const markUnknown = payouts
    .split('export async function markPayoutUnknown')[1]
    ?.split('export async function resolvePayoutUnknown')[0] || '';
  const identityValidation = payouts
    .split('function validatePayoutEventIdentity')[1]
    ?.split('async function validatePayoutSettlementLinkage')[0] || '';

  for (const source of [settlementLinkage, unknownResolutionLinkage]) {
    assert.match(
      source,
      /SELECT \* FROM wallet_holds[\s\S]*?reference_id=\$1[\s\S]*?hold_type='PAYOUT_RESERVATION'[\s\S]*?status='ACTIVE'[\s\S]*?FOR UPDATE/,
    );
    assert.match(source, /PAYOUT_RESERVATION_NOT_FOUND/);
    assert.match(source, /PAYOUT_HOLD_AMBIGUOUS/);
    assert.match(source, /PAYOUT_HOLD_LINKAGE_MISMATCH/);
  }

  assert.match(markUnknown, /validatePayoutEventIdentity\(event, payout\)/);
  assert.match(markUnknown, /await validatePayoutSettlementLinkage\(client, event, payout\)/);
  assert.match(markUnknown, /await validatePayoutUnknownResolutionLinkage\(client, payout\)/);
  assert.match(identityValidation, /PAYOUT_OUTBOX_IDENTITY_MISMATCH/);
  assert.match(markUnknown, /if \(!identity\.valid\)/);
  assert.match(markUnknown, /reconciliationResourceType = 'outbox_event'/);
  assert.match(markUnknown, /payoutEventPayload\(event\)\?\.operationId/);
  const operationUpdate = markUnknown.slice(markUnknown.indexOf('UPDATE financial_operations'));
  assert.ok(operationUpdate.includes("status='UNKNOWN'"));
  assert.ok(operationUpdate.includes('completed_at=NULL'));
  assert.ok(operationUpdate.includes("status='PROCESSING'"));
  assert.ok(operationUpdate.includes('RETURNING id'));
  assert.ok(operationUpdate.includes('[operationId, payout.user_id, payout.idempotency_key]'));
  assert.ok(markUnknown.includes('PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY'));
  assert.ok(markUnknown.includes('requiresReconciliation: Boolean(reconciliationReason)'));
  assert.doesNotMatch(markUnknown, /payout\.financial_operation_id/);
});

test('ambiguous payout provider outcomes never enter generic terminal failure handling', () => {
  const payoutUnknownBranch = outboxHandlers
    .split("if (result.status === 'UNKNOWN')")[1]
    ?.split("if (result.status !== 'SUCCEEDED'")[0] || '';

  assert.ok(payoutUnknownBranch.includes('OUTBOX_PAYOUT_UNKNOWN_PERSISTENCE_FAILED'));
  assert.ok(payoutUnknownBranch.includes('OUTBOX_PAYOUT_UNKNOWN_REQUIRES_RECONCILIATION'));
  assert.ok(payoutUnknownBranch.includes('return { processed:false, unknown:true, persistencePending:true }'));
  assert.ok(!payoutUnknownBranch.includes('return failOutboxEvent('));
});

