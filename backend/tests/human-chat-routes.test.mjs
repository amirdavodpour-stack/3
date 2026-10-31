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

async function withDatabaseUrl(value, callback) {
  const previous = process.env.DATABASE_URL;
  if (value == null) delete process.env.DATABASE_URL;
  else process.env.DATABASE_URL = value;
  try { return await callback(); }
  finally {
    if (previous === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = previous;
  }
}

test('unlinked primary ADMIN cannot enumerate private admin-room conversations', async () => {
  await withDatabaseUrl(null, async () => {
    let listed = false;
    const route = createHumanChatRoutes({
      authUser: async () => ({
        id: 'unlinked-primary',
        email: 'amir.davodpour@gmail.com',
        displayName: 'Unlinked primary',
        role: 'ADMIN',
        googleSubject: null,
      }),
      sendJson: (_res, status, data) => ({ status, data }),
      readBody: async () => ({}),
      HttpError: TestHttpError,
      config: { adminPanelVerificationMinutes: 15 },
      repo: {
        listChatConversations: async () => { listed = true; return [{ id: 'private-admin-room' }]; },
      },
      storage: {},
    });
    await assert.rejects(
      route({ method: 'GET' }, {}, ['messaging', 'conversations']),
      (error) => error.status === 403 && error.code === 'PRIMARY_ADMIN_IDENTITY_REQUIRED',
    );
    assert.equal(listed, false, 'the repository must not be queried before the primary identity guard');
  });
});

test('admin-room access requires the existing PostgreSQL panel step-up gate', async () => {
  await withDatabaseUrl('postgresql://unit-test.invalid/hope', async () => {
    let listed = false;
    const route = createHumanChatRoutes({
      authUser: async () => ({ id: 'ops-admin', email: 'ops@example.com', displayName: 'Ops', role: 'ADMIN' }),
      sendJson: (_res, status, data) => ({ status, data }),
      readBody: async () => ({}),
      HttpError: TestHttpError,
      config: { adminPanelVerificationMinutes: 15 },
      repo: {
        isAdminPanelVerified: async () => false,
        listChatConversations: async () => { listed = true; return [{ id: 'private-admin-room' }]; },
      },
      storage: {},
    });
    await assert.rejects(
      route({ method: 'GET' }, {}, ['messaging', 'conversations']),
      (error) => error.status === 403 && error.code === 'ADMIN_PANEL_LOCKED',
    );
    assert.equal(listed, false, 'the repository must not be queried while panel step-up is locked');
  });
});

test('verified operational admin can enumerate admin conversations after step-up', async () => {
  await withDatabaseUrl('postgresql://unit-test.invalid/hope', async () => {
    const route = createHumanChatRoutes({
      authUser: async () => ({ id: 'ops-admin', email: 'ops@example.com', displayName: 'Ops', role: 'ADMIN' }),
      sendJson: (_res, status, data) => ({ status, data }),
      readBody: async () => ({}),
      HttpError: TestHttpError,
      config: { adminPanelVerificationMinutes: 15 },
      repo: {
        isAdminPanelVerified: async () => true,
        listChatConversations: async () => [{ id: 'private-admin-room' }],
      },
      storage: {},
    });
    const response = await route({ method: 'GET' }, {}, ['messaging', 'conversations']);
    assert.equal(response.status, 200);
    assert.deepEqual(response.data.items, [{ id: 'private-admin-room' }]);
  });
});
