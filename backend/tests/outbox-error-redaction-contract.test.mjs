import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = (path) => {
  try { return fs.readFileSync(new URL(path, import.meta.url), 'utf8'); }
  catch { return ''; }
};

const migration = source('../src/db/migrations/056_outbox_error_redaction.js');
const normalizer = source('../src/outbox_failure_metadata.js');
const outbox = source('../src/repository/outbox.js');
const payouts = source('../src/repository/payouts.js');
const handlers = source('../src/outbox_handlers.js');
const notifications = source('../src/repository/notifications.js');
const privacy = source('../src/repository/privacy.js');
const funding = source('../src/repository/payment_funding.js');
const refunds = source('../src/repository/payment_refunds.js');

test('migration adds constrained Outbox and payout failure metadata without rewriting legacy text', () => {
  assert.ok(migration, 'migration 056 must exist');
  for (const column of [
    'last_error_code','last_error_category','last_error_retryable','last_error_http_status',
    'failure_category','failure_retryable','failure_http_status',
  ]) assert.match(migration, new RegExp(column));
  assert.match(migration, /100 AND 599/);
  assert.match(migration, /last_error/);
  assert.doesNotMatch(migration, /UPDATE\s+(?:outbox_events|payouts)\s+SET\s+(?:last_error|failure_message)/i,
    'legacy text must not be rewritten by this additive migration');
});

test('failure normalizer is explicit and does not persist arbitrary exception text', () => {
  assert.match(normalizer, /export function normalizeOutboxFailureMetadata/);
  assert.match(normalizer, /SAFE_ERROR_CODES/);
  assert.match(normalizer, /OUTBOX_PROCESSING_FAILED/);
  assert.match(normalizer, /HTTP_STATUS_PATTERN|HTTP_ERROR_PATTERN/);
});

test('generic Outbox failure path writes structured metadata and never truncates raw exceptions into last_error', () => {
  const start = outbox.indexOf('export async function failOutboxEvent(');
  const end = outbox.indexOf('\nfunction outboxReplayError(', start);
  assert.ok(start >= 0 && end > start, 'generic Outbox failure method must exist');
  const fail = outbox.slice(start, end);
  assert.match(fail, /normalizeOutboxFailureMetadata/);
  assert.match(fail, /last_error=NULL/);
  for (const field of ['last_error_code','last_error_category','last_error_retryable','last_error_http_status']) {
    assert.match(fail, new RegExp(field));
  }
  assert.doesNotMatch(fail, /String\(error\)\.slice\(0,\s*2000\)/);
});

test('payout failure path writes allowlisted metadata and leaves the legacy message column empty', () => {
  const start = payouts.indexOf('export async function failPayoutOutboxWithClient(');
  const end = payouts.indexOf('\nexport async function failPayoutOutbox(', start);
  assert.ok(start >= 0 && end > start, 'payout failure method must exist');
  const fail = payouts.slice(start, end);
  assert.match(fail, /failure_category/);
  assert.match(fail, /failure_retryable/);
  assert.match(fail, /failure_http_status/);
  assert.match(fail, /failure_message=NULL/);
  assert.doesNotMatch(fail, /String\(error\)\.slice\(0,\s*(?:1000|2000)\)/);
});

test('payout reads never expose historical raw failure_message values', () => {
  const getStart = payouts.indexOf('export async function getPayoutForUser(');
  const listStart = payouts.indexOf('export async function listPayoutsForUser(', getStart);
  const unknownStart = payouts.indexOf('export async function listUnknownPayouts(', listStart);
  assert.ok(getStart >= 0 && listStart > getStart && unknownStart > listStart);
  const get = payouts.slice(getStart, listStart);
  const list = payouts.slice(listStart, unknownStart);
  const unknown = payouts.slice(unknownStart);
  assert.doesNotMatch(get, /SELECT \*/);
  for (const query of [get,list,unknown]) {
    assert.doesNotMatch(query, /failure_message(?:\s+AS\s+["']failureMessage["'])?/i);
  }
  assert.match(list, /failure_code AS "failureCode"/);
  assert.match(unknown, /failure_code AS "failureCode"/);
});

test('worker failure logging does not emit raw exception messages or response bodies', () => {
  const start = handlers.indexOf('} catch (error) {', handlers.indexOf("event.event_type === 'NOTIFICATION_DISPATCH'"));
  assert.ok(start >= 0, 'Outbox catch block must exist');
  const catchBlock = handlers.slice(start, start + 1800);
  assert.match(catchBlock, /normalizeOutboxFailureMetadata/);
  assert.doesNotMatch(catchBlock, /error:\s*error\?\.message\s*\|\|\s*String\(error\)/);
});

test('notification erasure, suppression, dispute hold and refund supersession use safe codes', () => {
  for (const [name, text] of [
    ['notifications',notifications],['privacy',privacy],['funding',funding],['refunds',refunds],['outbox',outbox],
  ]) {
    assert.ok(text, name + ' source must load');
    assert.match(text, /last_error_code/,
      name + ' must maintain structured Outbox error metadata');
  }
  assert.match(notifications, /normalizeOutboxFailureMetadata/);
  assert.match(privacy, /RECIPIENT_ERASED/);
  assert.match(refunds, /SUPERSEDED_BY_REFUND/);
  assert.match(outbox, /CANCELLED_BY_ADMIN_DISPUTE_HOLD/);
});

test('successful completion and all explicit requeue paths clear structured error metadata', () => {
  for (const [name, text] of [['outbox',outbox],['notifications',notifications],['funding',funding],['refunds',refunds]]) {
    assert.ok(text, name + ' source must load');
    assert.match(text, /last_error_code\s*=\s*NULL/,
      name + ' must clear old structured failure metadata when it completes or requeues an event');
  }
});
