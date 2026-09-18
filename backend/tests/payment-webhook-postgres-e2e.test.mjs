import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { createMockPaymentServer } from '../../tools/staging-payment-provider/server.mjs';

const enabled = Boolean(process.env.DATABASE_URL);
let mockServer;
let appServer;

if (enabled) {
  mockServer = createMockPaymentServer({
    token: 'postgres-e2e-mock-provider-token-32-chars',
  });
  await new Promise((resolve) => mockServer.listen(0, '127.0.0.1', resolve));
  const port = mockServer.address().port;

  process.env.NODE_ENV = 'test';
  process.env.PAYMENT_PROVIDER = 'webhook';
  process.env.PAYMENT_CURRENCY = 'TOMAN';
  process.env.PAYMENT_PROVIDER_TOKEN = 'postgres-e2e-mock-provider-token-32-chars';
  process.env.PAYMENT_PROVIDER_CREATE_URL = `http://127.0.0.1:${port}/create`;
  process.env.PAYMENT_PROVIDER_RELEASE_URL = `http://127.0.0.1:${port}/release`;
  process.env.PAYMENT_PROVIDER_REFUND_URL = `http://127.0.0.1:${port}/refund`;
  process.env.PAYMENT_PROVIDER_MAX_ATTEMPTS = '1';
  process.env.PAYMENT_PROVIDER_RETRY_BASE_MS = '0';
  process.env.AUTH_RATE_LIMIT_MAX = '1000';
  process.env.GENERAL_RATE_LIMIT_MAX = '5000';

  const { createServer } = await import('../src/app.js');
  appServer = createServer();
  await new Promise((resolve) => appServer.listen(0, '127.0.0.1', resolve));
}

const base = enabled ? `http://127.0.0.1:${appServer.address().port}/api/v1` : '';
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

  assert.equal(funded.status, 201);
  assert.equal(funded.body.data.status, 'HELD');
  assert.equal(funded.body.data.currency, 'TOMAN');
  assert.match(funded.body.data.providerRef, /^MOCK-HOLD-/);
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
  assert.equal(funded.status, 201);
  assert.equal(funded.body.data.status, 'HELD');

  const refunded = await json(`/payments/refund/${job.id}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${owner.accessToken}`,
      'Idempotency-Key': `webhook-refund-${job.id}`,
    },
    body: '{}',
  });

  assert.equal(refunded.status, 200);
  assert.equal(refunded.body.data.status, 'REFUNDED');
  assert.ok(refunded.body.refund);
});

after(async () => {
  if (appServer) await new Promise((resolve) => appServer.close(resolve));
  if (mockServer) await new Promise((resolve) => mockServer.close(resolve));
});
