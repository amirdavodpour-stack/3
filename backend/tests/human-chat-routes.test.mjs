import test from 'node:test';
import assert from 'node:assert/strict';
import { createHumanChatRoutes } from '../src/routes/human_chat_routes.js';

class TestHttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

test('attachment download rejects a missing stream before sending HTTP 200 headers', async () => {
  let headersSent = false;
  const route = createHumanChatRoutes({
    authUser: async () => ({ id: 'participant-1', role: 'USER' }),
    sendJson: (_res, _status, body) => body,
    readBody: async () => ({}),
    HttpError: TestHttpError,
    repo: {
      getChatAttachmentForUser: async () => ({
        id: 'attachment-1',
        storageKey: 'private/key',
        filename: 'private.pdf',
        contentType: 'application/pdf',
        size: 128,
      }),
    },
    storage: {
      get: async () => ({ size: 128 }),
    },
  });
  const response = {
    writeHead() {
      headersSent = true;
      return this;
    },
    destroy() {},
  };

  await assert.rejects(
    route({ method: 'GET' }, response, ['messaging', 'attachments', 'attachment-1', 'content']),
    (error) => error.status === 500 && error.code === 'CHAT_ATTACHMENT_STREAM_UNAVAILABLE',
  );
  assert.equal(headersSent, false, 'a failed storage read must not commit HTTP 200 headers first');
});
