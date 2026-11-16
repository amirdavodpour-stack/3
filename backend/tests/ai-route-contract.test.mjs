import test from 'node:test';
import assert from 'node:assert/strict';
import { createAiRoutes } from '../src/routes/ai_routes.js';

const HttpError = class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
};

async function assertUserChatDisabled(body) {
  let authenticated = false;
  let bodyRead = false;
  let calledAi = false;
  const routes = createAiRoutes({
    authUser: async () => { authenticated = true; return {id: 'user-1'}; },
    readBody: async () => { bodyRead = true; return body; },
    sendJson: async () => { throw new Error('disabled user chat must not respond with an answer'); },
    HttpError,
    askAI: async () => { calledAi = true; return 'must not run'; },
  });

  await assert.rejects(
    () => routes({method: 'POST'}, {}, ['chat']),
    (error) => error.code === 'AI_USER_ACCESS_DISABLED' && error.status === 403,
  );
  assert.equal(authenticated, true);
  assert.equal(bodyRead, false, 'user-disabled policy should be checked before body processing');
  assert.equal(calledAi, false, 'disabled general AI must never call the provider');
}

test('POST /chat denies authenticated users because general AI access is disabled', async () => {
  await assertUserChatDisabled({message: 'hello'});
});

test('disabled general AI access takes precedence over empty-message validation', async () => {
  await assertUserChatDisabled({message: '   '});
});

test('disabled general AI access takes precedence over oversized-message validation', async () => {
  await assertUserChatDisabled({message: 'x'.repeat(12001)});
});
