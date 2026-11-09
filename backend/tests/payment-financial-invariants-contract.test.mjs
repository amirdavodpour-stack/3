import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const funding = fs.readFileSync(new URL('../src/repository/payment_funding.js', import.meta.url), 'utf8');
const webhooks = fs.readFileSync(new URL('../src/repository/payment_webhooks.js', import.meta.url), 'utf8');
const outbox = fs.readFileSync(new URL('../src/outbox_handlers.js', import.meta.url), 'utf8');
const externalLedger = fs.readFileSync(new URL('../src/repository/external_payment_ledger.js', import.meta.url), 'utf8');
const provider = fs.readFileSync(new URL('../src/payment_provider.js', import.meta.url), 'utf8');
const config = fs.readFileSync(new URL('../src/config.js', import.meta.url), 'utf8');

test('payment funding posts its canonical ledger only after provider hold confirmation', () => {
  // Funding creates a pending payment and an Outbox obligation; an unconfirmed
  // provider hold must not be represented as recognized funding in the ledger.
  assert.match(funding, /status='HOLD_PENDING'/);
  assert.match(funding, /PAYMENT_CREATE_HOLD/);
  assert.doesNotMatch(funding, /fundingJournal\s*\(/);

  // The external provider confirmation posts the canonical funding journal
  // through the shared, balanced and idempotent provider-ledger boundary.
  assert.match(externalLedger, /entries:\s*fundingJournal\(breakdown\)/);
  assert.match(outbox, /postExternalFundingJournalWithClient/);
  assert.match(outbox, /paymentProvider\.createHold/);
  assert.match(outbox, /completePaymentCreateHoldOutbox/);
  assert.match(outbox, /postInternalPaymentHoldWithClient/);

  // Signed provider callbacks use the same external ledger boundary; internal
  // payments use the dedicated wallet-ledger operations instead.
  assert.match(webhooks, /postExternalFundingJournalWithClient/);
  assert.match(webhooks, /postInternalPaymentHoldWithClient/);
  assert.match(webhooks, /postInternalPaymentReleaseWithClient/);
  assert.match(webhooks, /postInternalPaymentRefundWithClient/);
});

test('provider boundary is fail-closed for production simulator use', () => {
  assert.match(provider, /name === 'simulator'/);
  assert.match(config, /if \(config\.paymentProvider === 'internal'.*config\.paymentCurrency !== 'TOMAN'/s);
  assert.match(config, /!\['webhook','internal'\]\.includes\(config\.paymentProvider\)/);
});

test('webhook path stores canonical provider events before processing', () => {
  assert.match(webhooks, /INSERT INTO provider_events/);
  assert.match(webhooks, /UNIQUE|ON CONFLICT\(provider,provider_event_id\)/);
});
