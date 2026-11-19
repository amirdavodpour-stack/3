import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import hopeApiHandler from '../api/[...path].js';

const adapterSource = fs.readFileSync(new URL('../api/[...path].js', import.meta.url), 'utf8');
const vercelConfig = JSON.parse(fs.readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'));

test('Vercel Node entrypoint delegates the existing HTTP handler without starting a server process', async () => {
  const headers = new Map();
  const response = {
    statusCode: 200,
    body: '',
    setHeader(name, value) { headers.set(String(name).toLowerCase(), value); },
    getHeader(name) { return headers.get(String(name).toLowerCase()); },
    writeHead(statusCode, values = {}) {
      this.statusCode = statusCode;
      for (const [name, value] of Object.entries(values)) this.setHeader(name, value);
      return this;
    },
    end(body = '') { this.body = String(body); this.writableEnded = true; return this; },
  };
  const request = {
    method: 'GET',
    url: '/api/v1/live',
    headers: { host: 'localhost' },
  };

  await hopeApiHandler(request, response);

  assert.equal(response.statusCode, 200);
  assert.equal(response.writableEnded, true);
  assert.equal(headers.get('content-type'), 'application/json; charset=utf-8');
  assert.equal(JSON.parse(response.body).data.service, 'hope-api');
  assert.equal(JSON.parse(response.body).data.alive, true);
});


test('Vercel entrypoint imports the request handler, never the long-lived server bootstrap', () => {
  assert.match(adapterSource, /from ['"]\.\.\/src\/app\.js['"]/);
  assert.doesNotMatch(adapterSource, /server\.js|startOutboxWorker|startReconciliationWorker|startStorageCleanupWorker/);
  assert.equal(vercelConfig.functions['api/[...path].js'].maxDuration, 30);
  assert.equal(vercelConfig.functions['api/[...path].js'].includeFiles, 'src/db/migrations/**/*.js');
});


test('maintenance route rejects an invalid signature before starting any maintenance work', async () => {
  const { handle } = await import('../src/app.js');
  const previousVercelEnv = process.env.VERCEL_ENV;
  const previousStagingMode = process.env.HOPE_STAGING_MODE;
  process.env.VERCEL_ENV = 'preview';
  process.env.HOPE_STAGING_MODE = 'true';
  const headers = new Map();
  const response = {
    statusCode: 200,
    body: '',
    setHeader(name, value) { headers.set(String(name).toLowerCase(), value); },
    getHeader(name) { return headers.get(String(name).toLowerCase()); },
    writeHead(statusCode, values = {}) {
      this.statusCode = statusCode;
      for (const [name, value] of Object.entries(values)) this.setHeader(name, value);
      return this;
    },
    end(body = '') { this.body = String(body); this.writableEnded = true; return this; },
  };
  try {
    await handle({ method: 'POST', url: '/api/v1/internal/maintenance', headers: {
      host: 'localhost',
      'x-hope-timestamp': String(Math.floor(Date.now() / 1000)),
      'x-hope-request-id': '0e9bb0b7-f22a-4c13-9ba5-649c6900a0bb',
      'x-hope-signature': '0'.repeat(64),
    } }, response);
    assert.equal(response.statusCode, 401);
    assert.equal(JSON.parse(response.body).error.code, 'UNAUTHORIZED');
  } finally {
    if (previousVercelEnv === undefined) delete process.env.VERCEL_ENV; else process.env.VERCEL_ENV = previousVercelEnv;
    if (previousStagingMode === undefined) delete process.env.HOPE_STAGING_MODE; else process.env.HOPE_STAGING_MODE = previousStagingMode;
  }
});


test('Vercel exposes the existing health aliases through the API catch-all', () => {
  assert.ok(vercelConfig.rewrites.some((rewrite) => rewrite.source === '/live' && rewrite.destination === '/api/v1/live'));
  assert.ok(vercelConfig.rewrites.some((rewrite) => rewrite.source === '/health' && rewrite.destination === '/api/v1/health'));
  assert.match(adapterSource, /from ['"]\.\.\/src\/app\.js['"]/);
});
