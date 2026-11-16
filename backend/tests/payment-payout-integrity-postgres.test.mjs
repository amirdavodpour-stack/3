import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import pg from 'pg';

// These tests exercise only the synthetic internal payout adapter in a disposable CI database.
process.env.NODE_ENV = 'test';
process.env.PAYMENT_PROVIDER = 'internal';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}
const pool = enabled ? new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 8 }) : null;

const [{ getPool }, { creditWallet }, payouts] = await Promise.all([
  import('../src/db.js'),
  import('../src/wallet_ledger.js'),
  import('../src/repository/payouts.js'),
]);
const {
  requestPayoutAtomic,
  completePayoutOutbox,
  failPayoutOutbox,
  markPayoutUnknown,
  resolvePayoutUnknown,
} = payouts;
const { processOutboxEvent } = await import('../src/outbox_handlers.js');
const reconciliation = await import('../src/repository/reconciliation.js');
const { migration: reconciliationCaseEventsMigration } = await import('../src/db/migrations/059_reconciliation_case_events.js');
const { migration: reconciliationEventAttestationMigration } = await import('../src/db/migrations/060_reconciliation_event_attestation_and_disposition.js');
const { failOutboxEvent } = await import('../src/repository/outbox.js');
const { paymentProvider } = await import('../src/payment_provider.js');

async function insertFundedUser(prefix) {
  const userId = crypto.randomUUID();
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES($1,$2,'test','Payout integrity test','USER','ACTIVE',0,NOW())`,
    [userId, `${prefix}-${userId}@example.test`],
  );
  await creditWallet({
    userId,
    amount: '1000000',
    idempotencyKey: `payout-integrity-seed:${userId}`,
    referenceType: 'TEST_SEED',
    referenceId: crypto.randomUUID(),
  });
  const { rows } = await pool.query(
    `SELECT id FROM wallet_accounts WHERE user_id=$1 AND currency='TOMAN'`,
    [userId],
  );
  assert.equal(rows.length, 1);
  return { userId, walletId: rows[0].id };
}

async function reservePayout(userId, key, amount = '100000') {
  const payout = await requestPayoutAtomic({ userId, amount, idempotencyKey: key });
  const { rows } = await pool.query(
    `SELECT * FROM outbox_events
      WHERE event_type='PAYOUT_EXECUTE' AND aggregate_id=$1
      ORDER BY created_at DESC,id DESC LIMIT 1`,
    [payout.id],
  );
  assert.equal(rows.length, 1);
  return { payout, event: rows[0] };
}

async function snapshot({ userIds, payouts: payoutRows, events }) {
  const payoutIds = payoutRows.map((item) => item.payout.id);
  const eventIds = events.map((item) => item.id);
  const operationIds = payoutIds.length
    ? (await pool.query(
      `SELECT DISTINCT financial_operation_id AS id
         FROM wallet_holds WHERE reference_id=ANY($1::uuid[]) AND financial_operation_id IS NOT NULL`,
      [payoutIds],
    )).rows.map((row) => row.id)
    : [];
  const walletRows = await pool.query(
    `SELECT id,user_id,currency,status,available_balance,locked_balance
       FROM wallet_accounts WHERE user_id=ANY($1::uuid[]) ORDER BY id`,
    [userIds],
  );
  const payoutState = await pool.query(
    `SELECT id,wallet_id,user_id,amount,currency,status,provider_ref,failure_code,completed_at
       FROM payouts WHERE id=ANY($1::uuid[]) ORDER BY id`,
    [payoutIds],
  );
  const holds = await pool.query(
    `SELECT id,wallet_id,hold_type,reference_type,reference_id,financial_operation_id,amount,status,released_at
       FROM wallet_holds WHERE reference_id=ANY($1::uuid[]) ORDER BY id`,
    [payoutIds],
  );
  const operations = await pool.query(
    `SELECT id,operation_type,actor_type,actor_id,status,idempotency_key,completed_at
       FROM financial_operations
      WHERE id=ANY($1::uuid[]) OR (actor_id=ANY($2::uuid[]) AND operation_type='PAYOUT')
      ORDER BY id`,
    [operationIds, userIds],
  );
  const journals = await pool.query(
    `SELECT id,operation_id,journal_type,currency,status,posted_at
       FROM journals WHERE operation_id=ANY($1::uuid[]) ORDER BY id`,
    [operations.rows.map((row) => row.id)],
  );
  const walletEntries = await pool.query(
    `SELECT id,wallet_id,entry_type,direction,amount,currency,reference_type,reference_id,financial_operation_id,balance_after
       FROM wallet_entries
      WHERE reference_id=ANY($1::uuid[]) OR financial_operation_id=ANY($2::uuid[])
      ORDER BY id`,
    [payoutIds, operations.rows.map((row) => row.id)],
  );
  const ledgerEntries = await pool.query(
    `SELECT id,journal_id,reference_type,reference_id,account,debit,credit,currency
       FROM ledger_entries WHERE journal_id=ANY($1::uuid[]) ORDER BY id`,
    [journals.rows.map((row) => row.id)],
  );
  const outbox = await pool.query(
    `SELECT id,event_type,aggregate_type,aggregate_id,payload,status,processed_at,last_error
       FROM outbox_events WHERE id=ANY($1::uuid[]) ORDER BY id`,
    [eventIds],
  );
  const reconciliationCases = await pool.query(
    `SELECT id,case_type,resource_type,resource_id,severity,expected,observed,status
       FROM reconciliation_cases
      WHERE resource_id=ANY($1::uuid[]) OR resource_id=ANY($2::uuid[])
      ORDER BY id`,
    [payoutIds, eventIds],
  );
  return JSON.parse(JSON.stringify({
    wallets: walletRows.rows,
    payouts: payoutState.rows,
    holds: holds.rows,
    operations: operations.rows,
    journals: journals.rows,
    walletEntries: walletEntries.rows,
    ledgerEntries: ledgerEntries.rows,
    outbox: outbox.rows,
    reconciliationCases: reconciliationCases.rows,
  }));
}

async function expectUnchanged(before, args) {
  const afterState = await snapshot(args);
  assert.deepEqual(afterState, before, 'rejected payout transition must preserve all financial and Outbox state');
}

async function expectIntegrityQuarantine(before, args, { reason, resourceType = 'payout', payoutStatus = 'UNKNOWN', payoutId = null, eventId = null }) {
  const afterState = await snapshot(args);
  for (const field of ['wallets', 'holds', 'operations', 'journals', 'walletEntries', 'ledgerEntries']) {
    assert.deepEqual(afterState[field], before[field], 'integrity quarantine must preserve ' + field);
  }
  if (payoutStatus === 'UNCHANGED') {
    assert.deepEqual(afterState.payouts, before.payouts);
  } else {
    const targetPayout = afterState.payouts.find((row) => row.id === payoutId) || afterState.payouts[0];
    assert.equal(targetPayout.status, 'UNKNOWN');
  }
  const targetEvent = afterState.outbox.find((row) => row.id === eventId) || afterState.outbox[0];
  assert.equal(targetEvent.status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].resource_type, resourceType);
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
  assert.equal(afterState.reconciliationCases[0].observed.reason, reason);
}

test('Payout completion rejects an Outbox event belonging to a different payout without mutation', { skip: !enabled }, async () => {
  const { userId } = await insertFundedUser('payout-event-mismatch');
  const first = await reservePayout(userId, `event-a:${crypto.randomUUID()}`);
  const second = await reservePayout(userId, `event-b:${crypto.randomUUID()}`);
  const args = { userIds: [userId], payouts: [first, second], events: [first.event, second.event] };
  const before = await snapshot(args);

  const result = await completePayoutOutbox({
    eventId: second.event.id,
    payoutId: first.payout.id,
    providerRef: `must-not-be-used:${crypto.randomUUID()}`,
    leaseToken: second.event.lease_token,
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_OUTBOX_IDENTITY_MISMATCH');
  await expectIntegrityQuarantine(before, args, { reason: result.reason, resourceType: 'outbox_event', payoutStatus: 'UNCHANGED', eventId: second.event.id });
});

test('Payout completion rejects a reservation hold linked to another wallet without mutation', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-hold-owner');
  const other = await insertFundedUser('payout-hold-other');
  const reserved = await reservePayout(owner.userId, `wallet-mismatch:${crypto.randomUUID()}`);
  await pool.query(
    `UPDATE wallet_holds SET wallet_id=$2
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [reserved.payout.id, other.walletId],
  );
  const args = { userIds: [owner.userId, other.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  const result = await completePayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    providerRef: `must-not-be-used:${crypto.randomUUID()}`,
    leaseToken: reserved.event.lease_token,
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_HOLD_LINKAGE_MISMATCH');
  await expectIntegrityQuarantine(before, args, { reason: result.reason });
});

