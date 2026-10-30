import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync(new URL('../src/repository/payment_refunds.js', import.meta.url), 'utf8');
const outbox = fs.readFileSync(new URL('../src/repository/outbox.js', import.meta.url), 'utf8');
const routes = fs.readFileSync(new URL('../src/routes/payment_routes.js', import.meta.url), 'utf8');

test('refund idempotency reopens a terminally failed refund instead of returning a dead operation', () => {
  assert.match(source, /SELECT \* FROM refunds WHERE payment_id=\$1 AND idempotency_key=\$2 FOR UPDATE/);
  assert.match(source, /refundRow\?\.status === 'REFUNDED'/);
  assert.match(source, /refundRow\?\.status === 'PENDING'/);
  assert.match(source, /refundRow\?\.status === 'FAILED'/);
  assert.match(source, /UPDATE refunds SET status='PENDING',provider_ref=NULL/);
  assert.match(source, /UPDATE payments SET status='REFUND_PENDING'/);
  assert.match(source, /payment\.status.*HELD.*RELEASE_PENDING.*RELEASE_FAILED|\['HELD','RELEASE_PENDING','RELEASE_FAILED'\]/);
  assert.match(source, /PAYMENT_RELEASE.*SUPERSEDED_BY_REFUND|SUPERSEDED_BY_REFUND/);
  assert.match(source, /PAYMENT_REFUND:\$\{paymentId\}/);
  assert.match(source, /status IN \('PENDING','FAILED'\)/);
  assert.match(source, /REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY/);
  assert.match(source, /attempts=CASE WHEN outbox_events\.status='FAILED' THEN 0 ELSE outbox_events\.attempts END/);
  assert.match(source, /locked_at=CASE WHEN outbox_events\.status='FAILED' THEN NULL ELSE outbox_events\.locked_at END/);
  assert.match(source, /lease_token=CASE WHEN outbox_events\.status='FAILED' THEN NULL ELSE outbox_events\.lease_token END/);
  assert.match(source, /last_error=CASE WHEN outbox_events\.status='FAILED' THEN NULL ELSE outbox_events\.last_error END/);
  assert.match(source, /processed_at=CASE WHEN outbox_events\.status='FAILED' THEN NULL ELSE outbox_events\.processed_at END/);
  assert.match(source, /refundId:refundRow\.id/);
  assert.match(routes, /REFUND_RETRY_REQUIRES_SAME_IDEMPOTENCY_KEY/);
});

test('terminal refund failure restores the payment to HELD so the semantic retry is valid', () => {
  assert.match(outbox, /event_type='PAYMENT_REFUND'/);
  assert.match(outbox, /UPDATE refunds r SET status='FAILED'/);
  assert.match(outbox, /UPDATE payments p SET status='HELD'/);
});
