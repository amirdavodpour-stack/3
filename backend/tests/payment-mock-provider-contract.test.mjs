import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { createMockPaymentServer } from '../../tools/staging-payment-provider/server.mjs';

const token = 'mock-provider-test-token-01234567890123456789';
const server = createMockPaymentServer({ token });
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;

const post = async (path, { paymentId = 'p1', amount = '100000', currency = 'TOMAN', key = 'idem-1', providerRef } = {}) => {
  const response = await fetch(base + path, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      'idempotency-key': key,
    },
    body: JSON.stringify({ paymentId, amount, currency, providerRef }),
  });
  return { status: response.status, body: await response.json() };
};

test('mock payment provider exposes the HOPE webhook-provider contract', async () => {
  const health = await fetch(base + '/health');
  assert.equal(health.status, 200);

  const created = await post('/create');
  assert.equal(created.status, 200);
  assert.equal(created.body.status, 'HELD');
  assert.match(created.body.providerRef, /^MOCK-HOLD-/);

  const replay = await post('/create');
  assert.equal(replay.status, 200);
  assert.equal(replay.body.providerRef, created.body.providerRef);
  assert.equal(replay.body.idempotent, true);

  const conflict = await post('/create', { paymentId: 'different', key: 'idem-1' });
  assert.equal(conflict.status, 409);

  const released = await post('/release', { key: 'rel-1', providerRef: created.body.providerRef });
  assert.equal(released.status, 200);
  assert.equal(released.body.status, 'RELEASED');
  assert.ok(released.body.releaseRef);

  const refunded = await post('/refund', { key: 'ref-1', providerRef: created.body.providerRef });
  assert.equal(refunded.status, 200);
  assert.equal(refunded.body.status, 'REFUNDED');
  assert.ok(refunded.body.refundRef);
});

test('mock payment provider rejects missing credentials and unsupported currency', async () => {
  const unauthorized = await fetch(base + '/create', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'idempotency-key': 'bad-1' },
    body: JSON.stringify({ paymentId: 'p2', amount: '10', currency: 'TOMAN' }),
  });
  assert.equal(unauthorized.status, 401);

  const wrongCurrency = await post('/create', {
    paymentId: 'p3',
    key: 'currency-1',
    currency: 'USD',
  });
  assert.equal(wrongCurrency.status, 400);
});

test('mock provider webhook emitter signs the exact HOPE webhook contract', async () => {
  const originalFetch = global.fetch;
  const captured = [];
  global.fetch = async (url, options = {}) => {
    if (String(url).startsWith('https://mock-target.invalid/')) {
      captured.push({url: String(url), headers: options.headers, body: options.body});
      return new Response(JSON.stringify({accepted: true}), {status: 200, headers: {'content-type':'application/json'}});
    }
    return originalFetch(url, options);
  };

  const emitter = createMockPaymentServer({
    token,
    webhookSecret: 'mock-webhook-secret-32-characters',
    webhookTargetUrl: 'https://mock-target.invalid/api/v1/payments/webhook',
  });
  await new Promise((resolve) => emitter.listen(0, '127.0.0.1', resolve));
  const emitterBase = `http://127.0.0.1:${emitter.address().port}`;

  try {
    const response = await fetch(emitterBase + '/emit-webhook', {
      method: 'POST',
      headers: {
        authorization: `Bearer ${token}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        paymentId: 'payment-emitter-1',
        eventType: 'PAYMENT_HELD',
        providerRef: 'MOCK-HOLD-1',
        eventId: 'evt-emitter-1',
      }),
    });
    assert.equal(response.status, 200);
    assert.equal(captured.length, 1);

    const sent = captured[0];
    assert.equal(sent.headers['x-hope-event-id'], 'evt-emitter-1');
    assert.match(sent.headers['x-hope-timestamp'], /^\d+$/);
    assert.match(sent.headers['x-hope-signature'], /^sha256=[a-f0-9]{64}$/);
    assert.deepEqual(JSON.parse(sent.body), {
      eventId: 'evt-emitter-1',
      eventType: 'PAYMENT_HELD',
      paymentId: 'payment-emitter-1',
      providerRef: 'MOCK-HOLD-1',
    });
  } finally {
    global.fetch = originalFetch;
    await new Promise((resolve) => emitter.close(resolve));
  }
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});