test('Payout completion rejects a reservation amount mismatch without mutation', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-amount-owner');
  const reserved = await reservePayout(owner.userId, `amount-mismatch:${crypto.randomUUID()}`);
  await pool.query(
    `UPDATE wallet_holds SET amount=amount-1
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [reserved.payout.id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  const result = await completePayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    providerRef: `must-not-be-used:${crypto.randomUUID()}`,
    leaseToken: reserved.event.lease_token,
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_HOLD_LINKAGE_MISMATCH');
  await expectIntegrityQuarantine(before, args, { reason: result.reason });
});

test('Payout completion rejects a reservation linked to a different financial operation without mutation', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-operation-owner');
  const first = await reservePayout(owner.userId, `operation-a:${crypto.randomUUID()}`);
  const second = await reservePayout(owner.userId, `operation-b:${crypto.randomUUID()}`);
  const secondHold = await pool.query(
    `SELECT financial_operation_id FROM wallet_holds
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [second.payout.id],
  );
  assert.equal(secondHold.rows.length, 1);
  await pool.query(
    `UPDATE wallet_holds SET financial_operation_id=$2
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [first.payout.id, secondHold.rows[0].financial_operation_id],
  );
  const args = { userIds: [owner.userId], payouts: [first, second], events: [first.event, second.event] };
  const before = await snapshot(args);

  const result = await completePayoutOutbox({
    eventId: first.event.id,
    payoutId: first.payout.id,
    providerRef: `must-not-be-used:${crypto.randomUUID()}`,
    leaseToken: first.event.lease_token,
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_OPERATION_LINKAGE_MISMATCH');
  await expectIntegrityQuarantine(before, args, { reason: result.reason, payoutId: first.payout.id, eventId: first.event.id });
});

test('Payout completion rejects multiple active reservation holds for the same payout without mutation', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-duplicate-hold');
  const reserved = await reservePayout(owner.userId, `duplicate-hold:${crypto.randomUUID()}`);
  const canonical = await pool.query(
    `SELECT * FROM wallet_holds
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [reserved.payout.id],
  );
  assert.equal(canonical.rows.length, 1);
  await pool.query(
    `INSERT INTO wallet_holds(wallet_id,hold_type,reference_type,reference_id,financial_operation_id,amount,status)
     VALUES($1,'PAYOUT_RESERVATION','PAYOUT_SHADOW',$2,$3,$4,'ACTIVE')`,
    [canonical.rows[0].wallet_id,reserved.payout.id,canonical.rows[0].financial_operation_id,canonical.rows[0].amount],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  const result = await completePayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    providerRef: `must-not-be-used:${crypto.randomUUID()}`,
    leaseToken: reserved.event.lease_token,
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_HOLD_AMBIGUOUS');
  await expectIntegrityQuarantine(before, args, { reason: result.reason });
});

test('Payout failure rejects an Outbox event belonging to a different payout without releasing funds', { skip: !enabled }, async () => {
  const { userId } = await insertFundedUser('payout-fail-event-mismatch');
  const first = await reservePayout(userId, `fail-a:${crypto.randomUUID()}`);
  const second = await reservePayout(userId, `fail-b:${crypto.randomUUID()}`);
  const args = { userIds: [userId], payouts: [first, second], events: [first.event, second.event] };
  const before = await snapshot(args);

  const result = await failPayoutOutbox({
    eventId: second.event.id,
    payoutId: first.payout.id,
    error: 'synthetic failure must not cross payout identity',
    leaseToken: second.event.lease_token,
    failureCode: 'TEST_MISMATCH',
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_OUTBOX_IDENTITY_MISMATCH');
  await expectIntegrityQuarantine(before, args, { reason: result.reason, resourceType: 'outbox_event', payoutStatus: 'UNCHANGED', eventId: second.event.id });
});

test('Payout failure rejects a reservation amount mismatch without releasing funds', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-fail-amount');
  const reserved = await reservePayout(owner.userId, `fail-amount:${crypto.randomUUID()}`);
  await pool.query(
    `UPDATE wallet_holds SET amount=amount-1
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [reserved.payout.id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  const result = await failPayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    error: 'synthetic failure must preserve mismatched reservation',
    leaseToken: reserved.event.lease_token,
    failureCode: 'TEST_MISMATCH',
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_HOLD_LINKAGE_MISMATCH');
  await expectIntegrityQuarantine(before, args, { reason: result.reason });
});

test('PAYOUT_EXECUTE integrity preflight blocks provider dispatch for a cross-payout payload', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-provider-preflight');
  const intended = await reservePayout(owner.userId, `preflight-intended:${crypto.randomUUID()}`);
  const eventSource = await reservePayout(owner.userId, `preflight-source:${crypto.randomUUID()}`);
  const crossLinkedEvent = {
    ...eventSource.event,
    payload: { ...eventSource.event.payload, payoutId: intended.payout.id },
  };
  const args = {
    userIds: [owner.userId],
    payouts: [intended, eventSource],
    events: [intended.event, eventSource.event],
  };
  const before = await snapshot(args);

  let providerCalls = 0;
  const originalCreatePayout = paymentProvider.createPayout;
  paymentProvider.createPayout = async () => {
    providerCalls += 1;
    return { status: 'SUCCEEDED', providerRef: 'must-not-dispatch' };
  };
  let result;
  try {
    result = await processOutboxEvent(crossLinkedEvent);
  } finally {
    paymentProvider.createPayout = originalCreatePayout;
  }

  assert.equal(providerCalls, 0);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_OUTBOX_IDENTITY_MISMATCH');
  const afterState = await snapshot(args);
  assert.deepEqual(afterState.wallets, before.wallets);
  assert.deepEqual(afterState.payouts, before.payouts);
  assert.deepEqual(afterState.holds, before.holds);
  assert.deepEqual(afterState.operations, before.operations);
  assert.deepEqual(afterState.journals, before.journals);
  assert.deepEqual(afterState.walletEntries, before.walletEntries);
  assert.deepEqual(afterState.ledgerEntries, before.ledgerEntries);
  assert.equal(
    afterState.outbox.find((event) => event.id === intended.event.id).status,
    before.outbox.find((event) => event.id === intended.event.id).status,
  );
  assert.equal(afterState.outbox.find((event) => event.id === eventSource.event.id).status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].resource_type, 'outbox_event');
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
});

test('manual UNKNOWN payout resolution rejects a reservation amount mismatch without moving funds', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-unknown-resolution');
  const reserved = await reservePayout(owner.userId, `unknown-resolution:${crypto.randomUUID()}`);
  const marked = await markPayoutUnknown({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    reason: 'test provider outcome unknown',
    leaseToken: reserved.event.lease_token,
  });
  assert.equal(marked.marked, true);

  await pool.query(
    `UPDATE wallet_holds SET amount=amount-1
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [reserved.payout.id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  await assert.rejects(
    () => resolvePayoutUnknown({
      payoutId: reserved.payout.id,
      decision: 'FAILED',
      source: 'PROVIDER_RECONCILIATION',
      reason: 'provider reconciliation confirms no disbursement',
    }),
    (error) => error.code === 'PAYOUT_HOLD_LINKAGE_MISMATCH',
  );
  await expectUnchanged(before, args);
});

test('valid canonical Payout completion releases the reservation and posts a balanced journal', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-valid-complete');
  const reserved = await reservePayout(owner.userId, `valid-complete:${crypto.randomUUID()}`);
  const result = await completePayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    providerRef: `valid-provider-ref:${crypto.randomUUID()}`,
    leaseToken: reserved.event.lease_token,
  });
  assert.equal(result.completed, true);

  const wallet = await pool.query(
    `SELECT available_balance,locked_balance FROM wallet_accounts WHERE id=$1`,
    [reserved.payout.wallet_id],
  );
  assert.equal(String(wallet.rows[0].available_balance), '900000');
  assert.equal(String(wallet.rows[0].locked_balance), '0');
  const payout = await pool.query(`SELECT status FROM payouts WHERE id=$1`, [reserved.payout.id]);
  assert.equal(payout.rows[0].status, 'SUCCEEDED');
  const hold = await pool.query(
    `SELECT status,amount FROM wallet_holds WHERE reference_id=$1 AND reference_type='PAYOUT'`,
    [reserved.payout.id],
  );
  assert.equal(hold.rows.length, 1);
  assert.equal(hold.rows[0].status, 'RELEASED');
  const operation = await pool.query(
    `SELECT status FROM financial_operations WHERE id=$1`,
    [reserved.event.payload.operationId],
  );
  assert.equal(operation.rows[0].status, 'SUCCEEDED');
  const journal = await pool.query(
    `SELECT j.status,COALESCE(SUM(e.debit),0)::numeric AS debit,COALESCE(SUM(e.credit),0)::numeric AS credit
       FROM journals j LEFT JOIN ledger_entries e ON e.journal_id=j.id
      WHERE j.operation_id=$1 AND j.journal_type='PAYOUT'
      GROUP BY j.id`,
    [reserved.event.payload.operationId],
  );
  assert.equal(journal.rows.length, 1);
  assert.equal(journal.rows[0].status, 'POSTED');
  assert.equal(String(journal.rows[0].debit), String(journal.rows[0].credit));
  const event = await pool.query(`SELECT status FROM outbox_events WHERE id=$1`, [reserved.event.id]);
  assert.equal(event.rows[0].status, 'DONE');
});

