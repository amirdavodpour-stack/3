import test from 'node:test';
import assert from 'node:assert/strict';
import { createAiService, resolveAiEndpoint } from '../src/services/ai.js';

test('AI router base URL resolves to chat completions endpoint', () => {
  assert.equal(resolveAiEndpoint('http://localhost:20128/v1'), 'http://localhost:20128/v1/chat/completions');
  assert.equal(resolveAiEndpoint('http://localhost:20128/v1/'), 'http://localhost:20128/v1/chat/completions');
  assert.equal(resolveAiEndpoint('http://localhost:20128/v1/chat/completions'), 'http://localhost:20128/v1/chat/completions');
});

test('AI service sends configured model and server-side credential', async () => {
  const env = {
    AI_ROUTER_URL: 'http://localhost:20128/v1',
    AI_ROUTER_API_KEY: 'test-secret',
    AI_MODEL: 'apmix/deepseek-v4-flash-free',
    AI_TIMEOUT_MS: '30000',
  };
  let captured;
  const ask = createAiService({
    env,
    fetchImpl: async (url, options) => {
      captured = { url, options, body: JSON.parse(options.body) };
      return new Response(JSON.stringify({ choices: [{ message: { content: 'سلام' } }] }), { status: 200 });
    },
  });
  assert.equal(await ask('hello'), 'سلام');
  assert.equal(captured.url, 'http://localhost:20128/v1/chat/completions');
  assert.equal(captured.options.headers.Authorization, 'Bearer test-secret');
  assert.equal(captured.body.model, 'apmix/deepseek-v4-flash-free');
  assert.deepEqual(captured.body.messages, [{ role: 'user', content: 'hello' }]);
});

test('AI service fails closed when credential is missing', async () => {
  const ask = createAiService({ env: { AI_ROUTER_API_KEY: '' }, fetchImpl: async () => { throw new Error('network must not be called'); } });
  await assert.rejects(() => ask('hello'), (error) => error.code === 'AI_NOT_CONFIGURED' && error.status === 503);
});

test('AI service maps provider network failures to a sanitized gateway error', async () => {
  const ask = createAiService({ env: { AI_ROUTER_API_KEY: 'test-secret' }, fetchImpl: async () => { throw new Error('secret upstream detail'); } });
  await assert.rejects(() => ask('hello'), (error) => error.code === 'AI_PROVIDER_UNAVAILABLE' && error.status === 502 && error.message === 'AI provider is unavailable');
});
