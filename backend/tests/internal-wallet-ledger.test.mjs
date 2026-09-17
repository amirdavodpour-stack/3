import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const provider = fs.readFileSync(new URL('../src/payment_provider.js', import.meta.url), 'utf8');
const legacyMigration = fs.readFileSync(new URL('../src/db/migrations/005_internal_wallet_ledger.js', import.meta.url), 'utf8');
const migration = fs.readFileSync(new URL('../src/db/migrations/006_financial_core.js', import.meta.url), 'utf8');
const ledger = fs.readFileSync(new URL('../src/wallet_ledger.js', import.meta.url), 'utf8');
const outbox = fs.readFileSync(new URL('../src/repository/outbox.js', import.meta.url), 'utf8');
const refunds = fs.readFileSync(new URL('../src/repository/payment_refunds.js', import.meta.url), 'utf8');
const routes = fs.readFileSync(new URL('../src/application/wallet_routes.js', import.meta.url), 'utf8');
const config = fs.readFileSync(new URL('../src/config.js', import.meta.url), 'utf8');
const envCheck = fs.readFileSync(new URL('../scripts/validate-production-env.sh', import.meta.url), 'utf8');

test('internal provider is an application-local rail, not an external HTTP adapter', () => {
  assert.match(provider, /name === 'internal'/);
  const internal = provider.slice(provider.indexOf("name === 'internal'"), provider.indexOf("name === 'webhook'"));
  assert.doesNotMatch(internal, /fetch\(/);
  assert.match(internal, /status: 'HELD'/);
  assert.match(internal, /status: 'RELEASED'/);
  assert.match(internal, /status: 'REFUNDED'/);
});

test('financial core migrates wallets to TOMAN and adds canonical immutable primitives', () => {
  assert.match(legacyMigration, /version: 5/);
  assert.match(migration, /version: 6/);
  assert.match(migration, /ALTER TABLE wallet_accounts/);
  assert.match(migration, /BIGINT/);
  assert.match(migration, /'TOMAN'/);
  for (const table of ['financial_operations','idempotency_keys','wallet_holds','wallet_entries','journals','payouts','provider_events','reconciliation_cases']) assert.match(migration, new RegExp(`CREATE TABLE IF NOT EXISTS ${table}`));
  assert.match(migration, /wallet_accounts_user_uq/);
});

test('internal payment completion uses wallet balances and idempotent transaction records', () => {
  assert.match(ledger, /postInternalPaymentHoldWithClient/);
  assert.match(ledger, /postInternalPaymentReleaseWithClient/);
  assert.match(ledger, /postInternalPaymentRefundWithClient/);
  assert.match(ledger, /wallet_entries/);
  assert.match(ledger, /financial_operations/);
  assert.match(ledger, /CUSTOMER_WALLET_LIABILITY/);
  assert.match(outbox, /config\.paymentProvider === 'internal'/);
  assert.match(refunds, /config\.paymentProvider === 'internal'/);
  assert.match(outbox, /internal:hold/);
  assert.match(outbox, /internal:release/);
  assert.match(refunds, /internal:refund/);
});

test('production permits only internal or webhook payment rails', () => {
  assert.match(config, /\['webhook','internal'\]/);
  assert.match(config, /PAYMENT_CURRENCY=TOMAN is required when PAYMENT_PROVIDER=internal/);
  assert.match(envCheck, /webhook\|internal/);
  assert.match(envCheck, /webhook\|internal/);
});

test('wallet routes expose balance/history and keep sandbox credit gated', () => {
  assert.match(routes, /parts\[1\] === 'me'/);
  assert.match(routes, /parts\[1\] === 'transactions'/);
  assert.match(routes, /sandbox-credit/);
  assert.match(routes, /config\.internalWalletAdminCreditEnabled/);
});


test('release/refund internal paths use the canonical Financial Core journal exactly once', () => {
  const releaseStart = outbox.indexOf("if (config.paymentProvider === 'internal')", outbox.indexOf('completePaymentReleaseOutbox'));
  const releaseEnd = outbox.indexOf("} else {", releaseStart);
  const releaseInternal = outbox.slice(releaseStart, releaseEnd);
  const refundStart = refunds.indexOf("if (config.paymentProvider === 'internal')");
  const refundEnd = refunds.indexOf("} else {", refundStart);
  const refundInternal = refunds.slice(refundStart, refundEnd);
  assert.match(releaseInternal, /postInternalPaymentReleaseWithClient/);
  assert.doesNotMatch(releaseInternal, /journalId/);
  assert.match(refundInternal, /postInternalPaymentRefundWithClient/);
  assert.doesNotMatch(refundInternal, /journalId/);
});

test('internal payout is routed through the durable outbox boundary', () => {
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  const routesText = fs.readFileSync(new URL('../src/application/wallet_routes.js', import.meta.url), 'utf8');
  assert.ok(payoutRepo.includes('PAYOUT_EXECUTE'));
  assert.ok(payoutRepo.includes("'RESERVED'"));
  assert.ok(outbox.includes('PAYOUT_EXECUTE'));
  assert.ok(provider.includes('createPayout'));
  assert.ok(routesText.includes("parts[1] === 'withdraw'"));
});


test('payout operation stays processing until provider settlement and releases reservation on terminal failure', () => {
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  const outboxRepo = fs.readFileSync(new URL('../src/repository/outbox.js', import.meta.url), 'utf8');
  assert.match(payoutRepo, /operation_type.*PAYOUT/);
  assert.doesNotMatch(payoutRepo.slice(0, payoutRepo.indexOf('export async function markPayoutUnknown')), /status='SUCCEEDED'/);
  assert.match(payoutRepo, /status='FAILED'/);
  assert.match(payoutRepo, /available_balance=available_balance\+\$2/);
  assert.match(outboxRepo, /failPayoutOutbox/);
});


test('terminal payout failure finalizes inside the existing outbox transaction', () => {
  const outboxRepo = fs.readFileSync(new URL('../src/repository/outbox.js', import.meta.url), 'utf8');
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  assert.match(outboxRepo, /failPayoutOutboxWithClient\(client/);
  assert.match(payoutRepo, /export async function failPayoutOutboxWithClient/);
  assert.doesNotMatch(outboxRepo, /failPayoutOutbox\(\{ eventId/);
});


test('financial integrity guards protect immutable entries, wallet identity, and TOMAN amount invariants', () => {
  const guards = fs.readFileSync(new URL('../src/db/migrations/007_financial_integrity_guards.js', import.meta.url), 'utf8');
  assert.match(guards, /version: 7/);
  assert.match(guards, /wallet_entries_immutable_trigger/);
  assert.match(guards, /journals_posted_immutable_trigger/);
  assert.match(guards, /financial_operations_identity_trigger/);
  assert.match(guards, /wallet_identity_immutable_trigger/);
  assert.match(guards, /available_balance >= 0 AND locked_balance >= 0/);
  assert.match(guards, /financial_operations_completed_at_chk/);
  assert.match(ledger, /INVALID_PAYMENT_BREAKDOWN/);
  assert.match(ledger, /allowZero: true/);
});

test('payout path preserves exact TOMAN integers without Number coercion', () => {
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  assert.match(payoutRepo, /const MAX_AMOUNT = 9_000_000_000_000_000n/);
  assert.match(payoutRepo, /const n = BigInt\(raw\)/);
  assert.doesNotMatch(payoutRepo.slice(0, payoutRepo.indexOf('export async function markPayoutUnknown')), /Number\([^)]*p\.amount/);
  assert.doesNotMatch(payoutRepo.slice(0, payoutRepo.indexOf('export async function markPayoutUnknown')), /Number\([^)]*available_balance/);
});

test('payout amount parser shares the Financial Core maximum boundary', () => {
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  assert.match(payoutRepo, /MAX_AMOUNT = 9_000_000_000_000_000/);
  assert.match(payoutRepo, /n > MAX_AMOUNT/);
});

test('payout settlement credits worker payable, and UNKNOWN payout has admin resolution controls', () => {
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  const adminRoutes = fs.readFileSync(new URL('../src/routes/admin_routes.js', import.meta.url), 'utf8');
  const app = fs.readFileSync(new URL('../src/app.js', import.meta.url), 'utf8');
  const provider = fs.readFileSync(new URL('../src/payment_provider.js', import.meta.url), 'utf8');
  const outboxHandlers = fs.readFileSync(new URL('../src/outbox_handlers.js', import.meta.url), 'utf8');
  assert.match(payoutRepo, /WORKER_PAYABLE/);
  assert.match(payoutRepo, /listUnknownPayouts/);
  assert.match(payoutRepo, /resolvePayoutUnknown/);
  assert.match(adminRoutes, /payouts.*unknown/);
  assert.match(adminRoutes, /payouts.*resolve/);
  assert.match(app, /listUnknownPayouts: repo\.listUnknownPayouts/);
  assert.match(provider, /INTERNAL_PROVIDER_PAYOUT_OUTCOME/);
  assert.match(provider, /UNKNOWN/);
  assert.match(outboxHandlers, /markPayoutUnknown/);
});


test('payout idempotency is re-checked after the wallet lock for concurrent request safety', () => {
  const payoutRepo = fs.readFileSync(new URL('../src/repository/payouts.js', import.meta.url), 'utf8');
  const start = payoutRepo.indexOf('export async function requestPayoutAtomic');
  const body = payoutRepo.slice(start, payoutRepo.indexOf('export async function markPayoutUnknown', start));
  assert.match(body, /SELECT \* FROM payouts WHERE user_id=\$1 AND idempotency_key=\$2 FOR UPDATE/);
  assert.match(body, /Re-check the idempotency resource after acquiring the wallet lock/);
});


test('funding failure has an explicit Job recovery state and does not strand FUNDED jobs', () => {
  const funding = fs.readFileSync(new URL('../src/repository/payment_funding.js', import.meta.url), 'utf8');
  const outboxRepo = fs.readFileSync(new URL('../src/repository/outbox.js', import.meta.url), 'utf8');
  const recovery = fs.readFileSync(new URL('../src/db/migrations/008_funding_job_recovery.js', import.meta.url), 'utf8');
  const journalGuard = fs.readFileSync(new URL('../src/db/migrations/009_posted_journal_entry_immutability.js', import.meta.url), 'utf8');
  const stateGuard = fs.readFileSync(new URL('../src/db/migrations/010_state_transition_guards.js', import.meta.url), 'utf8');
  assert.match(recovery, /version: 8/);
  assert.match(journalGuard, /version: 9/);
  assert.match(journalGuard, /ledger_entries_posted_journal_immutable_trigger/);
  assert.match(stateGuard, /version: 10/);
  assert.match(stateGuard, /payment_state_transition_guard/);
  assert.match(stateGuard, /job_state_transition_guard/);
  assert.match(stateGuard, /HOLD_PENDING.*HELD.*HOLD_FAILED/);
  assert.match(stateGuard, /COMPLETED.*SETTLED/);
  assert.match(recovery, /funding_previous_job_status/);
  assert.match(funding, /funding_previous_job_status/);
  assert.match(funding, /job\.status/);
  assert.match(funding, /HOLD_FAILED/);
  assert.match(outboxRepo, /PAYMENT_HOLD_FAILED/);
  assert.match(outboxRepo, /restoredJobStatus/);
  assert.match(outboxRepo, /status=\$2,updated_at=NOW\(\) WHERE id=\$1/);
});

test('wallet ledger preserves exact TOMAN integers across all mutation paths', () => {
  const ledger = fs.readFileSync(new URL('../src/wallet_ledger.js', import.meta.url), 'utf8');
  assert.match(ledger, /MAX_AMOUNT = 9_000_000_000_000_000n/);
  assert.match(ledger, /const parsed = BigInt\(raw\)/);
  assert.doesNotMatch(ledger, /Number\(raw\)/);
  assert.doesNotMatch(ledger, /Number\(hold\.amount\)/);
  assert.match(ledger, /BigInt\(String\(lockedSource\.available_balance\)\) < value/);
});

test('wallet mutations re-check authoritative wallet status after acquiring the row lock', () => {
  const source = fs.readFileSync(new URL('../src/wallet_ledger.js', import.meta.url), 'utf8');
  assert.ok(source.includes('const [lockedPayer] = await lockWallets(client, [payer.id]);\n  assertActive(lockedPayer);'));
  assert.ok(source.includes('const [lockedSource, lockedDestination] = await lockWallets(client, [source.id, destination.id]);\n    assertActive(lockedSource);\n    assertActive(lockedDestination);'));
  assert.match(source, /assertReceivable\(lockedWorker\)/);
  assert.match(source, /balanceAfter/);
});

test('release semantics do not create a second payer-side debit after HOLD', () => {
  const source = fs.readFileSync(new URL('../src/wallet_ledger.js', import.meta.url), 'utf8');
  const start = source.indexOf('export async function postInternalPaymentReleaseWithClient');
  const end = source.indexOf('export async function postInternalPaymentRefundWithClient', start);
  const body = source.slice(start, end);
  assert.match(body, /Only the worker receives a wallet CREDIT/);
  assert.doesNotMatch(body, /entryType: 'RELEASE'.*direction: 'DEBIT'/s);
  assert.match(body, /entryType: 'RELEASE'.*direction: 'CREDIT'/s);
});

test('latest financial migrations define database-enforced terminal and currency boundaries', () => {
  const migrations = Object.fromEntries([14,15,16,17,18,19,20,21].map((v) => {
    const name = fs.readdirSync(new URL('../src/db/migrations', import.meta.url)).find((f) => f.startsWith(String(v).padStart(3,'0') + '_'));
    return [v, fs.readFileSync(new URL(`../src/db/migrations/${name}`, import.meta.url), 'utf8')];
  }));
  assert.match(migrations[14], /terminal_immutability/);
  assert.match(migrations[15], /provider_ref/);
  assert.match(migrations[16], /wallet_holds_active_reference_uq/);
  assert.match(migrations[17], /ALTER COLUMN debit TYPE BIGINT/);
  assert.match(migrations[18], /payouts_user_created_cursor_idx/);
  assert.match(migrations[19], /financial_operation_state_transition_guard/);
  assert.match(migrations[20], /financial_operation_terminal_immutability_trigger/);
  assert.match(migrations[21], /refunds_currency_chk/);
});

test('refund persistence carries explicit payment currency through migration 021', () => {
  const refunds = fs.readFileSync(new URL('../src/repository/payment_refunds.js', import.meta.url), 'utf8');
  const serialization = fs.readFileSync(new URL('../src/db/serialization.js', import.meta.url), 'utf8');
  assert.match(refunds, /INSERT INTO refunds\(id,payment_id,amount,currency,status/);
  assert.match(refunds, /payment\.currency \|\| config\.paymentCurrency/);
  assert.match(serialization, /case 'refunds':/);
  assert.match(serialization, /currency:r\.currency \|\| config\.paymentCurrency/);
});


test('wallet mutation routes expose deterministic amount and idempotency error contracts', () => {
  const routesText = fs.readFileSync(new URL('../src/application/wallet_routes.js', import.meta.url), 'utf8');
  assert.match(routesText, /error\.code === 'INVALID_AMOUNT'/g);
  assert.match(routesText, /error\.code === 'IDEMPOTENCY_CONFLICT'/g);
  assert.match(routesText, /error\.code === 'IDEMPOTENCY_IN_PROGRESS'/g);
  assert.match(routesText, /error\.code === 'WALLET_UNAVAILABLE'/g);
});