test('valid canonical Payout failure restores the reservation exactly once', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-valid-fail');
  const reserved = await reservePayout(owner.userId, `valid-fail:${crypto.randomUUID()}`);
  const result = await failPayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    error: 'verified mock provider failure',
    leaseToken: reserved.event.lease_token,
    failureCode: 'TEST_PROVIDER_FAILURE',
  });
  assert.equal(result.completed, true);

  const wallet = await pool.query(
    `SELECT available_balance,locked_balance FROM wallet_accounts WHERE id=$1`,
    [reserved.payout.wallet_id],
  );
  assert.equal(String(wallet.rows[0].available_balance), '1000000');
  assert.equal(String(wallet.rows[0].locked_balance), '0');
  const payout = await pool.query(`SELECT status FROM payouts WHERE id=$1`, [reserved.payout.id]);
  assert.equal(payout.rows[0].status, 'FAILED');
  const hold = await pool.query(
    `SELECT status FROM wallet_holds WHERE reference_id=$1 AND reference_type='PAYOUT'`,
    [reserved.payout.id],
  );
  assert.equal(hold.rows[0].status, 'CANCELLED');
  const operation = await pool.query(
    `SELECT status FROM financial_operations WHERE id=$1`,
    [reserved.event.payload.operationId],
  );
  assert.equal(operation.rows[0].status, 'FAILED');
  const journal = await pool.query(
    `SELECT status FROM journals WHERE operation_id=$1 AND journal_type='PAYOUT'`,
    [reserved.event.payload.operationId],
  );
  assert.equal(journal.rows[0].status, 'FAILED');
  const event = await pool.query(`SELECT status FROM outbox_events WHERE id=$1`, [reserved.event.id]);
  assert.equal(event.rows[0].status, 'FAILED');
});

test('valid UNKNOWN Payout resolution succeeds only after canonical linkage verification', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-valid-unknown-resolution');
  const reserved = await reservePayout(owner.userId, `valid-unknown:${crypto.randomUUID()}`);
  const marked = await markPayoutUnknown({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    reason: 'mock provider outcome ambiguous',
    leaseToken: reserved.event.lease_token,
  });
  assert.equal(marked.marked, true);
  assert.equal(marked.requiresReconciliation, false);

  const resolved = await resolvePayoutUnknown({
    payoutId: reserved.payout.id,
    decision: 'SUCCEEDED',
    source: 'PROVIDER_RECONCILIATION',
    providerRef: `manual-confirmation:${crypto.randomUUID()}`,
    reason: 'provider reconciliation verified settlement',
  });
  assert.equal(resolved.status, 'SUCCEEDED');
  const wallet = await pool.query(
    `SELECT available_balance,locked_balance FROM wallet_accounts WHERE id=$1`,
    [reserved.payout.wallet_id],
  );
  assert.equal(String(wallet.rows[0].available_balance), '900000');
  assert.equal(String(wallet.rows[0].locked_balance), '0');
  const hold = await pool.query(
    `SELECT status FROM wallet_holds WHERE reference_id=$1 AND reference_type='PAYOUT'`,
    [reserved.payout.id],
  );
  assert.equal(hold.rows[0].status, 'RELEASED');
});

test('ambiguous provider outcome opens critical reconciliation for a malformed hold and preserves the operation', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-unknown-linkage-mismatch');
  const reserved = await reservePayout(owner.userId, `unknown-linkage:${crypto.randomUUID()}`);
  await pool.query(
    `UPDATE wallet_holds SET amount=amount-1
      WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'`,
    [reserved.payout.id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  const result = await markPayoutUnknown({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    reason: 'provider outcome is ambiguous while the reservation linkage is inconsistent',
    leaseToken: reserved.event.lease_token,
  });

  assert.equal(result.marked, true);
  assert.equal(result.requiresReconciliation, true);
  assert.equal(result.reconciliationReason, 'PAYOUT_HOLD_LINKAGE_MISMATCH');
  const afterState = await snapshot(args);
  assert.deepEqual(afterState.wallets, before.wallets);
  assert.deepEqual(afterState.holds, before.holds);
  assert.deepEqual(afterState.walletEntries, before.walletEntries);
  assert.deepEqual(afterState.ledgerEntries, before.ledgerEntries);
  assert.equal(afterState.payouts[0].status, 'UNKNOWN');
  assert.equal(afterState.operations[0].status, 'PROCESSING');
  assert.equal(afterState.outbox[0].status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
});

test('ambiguous provider event identity mismatch records Outbox reconciliation without mutating either payout', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-unknown-cross-event');
  const intended = await reservePayout(owner.userId, `unknown-intended:${crypto.randomUUID()}`);
  const eventSource = await reservePayout(owner.userId, `unknown-source:${crypto.randomUUID()}`);
  const args = {
    userIds: [owner.userId],
    payouts: [intended, eventSource],
    events: [intended.event, eventSource.event],
  };
  const before = await snapshot(args);

  const result = await markPayoutUnknown({
    eventId: eventSource.event.id,
    payoutId: intended.payout.id,
    reason: 'provider result cannot be correlated to the requested payout',
    leaseToken: eventSource.event.lease_token,
  });

  assert.equal(result.marked, true);
  assert.equal(result.requiresReconciliation, true);
  assert.equal(result.reconciliationReason, 'PAYOUT_OUTBOX_IDENTITY_MISMATCH');
  const afterState = await snapshot(args);
  assert.deepEqual(afterState.wallets, before.wallets);
  assert.deepEqual(afterState.payouts, before.payouts);
  assert.deepEqual(afterState.holds, before.holds);
  assert.deepEqual(afterState.operations, before.operations);
  assert.deepEqual(afterState.journals, before.journals);
  assert.deepEqual(afterState.walletEntries, before.walletEntries);
  assert.deepEqual(afterState.ledgerEntries, before.ledgerEntries);
  assert.equal(afterState.outbox.find((item) => item.id === intended.event.id).status,
    before.outbox.find((item) => item.id === intended.event.id).status);
  assert.equal(afterState.outbox.find((item) => item.id === eventSource.event.id).status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].resource_type, 'outbox_event');
  assert.equal(afterState.reconciliationCases[0].resource_id, eventSource.event.id);
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
});

