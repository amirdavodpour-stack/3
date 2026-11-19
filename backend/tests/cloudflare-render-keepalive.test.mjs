import test from 'node:test';
import assert from 'node:assert/strict';
import { pingRenderStaging } from '../cloudflare-render-keepalive/worker.mjs';

const url = 'https://hopev2-staging.onrender.com/live';

test('Cloudflare keepalive performs a bounded HTTPS GET only against the Render staging liveness endpoint', async () => {
  let request;
  const result = await pingRenderStaging({
    healthUrl: url,
    fetchImpl: async (target, options) => {
      request = { target, options };
      return { status: 200, ok: true, body: { cancel() {} } };
    },
  });
  assert.deepEqual(result, { ok: true, status: 200 });
  assert.equal(request.target, url);
  assert.equal(request.options.method, 'GET');
  assert.equal(request.options.redirect, 'manual');
  assert.ok(request.options.signal instanceof AbortSignal);
});

test('Cloudflare keepalive rejects non-Render, non-HTTPS, path/query, and credential-bearing targets', async () => {
  for (const healthUrl of [
    'http://hopev2-staging.onrender.com/live',
    'https://example.com/live',
    'https://hopev2-staging.onrender.com/other',
    'https://hopev2-staging.onrender.com/live?token=secret',
    'https://user:password@hopev2-staging.onrender.com/live',
  ]) {
    await assert.rejects(() => pingRenderStaging({ healthUrl, fetchImpl: async () => { throw new Error('must not fetch'); } }), /RENDER_HEALTH_URL_INVALID/);
  }
});

test('Cloudflare keepalive refuses redirects and unsuccessful liveness responses', async () => {
  for (const status of [301, 302, 404, 503]) {
    await assert.rejects(
      () => pingRenderStaging({ healthUrl: url, fetchImpl: async () => ({ status, ok: false, body: { cancel() {} } }) }),
      /RENDER_HEALTH_CHECK_FAILED/,
    );
  }
});
