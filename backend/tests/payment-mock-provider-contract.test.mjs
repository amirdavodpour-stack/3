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

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});