test('PAYOUT_EXECUTE preflight blocks provider dispatch when the locked wallet balance cannot cover the payout', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-locked-balance-preflight');
  const reserved = await reservePayout(owner.userId, `locked-balance:${crypto.randomUUID()}`);
  await pool.query(
    `UPDATE wallet_accounts SET locked_balance=locked_balance-1 WHERE id=$1`,
    [reserved.payout.wallet_id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  let providerCalls = 0;
  const originalCreatePayout = paymentProvider.createPayout;
  paymentProvider.createPayout = async () => {
    providerCalls += 1;
    return { status: 'SUCCEEDED', providerRef: 'must-not-dispatch-with-insufficient-lock' };
  };
  let result;
  try {
    result = await processOutboxEvent(reserved.event);
  } finally {
    paymentProvider.createPayout = originalCreatePayout;
  }

  assert.equal(providerCalls, 0);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT');
  const afterState = await snapshot(args);
  assert.deepEqual(afterState.wallets, before.wallets);
  assert.deepEqual(afterState.holds, before.holds);
  assert.deepEqual(afterState.journals, before.journals);
  assert.deepEqual(afterState.walletEntries, before.walletEntries);
  assert.deepEqual(afterState.ledgerEntries, before.ledgerEntries);
  assert.equal(afterState.payouts[0].status, 'UNKNOWN');
  assert.equal(afterState.operations[0].status, 'UNKNOWN');
  assert.equal(afterState.holds[0].status, 'ACTIVE');
  assert.equal(afterState.outbox[0].status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
});

test('Payout success settlement quarantines an insufficient locked balance after provider confirmation', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-success-post-provider-lock');
  const reserved = await reservePayout(owner.userId, `success-post-provider:${crypto.randomUUID()}`);
  await pool.query(
    `UPDATE wallet_accounts SET locked_balance=locked_balance-1 WHERE id=$1`,
    [reserved.payout.wallet_id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  const result = await completePayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    providerRef: `provider-confirmed:${crypto.randomUUID()}`,
    leaseToken: reserved.event.lease_token,
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT');
  const afterState = await snapshot(args);
  assert.deepEqual(afterState.wallets, before.wallets);
  assert.deepEqual(afterState.holds, before.holds);
  assert.deepEqual(afterState.journals, before.journals);
  assert.deepEqual(afterState.walletEntries, before.walletEntries);
  assert.deepEqual(afterState.ledgerEntries, before.ledgerEntries);
  assert.equal(afterState.payouts[0].status, 'UNKNOWN');
  assert.equal(afterState.operations[0].status, 'UNKNOWN');
  assert.equal(afterState.holds[0].status, 'ACTIVE');
  assert.equal(afterState.outbox[0].status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
});

test('Payout failure settlement quarantines an insufficient locked balance instead of terminally failing Outbox', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-failure-post-provider-lock');
  const reserved = await reservePayout(owner.userId, `failure-post-provider:${crypto.randomUUID()}`);
  await pool.query(
    `UPDATE wallet_accounts SET locked_balance=locked_balance-1 WHERE id=$1`,
    [reserved.payout.wallet_id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [reserved.event] };
  const before = await snapshot(args);

  const result = await failPayoutOutbox({
    eventId: reserved.event.id,
    payoutId: reserved.payout.id,
    error: 'provider confirmed payout failure',
    leaseToken: reserved.event.lease_token,
    failureCode: 'TEST_PROVIDER_FAILURE',
  });

  assert.equal(result.completed, false);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT');
  const afterState = await snapshot(args);
  assert.deepEqual(afterState.wallets, before.wallets);
  assert.deepEqual(afterState.holds, before.holds);
  assert.deepEqual(afterState.journals, before.journals);
  assert.deepEqual(afterState.walletEntries, before.walletEntries);
  assert.deepEqual(afterState.ledgerEntries, before.ledgerEntries);
  assert.equal(afterState.payouts[0].status, 'UNKNOWN');
  assert.equal(afterState.operations[0].status, 'UNKNOWN');
  assert.equal(afterState.holds[0].status, 'ACTIVE');
  assert.equal(afterState.outbox[0].status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
});

test('terminal Outbox failure quarantines an insufficient locked Payout instead of marking it failed', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-terminal-outbox-lock');
  const reserved = await reservePayout(owner.userId, `terminal-outbox-lock:${crypto.randomUUID()}`);
  const { rows: events } = await pool.query(
    `UPDATE outbox_events
        SET status='PROCESSING',attempts=1,locked_at=NOW(),lease_token=gen_random_uuid()
      WHERE id=$1
      RETURNING *`,
    [reserved.event.id],
  );
  const processingEvent = events[0];
  await pool.query(
    `UPDATE wallet_accounts SET locked_balance=locked_balance-1 WHERE id=$1`,
    [reserved.payout.wallet_id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [processingEvent] };
  const before = await snapshot(args);

  const result = await failOutboxEvent({
    eventId: processingEvent.id,
    error: 'terminal provider failure after reservation corruption',
    maxAttempts: 1,
    leaseToken: processingEvent.lease_token,
  });

  assert.equal(result.terminal, true);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_LOCKED_BALANCE_INSUFFICIENT');
  const afterState = await snapshot(args);
  assert.deepEqual(afterState.wallets, before.wallets);
  assert.deepEqual(afterState.holds, before.holds);
  assert.deepEqual(afterState.journals, before.journals);
  assert.deepEqual(afterState.walletEntries, before.walletEntries);
  assert.deepEqual(afterState.ledgerEntries, before.ledgerEntries);
  assert.equal(afterState.payouts[0].status, 'UNKNOWN');
  assert.equal(afterState.operations[0].status, 'UNKNOWN');
  assert.equal(afterState.holds[0].status, 'ACTIVE');
  assert.equal(afterState.outbox[0].status, 'DONE');
  assert.equal(afterState.reconciliationCases.length, 1);
  assert.equal(afterState.reconciliationCases[0].severity, 'CRITICAL');
  assert.equal(afterState.reconciliationCases[0].status, 'OPEN');
});

test('PAYOUT_EXECUTE quarantines Hold linkage drift occurring during provider dispatch', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-provider-race-linkage');
  const reserved = await reservePayout(owner.userId, 'provider-race-linkage:' + crypto.randomUUID());
  const { rows } = await pool.query(
    "UPDATE outbox_events SET status='PROCESSING',locked_at=NOW(),lease_token=gen_random_uuid() WHERE id=$1 RETURNING *",
    [reserved.event.id],
  );
  const processingEvent = rows[0];
  const args = { userIds: [owner.userId], payouts: [reserved], events: [processingEvent] };
  let afterInjectedMismatch = null;
  let providerCalls = 0;
  const originalCreatePayout = paymentProvider.createPayout;
  paymentProvider.createPayout = async () => {
    providerCalls += 1;
    await pool.query(
      "UPDATE wallet_holds SET amount=amount-1 WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'",
      [reserved.payout.id],
    );
    afterInjectedMismatch = await snapshot(args);
    return { status: 'SUCCEEDED', providerRef: 'confirmed-before-linkage-check' };
  };
  let result;
  try {
    result = await processOutboxEvent(processingEvent);
  } finally {
    paymentProvider.createPayout = originalCreatePayout;
  }
  assert.equal(providerCalls, 1);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.providerInvoked, true);
  assert.equal(result.reason, 'PAYOUT_HOLD_LINKAGE_MISMATCH');
  await expectIntegrityQuarantine(afterInjectedMismatch, args, { reason: result.reason, payoutId: reserved.payout.id, eventId: processingEvent.id });
});

test('terminal Outbox failure quarantines a payout linkage mismatch instead of persisting FAILED', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('payout-terminal-outbox-linkage');
  const reserved = await reservePayout(owner.userId, 'terminal-outbox-linkage:' + crypto.randomUUID());
  const { rows: events } = await pool.query(
    "UPDATE outbox_events SET status='PROCESSING',attempts=1,locked_at=NOW(),lease_token=gen_random_uuid() WHERE id=$1 RETURNING *",
    [reserved.event.id],
  );
  const processingEvent = events[0];
  await pool.query(
    "UPDATE wallet_holds SET amount=amount-1 WHERE reference_id=$1 AND reference_type='PAYOUT' AND hold_type='PAYOUT_RESERVATION' AND status='ACTIVE'",
    [reserved.payout.id],
  );
  const args = { userIds: [owner.userId], payouts: [reserved], events: [processingEvent] };
  const before = await snapshot(args);
  const result = await failOutboxEvent({
    eventId: processingEvent.id,
    error: 'terminal provider outcome with reservation linkage corruption',
    maxAttempts: 1,
    leaseToken: processingEvent.lease_token,
  });
  assert.equal(result.terminal, true);
  assert.equal(result.integrityBlocked, true);
  assert.equal(result.reason, 'PAYOUT_HOLD_LINKAGE_MISMATCH');
  await expectIntegrityQuarantine(before, args, { reason: result.reason, payoutId: reserved.payout.id, eventId: processingEvent.id });
});


test('active outbox-event reconciliation cases are independently listable without mutating finance state', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('outbox-event-reconciliation-list');
  const reserved = await reservePayout(owner.userId, 'outbox-event-list:' + crypto.randomUUID());
  const args = { userIds:[owner.userId], payouts:[reserved], events:[reserved.event] };

  const eventCase = await reconciliation.openReconciliationCase({
    caseType:'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',
    resourceType:'outbox_event',
    resourceId:reserved.event.id,
    severity:'CRITICAL',
    expected:{payoutId:reserved.payout.id,eventType:'PAYOUT_EXECUTE'},
    observed:{reason:'PAYOUT_OUTBOX_IDENTITY_MISMATCH'},
  });
  await reconciliation.openReconciliationCase({
    caseType:'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',
    resourceType:'payout',
    resourceId:reserved.payout.id,
    severity:'CRITICAL',
    expected:{payoutId:reserved.payout.id},
    observed:{reason:'PAYOUT_HOLD_LINKAGE_MISMATCH'},
  });
  const secondEventCase = await reconciliation.openReconciliationCase({
    caseType:'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',
    resourceType:'outbox_event',
    resourceId:crypto.randomUUID(),
    severity:'CRITICAL',
    expected:{},
    observed:{reason:'second-active-event'},
  });
  const resolvedEventCase = await reconciliation.openReconciliationCase({
    caseType:'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',
    resourceType:'outbox_event',
    resourceId:crypto.randomUUID(),
    severity:'HIGH',
    expected:{},
    observed:{reason:'historical-only'},
  });
  await pool.query("UPDATE reconciliation_cases SET created_at='2099-01-02T00:00:00.123456Z' WHERE id=$1", [eventCase.id]);
  await pool.query("UPDATE reconciliation_cases SET created_at='2099-01-02T00:00:00.123123Z' WHERE id=$1", [secondEventCase.id]);
  await pool.query(
    "UPDATE reconciliation_cases SET status='RESOLVED',resolved_at=NOW(),updated_at=NOW() WHERE id=$1",
    [resolvedEventCase.id],
  );

  const before = await snapshot(args);
  await assert.rejects(
    reconciliation.listActiveOutboxEventReconciliationCases({cursor:'not-a-canonical-cursor'}),
    (error) => error?.code === 'INVALID_RECONCILIATION_CURSOR',
  );
  assert.equal(typeof reconciliation.listActiveOutboxEventReconciliationCases,'function',
    'repository must expose a read-only list for event-scoped reconciliation cases');
  const firstPage = await reconciliation.listActiveOutboxEventReconciliationCases({limit:1});
  const cases = firstPage.cases;
  const found = cases.find((item)=>item.id===eventCase.id);
  assert.ok(found,'active event-scoped CRITICAL case must be returned');
  assert.equal(found.resourceType,'outbox_event');
  assert.equal(found.resourceId,reserved.event.id);
  assert.equal(found.caseType,'PAYOUT_OUTBOX_INTEGRITY_MISMATCH');
  assert.equal(found.severity,'CRITICAL');
  assert.equal(found.status,'OPEN');
  assert.equal(found.eventType,'PAYOUT_EXECUTE');
  assert.equal(found.eventStatus,reserved.event.status);
  assert.equal(cases.some((item)=>item.resourceType==='payout'),false,
    'payout-scoped cases remain in the existing UNKNOWN payout queue');
  assert.equal(cases.some((item)=>item.id===resolvedEventCase.id),false,
    'resolved historical cases must not be mixed into the active queue');
  assert.equal(firstPage.hasMore,true,'active event cases must expose additional pages');
  assert.ok(firstPage.nextCursor,'a non-final page must expose an opaque next cursor');
  const secondPage = await reconciliation.listActiveOutboxEventReconciliationCases({
    limit:1,
    cursor:firstPage.nextCursor,
  });
  assert.deepEqual(secondPage.cases.map((item)=>item.id),[secondEventCase.id]);
  assert.equal(typeof secondPage.hasMore,'boolean');
  if (secondPage.hasMore) assert.ok(secondPage.nextCursor);
  else assert.equal(secondPage.nextCursor,null);
  const afterState = await snapshot(args);
  assert.deepEqual(afterState,before,'listing reconciliation evidence must not mutate payout, wallet, Hold, Outbox or ledger state');
});

after(async () => {
  if (pool) await pool.end();
  if (enabled) await getPool().end();
});


test('event-scoped investigation notes are audited and idempotent without changing financial state', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('outbox-event-investigation');
  const intended = await reservePayout(owner.userId, `investigation-intended:${crypto.randomUUID()}`);
  const eventSource = await reservePayout(owner.userId, `investigation-event:${crypto.randomUUID()}`);
  const args = {
    userIds: [owner.userId],
    payouts: [intended, eventSource],
    events: [intended.event, eventSource.event],
  };

  const quarantine = await markPayoutUnknown({
    eventId: eventSource.event.id,
    payoutId: intended.payout.id,
    reason: 'event/payout identity cannot be correlated',
  });
  assert.equal(quarantine.requiresReconciliation, true);
  assert.equal(quarantine.reconciliationReason, 'PAYOUT_OUTBOX_IDENTITY_MISMATCH');

  const { rows: cases } = await pool.query(
    `SELECT id,resource_id,status
       FROM reconciliation_cases
      WHERE resource_type='outbox_event' AND resource_id=$1
        AND case_type='PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY'
        AND status IN ('OPEN','INVESTIGATING')`,
    [eventSource.event.id],
  );
  assert.equal(cases.length, 1);
  const caseId = cases[0].id;
  assert.equal(cases[0].status, 'OPEN');
  const before = await snapshot(args);

  const actorId = crypto.randomUUID();
  const sessionJti = `investigation-write-session:${crypto.randomUUID()}`;
  const { rows: admins } = await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,
       google_subject,admin_panel_verified_at,
       admin_panel_verified_session_jti,admin_panel_verified_scope,created_at
     ) VALUES(
       $1,'amir.davodpour@gmail.com','test','Primary Admin','ADMIN','ACTIVE',0,
       $2,NOW(),$3,'WRITE',NOW()
     )
     ON CONFLICT (email) DO UPDATE SET
       role='ADMIN',status='ACTIVE',google_subject=EXCLUDED.google_subject,
       admin_panel_verified_at=NOW(),
       admin_panel_verified_session_jti=EXCLUDED.admin_panel_verified_session_jti,
       admin_panel_verified_scope='WRITE'
     RETURNING id`,
    [actorId, `verified-investigation-admin:${crypto.randomUUID()}`, sessionJti],
  );
  const verifiedActorId = admins[0].id;

  const input = {
    caseId,
    actorId: verifiedActorId,
    sessionJti,
    verificationMinutes: 5,
    reason: 'Correlate the quarantined event against the canonical payout and provider evidence.',
    evidenceReference: `incident:${crypto.randomUUID()}`,
    verification: {
      eventIdentity: 'MISMATCH_CONFIRMED',
      canonicalPayout: 'NOT_VERIFIED',
      providerOutcome: 'NOT_CHECKED',
    },
    idempotencyKey: `event-investigation:${crypto.randomUUID()}`,
  };

  const recorded = await reconciliation.appendOutboxEventReconciliationNote(input);
  assert.equal(recorded.caseId, caseId);
  assert.equal(recorded.eventId, eventSource.event.id);
  assert.equal(recorded.action, 'INVESTIGATION_NOTE_ADDED');
  assert.equal(recorded.caseStatus, 'INVESTIGATING');
  assert.equal(recorded.replayed, false);

  const after = await snapshot(args);
  for (const field of ['wallets','payouts','holds','operations','journals','walletEntries','ledgerEntries','outbox']) {
    assert.deepEqual(after[field], before[field], `investigation note must not change ${field}`);
  }
  assert.equal(after.reconciliationCases.length, 1);
  assert.equal(after.reconciliationCases[0].status, 'INVESTIGATING');
  assert.equal(after.reconciliationCases[0].resource_type, 'outbox_event');
  assert.equal(after.reconciliationCases[0].resource_id, eventSource.event.id);

  const replay = await reconciliation.appendOutboxEventReconciliationNote(input);
  assert.equal(replay.id, recorded.id);
  assert.equal(replay.replayed, true);
  const { rows: notes } = await pool.query(
    `SELECT id,actor_id,actor_session_jti,action,reason,evidence_reference,
            verification,idempotency_key,request_hash
       FROM reconciliation_case_events
      WHERE case_id=$1 AND actor_id=$2`,
    [caseId, verifiedActorId],
  );
  assert.equal(notes.length, 1);
  assert.equal(notes[0].actor_session_jti, sessionJti);
  assert.equal(notes[0].action, 'INVESTIGATION_NOTE_ADDED');
  assert.equal(notes[0].reason, input.reason);
  assert.equal(notes[0].evidence_reference, input.evidenceReference);
  assert.deepEqual(notes[0].verification, input.verification);

  const secondInput = {
    ...input,
    reason: 'A second operator note records the independent payout lookup result.',
    evidenceReference: `incident:${crypto.randomUUID()}`,
    verification: {
      eventIdentity: 'MISMATCH_CONFIRMED',
      canonicalPayout: 'MISMATCHED',
      providerOutcome: 'UNKNOWN',
    },
    idempotencyKey: `event-investigation-second:${crypto.randomUUID()}`,
  };
  await reconciliation.appendOutboxEventReconciliationNote(secondInput);

  const firstHistoryPage = await reconciliation.listOutboxEventReconciliationNotes({
    caseId,
    limit: 1,
  });
  assert.equal(firstHistoryPage.notes.length, 1);
  assert.equal(firstHistoryPage.hasMore, true);
  assert.ok(firstHistoryPage.nextCursor);
  const visibleNote = firstHistoryPage.notes[0];
  assert.equal(visibleNote.caseId, caseId);
  assert.equal(visibleNote.eventId, eventSource.event.id);
  assert.equal(visibleNote.actorDisplayName, 'Primary Admin');
  for (const sensitiveField of ['actorSessionJti','sessionJti','requestHash','idempotencyKey']) {
    assert.equal(Object.hasOwn(visibleNote, sensitiveField), false);
  }

  const secondHistoryPage = await reconciliation.listOutboxEventReconciliationNotes({
    caseId,
    limit: 1,
    cursor: firstHistoryPage.nextCursor,
  });
  assert.equal(secondHistoryPage.notes.length, 1);
  assert.equal(secondHistoryPage.hasMore, false);
  assert.notEqual(secondHistoryPage.notes[0].id, visibleNote.id);

  const historyAfter = await snapshot(args);
  for (const field of ['wallets','payouts','holds','operations','journals','walletEntries','ledgerEntries','outbox']) {
    assert.deepEqual(historyAfter[field], before[field], `reading or appending investigation history must not change ${field}`);
  }

  await assert.rejects(
    reconciliation.appendOutboxEventReconciliationNote({
      ...input,
      reason: 'A different statement must not reuse the same idempotency key.',
    }),
    (error) => error?.code === 'IDEMPOTENCY_CONFLICT',
  );

  const { rows: afterConflict } = await pool.query(
    `SELECT count(*)::int AS count FROM reconciliation_case_events WHERE case_id=$1`,
    [caseId],
  );
  assert.equal(afterConflict[0].count, 2);

  await assert.rejects(
    pool.query(
      'UPDATE reconciliation_case_events SET reason=$2 WHERE id=$1',
      [recorded.id, 'tampered evidence must never replace original content'],
    ),
    (error) => error?.code === 'P0001' && error?.message.includes('RECONCILIATION_CASE_EVENTS_APPEND_ONLY'),
  );
  await assert.rejects(
    pool.query('DELETE FROM reconciliation_case_events WHERE id=$1', [recorded.id]),
    (error) => error?.code === 'P0001' && error?.message.includes('RECONCILIATION_CASE_EVENTS_APPEND_ONLY'),
  );
  await assert.rejects(
    pool.query('TRUNCATE reconciliation_case_events'),
    (error) => error?.code === 'P0001' && error?.message.includes('RECONCILIATION_CASE_EVENTS_APPEND_ONLY'),
  );
  await assert.rejects(
    pool.query('DELETE FROM users WHERE id=$1', [verifiedActorId]),
    (error) => ['23001','23503'].includes(error?.code),
  );
  await assert.rejects(
    reconciliationCaseEventsMigration.down(pool),
    /Cannot rollback reconciliation case events while investigation evidence exists/,
  );
  const { rows: retained } = await pool.query(
    'SELECT id,reason FROM reconciliation_case_events WHERE id=$1',
    [recorded.id],
  );
  assert.equal(retained.length, 1);
  assert.equal(retained[0].reason, input.reason);
});

test('event-scoped investigation notes reject non-primary or stale-session administrators', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('outbox-event-investigation-auth');
  const intended = await reservePayout(owner.userId, `investigation-auth-intended:${crypto.randomUUID()}`);
  const eventSource = await reservePayout(owner.userId, `investigation-auth-event:${crypto.randomUUID()}`);
  await markPayoutUnknown({
    eventId: eventSource.event.id,
    payoutId: intended.payout.id,
    reason: 'event/payout identity cannot be correlated',
  });
  const { rows: cases } = await pool.query(
    `SELECT id FROM reconciliation_cases
      WHERE resource_type='outbox_event' AND resource_id=$1
        AND status IN ('OPEN','INVESTIGATING')`,
    [eventSource.event.id],
  );
  assert.equal(cases.length, 1);
  const caseId = cases[0].id;

  const actorId = crypto.randomUUID();
  const sessionJti = `investigation-auth-session:${crypto.randomUUID()}`;
  await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,
       google_subject,admin_panel_verified_at,
       admin_panel_verified_session_jti,admin_panel_verified_scope,created_at
     ) VALUES($1,$2,'test','Operations Admin','ADMIN','ACTIVE',0,$3,NOW(),$4,'WRITE',NOW())`,
    [actorId, `operations-investigation-${actorId}@example.test`, `operations-google-${actorId}`, sessionJti],
  );

  const input = {
    caseId,
    actorId,
    sessionJti,
    verificationMinutes: 5,
    reason: 'Investigate the quarantined event using the referenced evidence.',
    evidenceReference: `incident:${crypto.randomUUID()}`,
    verification: {
      eventIdentity: 'UNRESOLVED',
      canonicalPayout: 'NOT_VERIFIED',
      providerOutcome: 'NOT_CHECKED',
    },
    idempotencyKey: `event-investigation-auth:${crypto.randomUUID()}`,
  };

  await assert.rejects(
    reconciliation.appendOutboxEventReconciliationNote(input),
    (error) => error?.code === 'PRIMARY_ADMIN_ONLY',
  );
  assert.equal(
    (await pool.query('SELECT count(*)::int AS count FROM reconciliation_case_events WHERE case_id=$1', [caseId])).rows[0].count,
    0,
  );
});

