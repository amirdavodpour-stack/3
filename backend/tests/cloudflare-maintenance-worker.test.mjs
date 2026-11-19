import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { triggerMaintenance } from '../cloudflare-maintenance/worker.mjs';

const secret = 'staging-maintenance-secret-with-at-least-32-bytes';
const requestId = '0e9bb0b7-f22a-4c13-9ba5-649c6900a0bb';
const endpoint = 'https://hope-preview-abc123.vercel.app/api/v1/internal/maintenance';

test('Cloudflare scheduler sends a timestamped HMAC request to the Preview endpoint', async () => {
  let captured;
  const result = await triggerMaintenance({ HOPE_MAINTENANCE_URL: endpoint, HOPE_MAINTENANCE_HMAC_SECRET: secret }, {
    now: () => 1795050000000,
    newRequestId: () => requestId,
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return { ok: true, status: 200 };
    },
  });
  const timestamp = '1795050000';
  const expected = crypto.createHmac('sha256', secret)
    .update(`${timestamp}.${requestId}.POST./api/v1/internal/maintenance`)
    .digest('hex');
  assert.equal(captured.url, endpoint);
  assert.equal(captured.options.method, 'POST');
  assert.equal(captured.options.redirect, 'manual');
  assert.equal(captured.options.headers['x-hope-timestamp'], timestamp);
  assert.equal(captured.options.headers['x-hope-request-id'], requestId);
  assert.equal(captured.options.headers['x-hope-signature'], expected);
  assert.deepEqual(result, { ok: true, status: 200, requestId });
});

test('Cloudflare scheduler refuses non-HTTPS, non-Vercel, path, query, and credential-bearing URLs', async () => {
  const invalid = [
    'http://hope-preview-abc123.vercel.app/api/v1/internal/maintenance',
    'https://api.example.com/api/v1/internal/maintenance',
    'https://hope-preview-abc123.vercel.app/internal/maintenance',
    'https://hope-preview-abc123.vercel.app/api/v1/internal/maintenance?token=x',
    'https://user:pass@hope-preview-abc123.vercel.app/api/v1/internal/maintenance',
  ];
  for (const HOPE_MAINTENANCE_URL of invalid) {
    await assert.rejects(() => triggerMaintenance({ HOPE_MAINTENANCE_URL, HOPE_MAINTENANCE_HMAC_SECRET: secret }), /MAINTENANCE_ENDPOINT_INVALID/);
  }
});

test('Cloudflare scheduler rejects missing secret, non-UUID request id, and non-success responses', async () => {
  await assert.rejects(() => triggerMaintenance({ HOPE_MAINTENANCE_URL: endpoint, HOPE_MAINTENANCE_HMAC_SECRET: 'short' }), /MAINTENANCE_SECRET_INVALID/);
  await assert.rejects(() => triggerMaintenance({ HOPE_MAINTENANCE_URL: endpoint, HOPE_MAINTENANCE_HMAC_SECRET: secret }, { newRequestId: () => 'bad-id' }), /MAINTENANCE_REQUEST_ID_INVALID/);
  await assert.rejects(() => triggerMaintenance({ HOPE_MAINTENANCE_URL: endpoint, HOPE_MAINTENANCE_HMAC_SECRET: secret }, { fetchImpl: async () => ({ ok: false, status: 503 }) }), /MAINTENANCE_HTTP_503/);
});
