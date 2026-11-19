import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { verifyMaintenanceSignature } from '../src/maintenance_auth.js';
import { runBoundedBatch } from '../src/bounded_batch.js';

const secret = 'staging-maintenance-secret-with-at-least-32-bytes';
const path = '/api/v1/internal/maintenance';
const requestId = '0e9bb0b7-f22a-4c13-9ba5-649c6900a0bb';

function signatureFor({ secretValue = secret, timestamp = '1795050000', id = requestId, method = 'POST', pathname = path } = {}) {
  return crypto.createHmac('sha256', secretValue)
    .update(`${timestamp}.${id}.${method}.${pathname}`, 'utf8')
    .digest('hex');
}

test('maintenance HMAC accepts a current POST with a canonical path and UUID request id', () => {
  const timestamp = '1795050000';
  const result = verifyMaintenanceSignature({
    method: 'POST', pathname: path, timestamp, requestId,
    signature: signatureFor({ timestamp }), secret, nowSeconds: 1795050000,
  });
  assert.deepEqual(result, { valid: true, requestId });
});

test('maintenance HMAC rejects stale, future, wrong-method, and wrong-path requests', () => {
  const timestamp = '1795050000';
  const signature = signatureFor({ timestamp });
  assert.equal(verifyMaintenanceSignature({ method: 'POST', pathname: path, timestamp, requestId, signature, secret, nowSeconds: 1795050601 }).valid, false);
  assert.equal(verifyMaintenanceSignature({ method: 'POST', pathname: path, timestamp, requestId, signature, secret, nowSeconds: 1795049399 }).valid, false);
  assert.equal(verifyMaintenanceSignature({ method: 'GET', pathname: path, timestamp, requestId, signature, secret, nowSeconds: 1795050000 }).valid, false);
  assert.equal(verifyMaintenanceSignature({ method: 'POST', pathname: '/internal/other', timestamp, requestId, signature, secret, nowSeconds: 1795050000 }).valid, false);
});

test('maintenance HMAC rejects tampered signatures, malformed request ids, and short secrets', () => {
  const timestamp = '1795050000';
  const signature = signatureFor({ timestamp });
  assert.equal(verifyMaintenanceSignature({ method: 'POST', pathname: path, timestamp, requestId, signature: `${signature.slice(0, 63)}${signature.endsWith('0') ? '1' : '0'}`, secret, nowSeconds: 1795050000 }).valid, false);
  assert.equal(verifyMaintenanceSignature({ method: 'POST', pathname: path, timestamp, requestId: 'not-a-uuid', signature, secret, nowSeconds: 1795050000 }).valid, false);
  assert.equal(verifyMaintenanceSignature({ method: 'POST', pathname: path, timestamp, requestId, signature, secret: 'short', nowSeconds: 1795050000 }).valid, false);
});

test('bounded maintenance batch never claims more than maxItems', async () => {
  const queue = [1, 2, 3, 4];
  const processed = [];
  const result = await runBoundedBatch({
    maxItems: 2,
    maxDurationMs: 1000,
    claim: async () => queue.shift() ?? null,
    process: async (item) => { processed.push(item); return { processed: true }; },
    clock: () => 0,
  });
  assert.equal(result.claimed, 2);
  assert.equal(result.processed, 2);
  assert.deepEqual(processed, [1, 2]);
  assert.equal(queue.length, 2);
  assert.equal(result.limitReached, true);
});

test('bounded maintenance batch stops when no work is available', async () => {
  let claims = 0;
  const result = await runBoundedBatch({
    maxItems: 5,
    maxDurationMs: 1000,
    claim: async () => { claims += 1; return null; },
    process: async () => ({ processed: true }),
    clock: () => 0,
  });
  assert.equal(claims, 1);
  assert.equal(result.claimed, 0);
  assert.equal(result.empty, true);
  assert.equal(result.limitReached, false);
});

test('bounded maintenance batch checks elapsed time before claiming another item', async () => {
  let now = 0;
  let claims = 0;
  const result = await runBoundedBatch({
    maxItems: 10,
    maxDurationMs: 50,
    claim: async () => { claims += 1; now += 1; return claims; },
    process: async () => { now += 60; return { processed: true }; },
    clock: () => now,
  });
  assert.equal(claims, 1);
  assert.equal(result.claimed, 1);
  assert.equal(result.processed, 1);
  assert.equal(result.limitReached, true);
});

test('bounded maintenance batch validates its limits and dependencies', async () => {
  await assert.rejects(() => runBoundedBatch({ maxItems: 0, maxDurationMs: 1000, claim: async () => null, process: async () => ({}) }), /maxItems/);
  await assert.rejects(() => runBoundedBatch({ maxItems: 1, maxDurationMs: 0, claim: async () => null, process: async () => ({}) }), /maxDurationMs/);
});


test('serverless maintenance passes a short explicit timeout through expired-object cleanup', () => {
  const service = fs.readFileSync(new URL('../src/maintenance_service.js', import.meta.url), 'utf8');
  const cleanup = fs.readFileSync(new URL('../src/storage_cleanup_worker.js', import.meta.url), 'utf8');
  const storage = fs.readFileSync(new URL('../src/storage.js', import.meta.url), 'utf8');
  assert.match(service, /deleteTimeoutMs:\s*config\.maintenanceStorageRequestTimeoutMs/);
  assert.match(cleanup, /storageBackend\.delete\(\{\s*key:\s*intent\.storageKey,\s*timeoutMs:\s*deleteTimeoutMs\s*\}\)/);
  assert.match(storage, /async delete\(\{ key, timeoutMs = 10000 \}\)/);
  assert.match(storage, /AbortSignal\.timeout\(timeoutMs\)/);
});