test('event-scoped investigation notes reject a stale primary-admin session JTI', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('outbox-event-investigation-stale-session');
  const intended = await reservePayout(owner.userId, `investigation-stale-intended:${crypto.randomUUID()}`);
  const eventSource = await reservePayout(owner.userId, `investigation-stale-event:${crypto.randomUUID()}`);
  await markPayoutUnknown({
    eventId: eventSource.event.id,
    payoutId: intended.payout.id,
    reason: 'event/payout identity cannot be correlated',
  });
  const { rows: cases } = await pool.query(
    `SELECT id FROM reconciliation_cases
      WHERE resource_type='outbox_event' AND resource_id=$1
        AND case_type='PAYOUT_UNKNOWN_COMMIT_INCONSISTENCY'
        AND status IN ('OPEN','INVESTIGATING')`,
    [eventSource.event.id],
  );
  assert.equal(cases.length, 1);
  const caseId = cases[0].id;
  const actorId = crypto.randomUUID();
  const storedSessionJti = `current-investigation-session:${crypto.randomUUID()}`;
  const staleSessionJti = `stale-investigation-session:${crypto.randomUUID()}`;
  const { rows: admins } = await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,
       google_subject,admin_panel_verified_at,
       admin_panel_verified_session_jti,admin_panel_verified_scope,created_at
     ) VALUES(
       $1,'amir.davodpour@gmail.com','test','Primary Admin','ADMIN','ACTIVE',0,
       $2,NOW(),$3,'WRITE',NOW()
     )
     ON CONFLICT (email) DO UPDATE SET
       role='ADMIN',status='ACTIVE',google_subject=EXCLUDED.google_subject,
       admin_panel_verified_at=NOW(),
       admin_panel_verified_session_jti=EXCLUDED.admin_panel_verified_session_jti,
       admin_panel_verified_scope='WRITE'
     RETURNING id`,
    [actorId, `verified-stale-session-admin:${crypto.randomUUID()}`, storedSessionJti],
  );
  const input = {
    caseId,
    actorId: admins[0].id,
    sessionJti: staleSessionJti,
    verificationMinutes: 5,
    reason: 'Verify this event against the independently retained evidence record.',
    evidenceReference: `incident:${crypto.randomUUID()}`,
    verification: {
      eventIdentity: 'UNRESOLVED',
      canonicalPayout: 'NOT_VERIFIED',
      providerOutcome: 'NOT_CHECKED',
    },
    idempotencyKey: `event-investigation-stale:${crypto.randomUUID()}`,
  };
  await assert.rejects(
    reconciliation.appendOutboxEventReconciliationNote(input),
    (error) => error?.code === 'ADMIN_PANEL_LOCKED',
  );
  assert.equal(
    (await pool.query('SELECT count(*)::int AS count FROM reconciliation_case_events WHERE case_id=$1', [caseId])).rows[0].count,
    0,
  );
});


test('event-scoped attestations are digest-bound, append-only, replayable across fresh sessions, and never resolve the financial quarantine', { skip: !enabled }, async () => {
  const owner = await insertFundedUser('outbox-event-attestation');
  const reserved = await reservePayout(owner.userId, `event-attestation:${crypto.randomUUID()}`);
  const args = { userIds:[owner.userId], payouts:[reserved], events:[reserved.event] };
  const eventCase = await reconciliation.openReconciliationCase({
    caseType:'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',
    resourceType:'outbox_event',
    resourceId:reserved.event.id,
    severity:'CRITICAL',
    expected:{payoutId:crypto.randomUUID(),eventType:'PAYOUT_EXECUTE'},
    observed:{reason:'EVENT_PAYOUT_IDENTITY_MISMATCH'},
  });

  const actorId = crypto.randomUUID();
  const firstSessionJti = `attestation-session:${crypto.randomUUID()}`;
  const { rows: admins } = await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,
       google_subject,admin_panel_verified_at,
       admin_panel_verified_session_jti,admin_panel_verified_scope,created_at
     ) VALUES(
       $1,'amir.davodpour@gmail.com','test','Primary Administrator','ADMIN','ACTIVE',0,
       $2,NOW(),$3,'WRITE',NOW()
     )
     ON CONFLICT (email) DO UPDATE SET
       role='ADMIN',status='ACTIVE',google_subject=EXCLUDED.google_subject,
       admin_panel_verified_at=NOW(),
       admin_panel_verified_session_jti=EXCLUDED.admin_panel_verified_session_jti,
       admin_panel_verified_scope='WRITE'
     RETURNING id`,
    [actorId, `attestation-google-${actorId}`, firstSessionJti],
  );
  const verifiedActorId = admins[0].id;
  const initial = await reconciliation.listActiveOutboxEventReconciliationCases({limit:100});
  const listedCase = initial.cases.find((item) => item.id === eventCase.id);
  assert.ok(listedCase, 'the active event-scoped quarantine must be visible');
  assert.match(
    listedCase.caseEvidenceDigest,
    /^[a-f0-9]{64}$/,
    'the queue must return a canonical SHA-256 digest for the exact case and Outbox evidence snapshot',
  );

  const before = await snapshot(args);
  const common = {
    caseId:eventCase.id,
    actorId:verifiedActorId,
    sessionJti:firstSessionJti,
    verificationMinutes:5,
    reason:'Compare the event identity with independently retained provider evidence.',
    sourceType:'PROVIDER_ARTIFACT',
    issuer:'Example Payment Provider',
    evidenceReference:`provider-case:${crypto.randomUUID()}`,
    artifactSha256:'a'.repeat(64),
    sourceObservedAt:'2026-11-15T19:00:00.000Z',
    verification:{
      eventIdentity:{result:'MISMATCH_CONFIRMED',verificationLevel:'SOURCE_ARTIFACT_REVIEWED'},
      canonicalPayout:{result:'NOT_VERIFIED',verificationLevel:'NOT_CHECKED'},
      providerOutcome:{result:'NOT_CHECKED',verificationLevel:'NOT_CHECKED'},
    },
    reviewedCaseDigest:listedCase.caseEvidenceDigest,
  };

  await assert.rejects(
    reconciliation.recordOutboxEventReconciliationAttestation({
      ...common,
      action:'INVESTIGATION_ATTESTATION_RECORDED',
      idempotencyKey:`event-invalid-extra-field:${crypto.randomUUID()}`,
      unexpectedProviderPayload:{providerSecret:'must not be accepted'},
    }),
    (error) => error?.code === 'INVALID_RECONCILIATION_ATTESTATION_FIELDS' && error?.status === 400,
  );

  const attestation = await reconciliation.recordOutboxEventReconciliationAttestation({
    ...common,
    action:'INVESTIGATION_ATTESTATION_RECORDED',
    idempotencyKey:`event-attestation:${crypto.randomUUID()}`,
  });
  assert.equal(attestation.action,'INVESTIGATION_ATTESTATION_RECORDED');
  assert.equal(attestation.caseId,eventCase.id);
  assert.equal(attestation.eventId,reserved.event.id);
  assert.equal(attestation.caseStatus,'INVESTIGATING');

  const concurrentKey = `event-concurrent-attestation:${crypto.randomUUID()}`;
  const concurrentCommand = {
    ...common,
    action:'INVESTIGATION_ATTESTATION_RECORDED',
    reason:'Concurrent duplicate requests must append exactly one immutable event.',
    idempotencyKey:concurrentKey,
  };
  const concurrentResults = await Promise.all([
    reconciliation.recordOutboxEventReconciliationAttestation(concurrentCommand),
    reconciliation.recordOutboxEventReconciliationAttestation(concurrentCommand),
  ]);
  assert.equal(concurrentResults[0].id,concurrentResults[1].id);
  assert.equal(concurrentResults.filter((item) => item.replayed === false).length,1);
  assert.equal(concurrentResults.filter((item) => item.replayed === true).length,1);
  const { rows: concurrentRows } = await pool.query(
    `SELECT id FROM reconciliation_case_events
      WHERE actor_id=$1 AND idempotency_key=$2`,
    [verifiedActorId,concurrentKey],
  );
  assert.equal(concurrentRows.length,1,
    'same-key concurrent submissions serialize to one immutable event');

  await assert.rejects(
    reconciliation.recordOutboxEventReconciliationAttestation({
      ...concurrentCommand,
      reason:'Changed semantic payload must not reuse an existing idempotency key.',
    }),
    (error) => error?.code === 'IDEMPOTENCY_CONFLICT' && error?.status === 409,
  );

  const closureInput = {
    ...common,
    action:'INVESTIGATION_CLOSED_UNRESOLVED',
    reason:'No independently corroborated financial outcome is available; retain quarantine.',
    idempotencyKey:`event-close-unresolved:${crypto.randomUUID()}`,
  };
  const closed = await reconciliation.recordOutboxEventReconciliationAttestation(closureInput);
  assert.equal(closed.action,'INVESTIGATION_CLOSED_UNRESOLVED');
  assert.equal(closed.caseStatus,'INVESTIGATING',
    'closing the investigation must not mark the financial reconciliation case RESOLVED or DISMISSED');

  const closedPage = await reconciliation.listActiveOutboxEventReconciliationCases({limit:100});
  const closedCase = closedPage.cases.find((item) => item.id === eventCase.id);
  assert.ok(closedCase, 'a closed investigation must remain in the active financial quarantine queue');
  assert.equal(closedCase.status,'INVESTIGATING');
  assert.equal(closedCase.investigationStatus,'CLOSED_UNRESOLVED');
  assert.equal(closedCase.reReviewRequired,false);

  await pool.query(
    `UPDATE reconciliation_cases
        SET expected=$2::jsonb,updated_at=NOW()
      WHERE id=$1`,
    [eventCase.id, JSON.stringify({payoutId:reserved.payout.id,eventType:'PAYOUT_EXECUTE',revision:2})],
  );
  await assert.rejects(
    reconciliation.recordOutboxEventReconciliationAttestation({
      ...common,
      action:'INVESTIGATION_REOPENED',
      reason:'Attempt to reopen using the obsolete evidence snapshot must be rejected.',
      idempotencyKey:`event-reopen-stale:${crypto.randomUUID()}`,
    }),
    (error) => error?.code === 'RECONCILIATION_EVIDENCE_STALE' && error?.status === 409,
  );

  const changedPage = await reconciliation.listActiveOutboxEventReconciliationCases({limit:100});
  const changedCase = changedPage.cases.find((item) => item.id === eventCase.id);
  assert.notEqual(changedCase.caseEvidenceDigest,listedCase.caseEvidenceDigest);
  assert.equal(changedCase.investigationStatus,'CLOSED_UNRESOLVED');
  assert.equal(changedCase.reReviewRequired,true,
    'a new case-evidence revision after closure must visibly require re-review');

  const reopenInput = {
    ...common,
    sessionJti:firstSessionJti,
    action:'INVESTIGATION_REOPENED',
    reason:'New case evidence has arrived; reopen the investigation while keeping the quarantine.',
    reviewedCaseDigest:changedCase.caseEvidenceDigest,
    idempotencyKey:`event-reopen-current:${crypto.randomUUID()}`,
  };
  const reopened = await reconciliation.recordOutboxEventReconciliationAttestation(reopenInput);
  assert.equal(reopened.action,'INVESTIGATION_REOPENED');
  assert.equal(reopened.caseStatus,'INVESTIGATING');

  const refreshedPage = await reconciliation.listActiveOutboxEventReconciliationCases({limit:100});
  const refreshedCase = refreshedPage.cases.find((item) => item.id === eventCase.id);
  assert.equal(refreshedCase.investigationStatus,'IN_PROGRESS');
  assert.equal(refreshedCase.reReviewRequired,false);

  const nextSessionJti = `attestation-retry-session:${crypto.randomUUID()}`;
  await pool.query(
    `UPDATE users
        SET admin_panel_verified_at=NOW(),
            admin_panel_verified_session_jti=$2,
            admin_panel_verified_scope='WRITE'
      WHERE id=$1`,
    [verifiedActorId,nextSessionJti],
  );
  await assert.rejects(
    reconciliation.recordOutboxEventReconciliationAttestation({
      ...reopenInput,
      sessionJti:firstSessionJti,
    }),
    (error) => error?.code === 'ADMIN_PANEL_LOCKED' && error?.status === 403,
    'an idempotent replay must still reject the original session after its WRITE step-up has been replaced',
  );
  const replay = await reconciliation.recordOutboxEventReconciliationAttestation({
    ...reopenInput,
    sessionJti:nextSessionJti,
    verificationMinutes:30,
  });
  assert.equal(replay.id,reopened.id);
  assert.equal(replay.replayed,true,
    'same actor/key and semantic payload must replay across a fresh session and verification TTL');

  const history = await reconciliation.listOutboxEventReconciliationNotes({caseId:eventCase.id,limit:20});
  const reopenedEvent = history.notes.find((item) => item.id === reopened.id);
  assert.ok(reopenedEvent);
  assert.equal(reopenedEvent.actorId,verifiedActorId,
    'restricted Admin history must preserve the stable actor UUID');
  assert.equal(reopenedEvent.actorSessionJti,undefined);
  assert.equal(reopenedEvent.sourceType,'PROVIDER_ARTIFACT');
  assert.equal(reopenedEvent.issuer,'Example Payment Provider');
  assert.equal(reopenedEvent.artifactSha256,'a'.repeat(64));
  assert.equal(reopenedEvent.sourceObservedAt,'2026-11-15T19:00:00.000000Z');
  assert.equal(reopenedEvent.reviewedCaseDigest,changedCase.caseEvidenceDigest);
  assert.equal(reopenedEvent.createdAt.length > 20,true,
    'server record time remains distinct from source-observed time');

  const { rows: stored } = await pool.query(
    `SELECT actor_session_jti,request_hash,action,reviewed_case_digest
       FROM reconciliation_case_events
      WHERE id=$1`,
    [reopened.id],
  );
  assert.equal(stored.length,1);
  assert.equal(stored[0].actor_session_jti,firstSessionJti,
    'replay in a new session must not overwrite original-session provenance');
  assert.match(stored[0].request_hash,/^[a-f0-9]{64}$/);
  assert.equal(stored[0].action,'INVESTIGATION_REOPENED');

  await assert.rejects(
    pool.query(
      'UPDATE reconciliation_case_events SET reason=$2 WHERE id=$1',
      [reopened.id,'tampered attestation must remain immutable'],
    ),
    (error) => error?.code === 'P0001' && error?.message.includes('RECONCILIATION_CASE_EVENTS_APPEND_ONLY'),
  );
  await assert.rejects(
    pool.query('DELETE FROM reconciliation_case_events WHERE id=$1',[reopened.id]),
    (error) => error?.code === 'P0001' && error?.message.includes('RECONCILIATION_CASE_EVENTS_APPEND_ONLY'),
  );
  await assert.rejects(
    pool.query('TRUNCATE reconciliation_case_events'),
    (error) => error?.code === 'P0001' && error?.message.includes('RECONCILIATION_CASE_EVENTS_APPEND_ONLY'),
  );

  const { rows: audit } = await pool.query(
    `SELECT action,actor_id,entity_id
       FROM audit_logs
      WHERE entity_type='reconciliation_case' AND entity_id=$1
        AND action IN (
          'OUTBOX_EVENT_RECONCILIATION_ATTESTED',
          'OUTBOX_EVENT_RECONCILIATION_CLOSED_UNRESOLVED',
          'OUTBOX_EVENT_RECONCILIATION_REOPENED'
        )
      ORDER BY action`,
    [eventCase.id],
  );
  assert.equal(audit.length,4,'each accepted attestation/disposition must have a same-transaction audit entry, including exactly one row for the concurrent replay key');
  assert.ok(audit.every((item) => item.actor_id === verifiedActorId));

  const after = await snapshot(args);
  for (const field of ['wallets','payouts','holds','operations','journals','walletEntries','ledgerEntries','outbox']) {
    assert.deepEqual(after[field],before[field],
      `attestation, close, reopen, replay and evidence reads must not change ${field}`);
  }
  assert.equal(after.reconciliationCases.length,1);
  assert.equal(after.reconciliationCases[0].resource_type,'outbox_event');
  assert.equal(after.reconciliationCases[0].status,'INVESTIGATING',
    'the underlying financial quarantine must remain active after investigation closure/reopening');
  await assert.rejects(
    reconciliationEventAttestationMigration.down(pool),
    /Cannot rollback event attestation migration while attestation or disposition evidence exists/,
    'migration rollback must refuse to erase immutable attestation/disposition evidence',
  );
});
