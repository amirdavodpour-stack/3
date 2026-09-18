import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { createMockPaymentServer } from '../../tools/staging-payment-provider/server.mjs';

const enabled = Boolean(process.env.DATABASE_URL);
let mockServer;
let mockServerBase = '';
let appServer;

if (enabled) {
  mockServer = createMockPaymentServer({
    token: 'postgres-e2e-mock-provider-token-32-chars',
  });
  await new Promise((resolve) => mockServer.listen(0, '127.0.0.1', resolve));
  const port = mockServer.address().port;
  mockServerBase = `http://127.0.0.1:${port}`;

  process.env.NODE_ENV = 'test';
  process.env.PAYMENT_PROVIDER = 'webhook';
  process.env.PAYMENT_CURRENCY = 'TOMAN';
  process.env.PAYMENT_PROVIDER_TOKEN = 'postgres-e2e-mock-provider-token-32-chars';
  process.env.PAYMENT_PROVIDER_CREATE_URL = `http://127.0.0.1:${port}/create`;
  process.env.PAYMENT_PROVIDER_RELEASE_URL = `http://127.0.0.1:${port}/release`;
  process.env.PAYMENT_PROVIDER_REFUND_URL = `http://127.0.0.1:${port}/refund`;
  process.env.PAYMENT_WEBHOOK_SECRET = 'postgres-e2e-webhook-secret-32-characters';
  process.env.PAYMENT_PROVIDER_MAX_ATTEMPTS = '1';
  process.env.PAYMENT_PROVIDER_RETRY_BASE_MS = '0';
  process.env.OUTBOX_POLL_MS = '60000';
  process.env.AUTH_RATE_LIMIT_MAX = '1000';
  process.env.GENERAL_RATE_LIMIT_MAX = '5000';

  const { createServer } = await import('../src/app.js');
  appServer = createServer();
  await new Promise((resolve) => appServer.listen(0, '127.0.0.1', resolve));
}

const base = enabled ? `http://127.0.0.1:${appServer.address().port}/api/v1` : '';
const { findPaymentByJob } = await import('../src/repository.js');
const { processPaymentCreateHoldNow, processPaymentRefundNow } = await import('../src/outbox_worker.js');

const drainUntilPaymentStatus = async (jobId, expectedStatus, processNext) => {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const payment = await findPaymentByJob(jobId);
    if (payment?.status === expectedStatus) return payment;
    await processNext();
  }
  throw new Error(`PAYMENT_STATUS_DID_NOT_REACH_${expectedStatus}`);
};
const json = async (path, options = {}) => {
  const response = await fetch(base + path, {
    ...options,
    headers: { 'content-type': 'application/json', ...(options.headers || {}) },
  });
  return { status: response.status, body: await response.json() };
};

const register = async (label) => {
  const email = `${label}-${crypto.randomUUID()}@example.test`;
  const result = await json('/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      email,
      password: 'pass123456789',
      displayName: label,
    }),
  });
  assert.equal(result.status, 201);
  return result.body.data;
};

const createFundableMission = async (owner, provider) => {
  const categories = await json('/categories');
  assert.equal(categories.status, 200);
  const job = await json('/jobs', {
    method: 'POST',
    headers: { Authorization: `Bearer ${owner.accessToken}` },
    body: JSON.stringify({
      title: 'Webhook payment mission',
      description: 'External provider integration test',
      categoryId: categories.body.data[0].id,
      jobType: 'FIXED',
      budgetType: 'FIXED',
      budgetMin: 1000000,
      budgetMax: 1000000,
      duration: 2,
      acceptanceCriteria: 'Done',
      city: 'تهران',
      kind: 'MISSION',
      visibility: 'PUBLIC',
    }),
  });
  assert.equal(job.status, 201);

  const published = await json(`/jobs/${job.body.data.id}/publish`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${owner.accessToken}` },
  });
  assert.equal(published.status, 200);

  const offer = await json('/offers', {
    method: 'POST',
    headers: { Authorization: `Bearer ${provider.accessToken}` },
    body: JSON.stringify({
      jobId: job.body.data.id,
      price: 1000000,
      message: 'accept',
    }),
  });
  assert.equal(offer.status, 201);

  const accepted = await json(`/offers/${offer.body.data.id}/accept`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${owner.accessToken}` },
  });
  assert.equal(accepted.status, 200);

  return job.body.data;
};

