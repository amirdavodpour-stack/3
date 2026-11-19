import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { createRateLimiter } from '../src/rate_limit.js';

function request({ remoteAddress = '10.0.0.8', headers = {} } = {}) {
  return { socket: { remoteAddress }, headers };
}

function makePool() {
  const queries = [];
  return {
    queries,
    pool: {
      async query(query) {
        queries.push(query);
        return { rows: [{ request_count: 1 }] };
      },
    },
  };
}

test('Render rate limiting uses the Cloudflare-assigned client IP instead of the shared Render proxy address', async () => {
  const fake = makePool();
  const limiter = createRateLimiter({ pool: fake.pool, trustProxy: true, trustedProxyHeader: 'cf-connecting-ip' });
  await limiter.general(request({ headers: { 'cf-connecting-ip': '203.0.113.7', 'cf-ray': '6a2b4d3c8e7f4a1b-IAD', 'x-forwarded-for': '198.51.100.99' } }), 10, 60000);
  const expected = crypto.createHash('sha256').update('general:203.0.113.7').digest('hex');
  assert.equal(fake.queries[0].values[0], expected);
});

test('Render rate limiting ignores spoofed forwarding headers and falls back to the peer when CF-Connecting-IP is invalid', async () => {
  const fake = makePool();
  const limiter = createRateLimiter({ pool: fake.pool, trustProxy: true, trustedProxyHeader: 'cf-connecting-ip' });
  await limiter.general(request({ headers: { 'cf-connecting-ip': 'not-an-ip', 'cf-ray': '6a2b4d3c8e7f4a1b-IAD', 'x-forwarded-for': '203.0.113.44' } }), 10, 60000);
  const expected = crypto.createHash('sha256').update('general:10.0.0.8').digest('hex');
  assert.equal(fake.queries[0].values[0], expected);
});


test('Render rate limiting ignores a client-supplied CF-Connecting-IP without a Cloudflare Ray ID', async () => {
  const fake = makePool();
  const limiter = createRateLimiter({ pool: fake.pool, trustProxy: true, trustedProxyHeader: 'cf-connecting-ip' });
  await limiter.general(request({ headers: { 'cf-connecting-ip': '203.0.113.7', 'x-forwarded-for': '198.51.100.22' } }), 10, 60000);
  const expected = crypto.createHash('sha256').update('general:10.0.0.8').digest('hex');
  assert.equal(fake.queries[0].values[0], expected);
});
