import test from 'node:test';
import assert from 'node:assert/strict';
import { createAiRoutes } from '../src/routes/ai_routes.js';

test('POST /chat requires authentication and returns the AI answer', async () => {
  let authenticated = false;
  let sent;
  const routes = createAiRoutes({
    authUser: async () => { authenticated = true; return { id: 'user-1' }; },
    readBody: async () => ({ message: 'hello' }),
    sendJson: async (_res, status, data) => { sent = { status, data }; },
    HttpError: class HttpError extends Error { constructor(status, code, message) { super(message); this.status = status; this.code = code; } },
    askAI: async (message) => 'answer:' + message,
  });
  await routes({ method: 'POST' }, {}, ['chat']);
  assert.equal(authenticated, true);
  assert.deepEqual(sent, { status: 200, data: { answer: 'answer:hello' } });
});

test('POST /chat rejects an empty message', async () => {
  const HttpError = class HttpError extends Error { constructor(status, code, message) { super(message); this.status = status; this.code = code; } };
  const routes = createAiRoutes({ authUser: async () => ({}), readBody: async () => ({ message: '   ' }), sendJson: async () => {}, HttpError, askAI: async () => 'must not run' });
  await assert.rejects(() => routes({ method: 'POST' }, {}, ['chat']), (error) => error.code === 'INVALID_MESSAGE' && error.status === 400);
});

test('POST /chat rejects an oversized message', async () => {
  const HttpError = class HttpError extends Error { constructor(status, code, message) { super(message); this.status = status; this.code = code; } };
  const routes = createAiRoutes({ authUser: async () => ({}), readBody: async () => ({ message: 'x'.repeat(12001) }), sendJson: async () => {}, HttpError, askAI: async () => 'must not run' });
  await assert.rejects(() => routes({ method: 'POST' }, {}, ['chat']), (error) => error.code === 'MESSAGE_TOO_LONG' && error.status === 400);
});