test('PostgreSQL payment fund uses the real webhook provider boundary and commits HOLD', { skip: !enabled }, async () => {
  const owner = await register('webhook-owner');
  const provider = await register('webhook-provider');
  const job = await createFundableMission(owner, provider);

  const funded = await json(`/payments/fund/${job.id}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${owner.accessToken}`,
      'Idempotency-Key': `webhook-fund-${job.id}`,
    },
    body: '{}',
  });

  assert.ok([201, 202].includes(funded.status));
  const payment = await drainUntilPaymentStatus(job.id, 'HELD', processPaymentCreateHoldNow);
  assert.equal(payment.currency, 'TOMAN');
  assert.match(payment.provider_ref || payment.providerRef, /^MOCK-HOLD-/);
});

test('PostgreSQL payment refund uses the webhook provider boundary and commits REFUNDED', { skip: !enabled }, async () => {
  const owner = await register('webhook-refund-owner');
  const provider = await register('webhook-refund-provider');
  const job = await createFundableMission(owner, provider);

  const funded = await json(`/payments/fund/${job.id}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${owner.accessToken}`,
      'Idempotency-Key': `webhook-refund-fund-${job.id}`,
    },
    body: '{}',
  });
  assert.ok([201, 202].includes(funded.status));
  await drainUntilPaymentStatus(job.id, 'HELD', processPaymentCreateHoldNow);

  const refunded = await json(`/payments/refund/${job.id}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${owner.accessToken}`,
      'Idempotency-Key': `webhook-refund-${job.id}`,
    },
    body: '{}',
  });

  assert.ok([200, 202].includes(refunded.status));
  const payment = await drainUntilPaymentStatus(job.id, 'REFUNDED', processPaymentRefundNow);
  assert.equal(payment.status, 'REFUNDED');
  assert.ok(refunded.body.refund);
});


