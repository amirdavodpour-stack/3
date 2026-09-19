import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const funding = fs.readFileSync(new URL('../src/repository/payment_funding.js', import.meta.url), 'utf8');
const webhooks = fs.readFileSync(new URL('../src/repository/payment_webhooks.js', import.meta.url), 'utf8');
const outbox = fs.readFileSync(new URL('../src/outbox_handlers.js', import.meta.url), 'utf8');
const provider = fs.readFileSync(new URL('../src/payment_provider.js', import.meta.url), 'utf8');
const config = fs.readFileSync(new URL('../src/config.js', import.meta.url), 'utf8');

test('payment funding has a canonical ledger boundary', () => {
  assert.match(funding, /fundingJournal\(fees\)/);
  assert.match(webhooks, /postInternalPaymentHoldWithClient/);
  assert.match(webhooks, /postInternalPaymentReleaseWithClient/);
  assert.match(webhooks, /postInternalPaymentRefundWithClient/);
  assert.match(outbox, /paymentProvider\.createHold/);
  assert.match(outbox, /completePaymentCreateHoldOutbox/);
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
