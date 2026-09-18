import test from 'node:test';
import assert from 'node:assert/strict';

const base = String(process.env.MOCK_PROVIDER_BASE_URL || '').replace(/\/$/, '');
if (!base) {
  test('live mock payment provider contract', { skip: 'MOCK_PROVIDER_BASE_URL is not configured' }, () => {});
} else {
  const token = String(process.env.PAYMENT_PROVIDER_TOKEN || '');
  const { createPaymentProvider } = await import('../src/payment_provider.js');
  const provider = createPaymentProvider('webhook');

  const directPost = async (path, body, key, authorization = token) => {
    const response = await fetch(base + path, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${authorization}`,
        'content-type': 'application/json',
        'idempotency-key': key,
      },
      body: JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  };

  test('live mock provider process is reachable and implements create/release/refund', async () => {
    const health = await fetch(base + '/health');
    assert.equal(health.status, 200);
    const healthBody = await health.json();
    assert.equal(healthBody.ok, true);
    assert.equal(healthBody.provider, 'MOCK');

    const paymentId = 'live-mock-payment-1';
    const created = await provider.createHold({
      paymentId,
      amount: '250000',
      currency: 'TOMAN',
      idempotencyKey: 'live-create-1',
    });
    assert.equal(created.status, 'HELD');
    assert.match(created.providerRef, /^MOCK-HOLD-/);

    const replay = await provider.createHold({
      paymentId,
      amount: '250000',
      currency: 'TOMAN',
      idempotencyKey: 'live-create-1',
    });
    assert.equal(replay.providerRef, created.providerRef);
    assert.equal(replay.idempotent, true);

    const released = await provider.releaseHold({
      paymentId,
      providerRef: created.providerRef,
      currency: 'TOMAN',
      idempotencyKey: 'live-release-1',
    });
    assert.equal(released.status, 'RELEASED');
    assert.match(released.releaseRef, /^MOCK-RELEASE-/);

    const refunded = await provider.refundHold({
      paymentId,
      providerRef: created.providerRef,
      currency: 'TOMAN',
      idempotencyKey: 'live-refund-1',
    });
    assert.equal(refunded.status, 'REFUNDED');
    assert.match(refunded.refundRef, /^MOCK-REFUND-/);
  });

  test('live mock provider enforces auth, currency, and idempotency conflict', async () => {
    const unauthorized = await directPost('/create', {
      paymentId: 'live-auth-1',
      amount: '10',
      currency: 'TOMAN',
    }, 'live-auth-1', 'wrong-token');
    assert.equal(unauthorized.status, 401);

    const wrongCurrency = await directPost('/create', {
      paymentId: 'live-currency-1',
      amount: '10',
      currency: 'EUR',
    }, 'live-currency-1');
    assert.equal(wrongCurrency.status, 400);

    const first = await directPost('/create', {
      paymentId: 'live-conflict-1',
      amount: '10',
      currency: 'TOMAN',
    }, 'live-conflict-key');
    assert.equal(first.status, 200);

    const conflict = await directPost('/create', {
      paymentId: 'live-conflict-2',
      amount: '10',
      currency: 'TOMAN',
    }, 'live-conflict-key');
    assert.equal(conflict.status, 409);
    assert.equal(conflict.body.error, 'IDEMPOTENCY_CONFLICT');
  });
}