test('PostgreSQL payment release uses the webhook provider boundary and commits RELEASED', { skip: !enabled }, async () => {
  const owner = await register('webhook-release-owner');
  const provider = await register('webhook-release-provider');
  const job = await createFundableMission(owner, provider);

  const funded = await json(`/payments/fund/${job.id}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${owner.accessToken}`,
      'Idempotency-Key': `webhook-release-fund-${job.id}`,
    },
    body: '{}',
  });
  assert.ok([201, 202].includes(funded.status));
  const held = await drainUntilPaymentStatus(job.id, 'HELD', processPaymentCreateHoldNow);
  assert.match(held.provider_ref || held.providerRef, /^MOCK-HOLD-/);

  const started = await json(`/jobs/${job.id}/start`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${provider.accessToken}` },
  });
  assert.equal(started.status, 200);

  const delivered = await json(`/jobs/${job.id}/deliver`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${provider.accessToken}` },
  });
  assert.equal(delivered.status, 200);

  const accepted = await json(`/jobs/${job.id}/accept`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${owner.accessToken}` },
  });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.data.status, 'COMPLETED');

  const released = await json(`/payments/release/${job.id}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${owner.accessToken}` },
  });
  assert.ok([200, 202].includes(released.status));
  assert.ok(released.body.data?.payment?.status || released.body.payment?.status || released.body.status);

  // The targeted release worker is triggered by the route itself. Poll the
  // payment row so the assertion covers the actual provider -> outbox -> DB
  // transition rather than only the HTTP response.
  let payment = null;
  for (let attempt = 0; attempt < 20; attempt += 1) {
    payment = await findPaymentByJob(job.id);
    if (payment?.status === 'RELEASED') break;
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  assert.equal(payment?.status, 'RELEASED');
  const { rows: settlementRows } = await requirePool().query(
    `SELECT provider_ref, status FROM settlements WHERE payment_id=$1`,
    [payment.id],
  );
  assert.equal(settlementRows.length, 1);
  assert.equal(settlementRows[0].status, 'RELEASED');
  assert.match(settlementRows[0].provider_ref, /^MOCK-RELEASE-/);
  const settledJob = await json(`/jobs/${job.id}`, {
    method: 'GET',
    headers: { Authorization: `Bearer ${owner.accessToken}` },
  });
  assert.equal(settledJob.status, 200);
  assert.equal(settledJob.body.data.status, 'SETTLED');
});

test('payment webhook callback is applied atomically in PostgreSQL', { skip: !enabled }, async () => {
  const owner = await register('webhook-callback-owner');
  const provider = await register('webhook-callback-provider');
  const job = await createFundableMission(owner, provider);

  const funded = await json(`/payments/fund/${job.id}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${owner.accessToken}`,
      'Idempotency-Key': `webhook-callback-fund-${job.id}`,
    },
    body: '{}',
  });
  assert.ok([201, 202].includes(funded.status));
  const held = await drainUntilPaymentStatus(job.id, 'HELD', processPaymentCreateHoldNow);

  const started = await json(`/jobs/${job.id}/start`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${provider.accessToken}` },
  });
  assert.equal(started.status, 200);
  const delivered = await json(`/jobs/${job.id}/deliver`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${provider.accessToken}` },
  });
  assert.equal(delivered.status, 200);
  const accepted = await json(`/jobs/${job.id}/accept`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${owner.accessToken}` },
  });
  assert.equal(accepted.status, 200);
  assert.equal(accepted.body.data.status, 'COMPLETED');

  const paymentBeforeWebhook = await findPaymentByJob(job.id);
  assert.equal(paymentBeforeWebhook.status, 'RELEASE_PENDING');
  assert.equal(paymentBeforeWebhook.provider_ref || paymentBeforeWebhook.providerRef, held.provider_ref || held.providerRef);

  const queued = await enqueuePaymentRelease({
    jobId: job.id,
    ownerId: owner.user?.id || owner.id,
    paymentId: paymentBeforeWebhook.id,
    dedupeKey: `PAYMENT_RELEASE:WEBHOOK_CALLBACK:${paymentBeforeWebhook.id}`,
  });
  assert.ok(queued?.id);

  const eventId = crypto.randomUUID();
  const timestamp = Math.floor(Date.now() / 1000);
  const body = JSON.stringify({
    eventId,
    eventType: 'PAYMENT_RELEASED',
    paymentId: paymentBeforeWebhook.id,
    providerRef: String(paymentBeforeWebhook.provider_ref || paymentBeforeWebhook.providerRef),
  });
  const signature = signTimestampedPayload(Buffer.from(body), process.env.PAYMENT_WEBHOOK_SECRET, timestamp, eventId);

  const callback = await json('/payments/webhook', {
    method: 'POST',
    headers: {
      'x-hope-signature': signature,
      'x-hope-timestamp': String(timestamp),
      'x-hope-event-id': eventId,
    },
    body,
  });
  assert.equal(callback.status, 200);
  assert.equal(callback.body.data.processed, true);
  assert.equal(callback.body.data.duplicate, false);

  const paymentAfterWebhook = await findPaymentByJob(job.id);
  assert.equal(paymentAfterWebhook.status, 'RELEASED');
  const settledJob = await json(`/jobs/${job.id}`, {
    headers: { Authorization: `Bearer ${owner.accessToken}` },
  });
  assert.equal(settledJob.status, 200);
  assert.equal(settledJob.body.data.status, 'SETTLED');

  const duplicate = await json('/payments/webhook', {
    method: 'POST',
    headers: {
      'x-hope-signature': signature,
      'x-hope-timestamp': String(timestamp),
      'x-hope-event-id': eventId,
    },
    body,
  });
  assert.equal(duplicate.status, 200);
  assert.equal(duplicate.body.data.processed, true);
  assert.equal(duplicate.body.data.duplicate, true);
});
after(async () => {
  if (appServer) await new Promise((resolve) => appServer.close(resolve));
  if (mockServer) await new Promise((resolve) => mockServer.close(resolve));
});
