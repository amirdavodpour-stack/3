import test from 'node:test';
import assert from 'node:assert/strict';

let normalizeOutboxFailureMetadata = null;
let importError = null;
try {
  ({ normalizeOutboxFailureMetadata } = await import('../src/outbox_failure_metadata.js'));
} catch (error) {
  importError = error;
}

test('normalizes an exact provider HTTP error into a safe code, category, retry state and status', () => {
  assert.equal(importError, null, 'outbox failure metadata normalizer must be implemented');
  const error = Object.assign(new Error('NOTIFICATION_PROVIDER_HTTP_503'), {
    code: 'NOTIFICATION_PROVIDER_HTTP_503',
    responseBody: 'private response must never be copied',
  });
  assert.deepEqual(
    normalizeOutboxFailureMetadata({
      eventType:'NOTIFICATION_DISPATCH',
      payload:{ channel:'EMAIL' },
      error,
      retryable:true,
    }),
    { code:'NOTIFICATION_PROVIDER_HTTP_ERROR', category:'email', retryable:true, httpStatus:503 },
  );
});

test('untrusted exception message, error code, status and body collapse to a safe event-class fallback', () => {
  assert.equal(importError, null, 'outbox failure metadata normalizer must be implemented');
  const secret = 'Bearer private-token david@example.test raw-provider-body';
  const error = Object.assign(new Error(secret), {
    code: 'PRIVATE_USER_CONTROLLED_ERROR_CODE',
    status: 503,
    responseBody: secret,
  });
  const metadata = normalizeOutboxFailureMetadata({
    eventType:'PAYOUT_EXECUTE',
    payload:{},
    error,
    retryable:false,
  });
  assert.deepEqual(metadata, {
    code:'PAYOUT_PROVIDER_FAILED',
    category:'payout',
    retryable:false,
    httpStatus:null,
  });
  assert.equal(JSON.stringify(metadata).includes(secret), false);
});

test('only recognized event types and channels control the persisted failure category', () => {
  assert.equal(importError, null, 'outbox failure metadata normalizer must be implemented');
  assert.equal(
    normalizeOutboxFailureMetadata({eventType:'PAYMENT_RELEASE',payload:{},error:'unexpected',retryable:false}).category,
    'payment',
  );
  assert.equal(
    normalizeOutboxFailureMetadata({eventType:'AUTH_REFRESH_REUSE_ALERT',payload:{},error:'unexpected',retryable:false}).category,
    'security',
  );
  assert.equal(
    normalizeOutboxFailureMetadata({eventType:'NOTIFICATION_DISPATCH',payload:{channel:'PUSH'},error:'unexpected',retryable:false}).category,
    'push',
  );
  assert.equal(
    normalizeOutboxFailureMetadata({eventType:'UNKNOWN_EVENT',payload:{},error:'unexpected',retryable:false}).category,
    'system',
  );
});

test('an HTTP-like status property without an exact recognized provider error is not trusted', () => {
  assert.equal(importError, null, 'outbox failure metadata normalizer must be implemented');
  const error = Object.assign(new Error('sensitive provider response'), { status: 429 });
  const metadata = normalizeOutboxFailureMetadata({
    eventType:'PAYMENT_RELEASE',payload:{},error,retryable:true,
  });
  assert.equal(metadata.httpStatus, null);
  assert.equal(metadata.code, 'OUTBOX_PROCESSING_FAILED');
});
