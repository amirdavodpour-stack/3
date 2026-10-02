import assert from 'node:assert/strict';
import test from 'node:test';
import { createAiService } from '../src/services/ai.js';

test('AI service sends OpenAI-compatible chat completion payload without hard-coded credentials', async () => {
  let request;
  const service = createAiService({
    env: {
      AI_ROUTER_URL: 'http://127.0.0.1:20128/v1/chat/completions',
      AI_ROUTER_API_KEY: 'test-secret',
      AI_MODEL: 'apmix/deepseek-v4-flash-free',
      AI_TIMEOUT_MS: '1000',
    },
    fetchImpl: async (url, options) => {
      request = { url, options };
      return new Response(JSON.stringify({
        choices: [{ message: { content: 'hello from test' } }],
      }), { status: 200, headers: { 'content-type': 'application/json' } });
    },
  });

  const answer = await service.askAI('hello');

  assert.equal(answer, 'hello from test');
  assert.equal(request.url, 'http://127.0.0.1:20128/v1/chat/completions');
  assert.equal(request.options.headers.Authorization, 'Bearer test-secret');
  assert.deepEqual(JSON.parse(request.options.body), {
    model: 'apmix/deepseek-v4-flash-free',
    messages: [{ role: 'user', content: 'hello' }],
  });
});

test('AI service fails closed when the provider credential is missing', async () => {
  const service = createAiService({
    env: { AI_ROUTER_URL: 'http://127.0.0.1:20128/v1/chat/completions' },
    fetchImpl: async () => {
      throw new Error('network must not be reached');
    },
  });

  await assert.rejects(
    service.askAI('hello'),
    (error) => error.code === 'AI_NOT_CONFIGURED' && error.status === 503,
  );
});

test('AI service maps provider failures to a sanitized gateway error', async () => {
  const service = createAiService({
    env: { AI_ROUTER_API_KEY: 'test-secret' },
    fetchImpl: async () => new Response('upstream failed', { status: 500 }),
  });

  await assert.rejects(
    service.askAI('hello'),
    (error) => error.code === 'AI_PROVIDER_ERROR' && error.status === 502 && error.message === 'AI provider returned an error',
  );
});
