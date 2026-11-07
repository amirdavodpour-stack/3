import test from 'node:test';
import assert from 'node:assert/strict';
import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';

function makeRoute({
  identity = {
    subject: 'google-subject-admin-1',
    email: 'ops@example.test',
    issuedAt: Math.floor(Date.now() / 1000),
  },
  body = {
    name: 'Operations Admin',
    username: 'hope-admin',
    idToken: 'fresh-google-id-token',
  },
  user = {
    id: 'admin-1',
    email: 'ops@example.test',
    displayName: 'Operations Admin',
    role: 'ADMIN',
    status: 'ACTIVE',
    googleSubject: 'google-subject-admin-1',
    sessionJti: 'admin-session-jti-1',
    passwordHash: 'unused-password-hash',
  },
  googleAuthEnabled = true,
  googleOAuthClientId = 'hope-google-client',
  verificationError = null,
} = {}) {
  const auditEntries = [];
  const verificationWrites = [];
  const rateLimitCalls = [];
  const routes = createAdminRoutes({
    authUser: async () => user,
    requireAdmin: (value) => value,
    readBody: async () => body,
    sendJson: async (_res, status, data) => ({ status, data }),
    HttpError,
    config: {
      adminPanelUsername: 'hope-admin',
      adminPanelAllowedEmail: 'amir.davodpour@gmail.com',
      adminPanelVerificationMinutes: 15,
      authRateLimitMax: 8,
      rateLimitWindowMs: 60000,
      googleAuthEnabled,
      googleOAuthClientId,
    },
    repo: {
      setAdminPanelVerified: async (...args) => {
        verificationWrites.push(args);
        return { verifiedAt: new Date().toISOString() };
      },
    },
    createAudit: async (...args) => { auditEntries.push(args); },
    verifyPassword: async () => false,
    verifyGoogleIdToken: async (token, audience) => {
      assert.equal(token, 'fresh-google-id-token');
      assert.equal(audience, googleOAuthClientId);
      if (verificationError) throw verificationError;
      return identity;
    },
    rateLimitAuth: async (...args) => {
      rateLimitCalls.push(['ip', ...args]);
      return true;
    },
    rateLimitAuthAccount: async (...args) => {
      rateLimitCalls.push(['account', ...args]);
      return true;
    },
    DUMMY_PASSWORD_HASH: 'dummy-password-hash',
    PASSWORD_MAX_LENGTH: 128,
  });
  return { routes, auditEntries, verificationWrites, rateLimitCalls };
}

async function withPostgresEnvironment(callback) {
  const previous = process.env.DATABASE_URL;
  process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';
  try {
    return await callback();
  } finally {
    if (previous === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = previous;
  }
}

const invokeUnlock = (routes) => routes(
  { method: 'POST', headers: { 'x-forwarded-for': '127.0.0.1' } },
  {},
  ['admin', 'access'],
);

test('Google reauthentication unlocks the admin panel only for the same recent provider identity and current session', async () => {
  const { routes, auditEntries, verificationWrites, rateLimitCalls } = makeRoute();
  const result = await withPostgresEnvironment(() => invokeUnlock(routes));

  assert.equal(result.status, 200);
  assert.equal(result.data.verified, true);
  assert.deepEqual(verificationWrites, [['admin-1', 'admin-session-jti-1', 'WRITE', { expiresInMinutes:5, method:'google', mfaMethod:'not_required' }]]);
  assert.equal(auditEntries.length, 0, 'PostgreSQL unlock audit must be written atomically by the repository, not as a second route operation');
  assert.equal(rateLimitCalls.length, 2);
  assert.equal(rateLimitCalls[1][1], 'admin-panel:admin-1');
});

for (const [label, identity] of [
  ['a different Google subject', {
    subject: 'another-google-subject',
    email: 'ops@example.test',
    issuedAt: Math.floor(Date.now() / 1000),
  }],
  ['a different verified email', {
    subject: 'google-subject-admin-1',
    email: 'other@example.test',
    issuedAt: Math.floor(Date.now() / 1000),
  }],
  ['an expired provider token', {
    subject: 'google-subject-admin-1',
    email: 'ops@example.test',
    issuedAt: Math.floor(Date.now() / 1000) - 301,
  }],
  ['a token issued too far in the future', {
    subject: 'google-subject-admin-1',
    email: 'ops@example.test',
    issuedAt: Math.floor(Date.now() / 1000) + 31,
  }],
]) {
  test(`Google reauthentication fails closed for ${label}`, async () => {
    const { routes, auditEntries, verificationWrites } = makeRoute({ identity });
    await assert.rejects(
      invokeUnlock(routes),
      (error) => error?.status === 401 && error?.code === 'ADMIN_REAUTH_FAILED',
    );
    assert.deepEqual(verificationWrites, []);
    assert.deepEqual(auditEntries, []);
  });
}

test('Google reauthentication fails closed when the provider rejects the ID token', async () => {
  const { routes, auditEntries, verificationWrites } = makeRoute({
    verificationError: new Error('invalid provider token'),
  });
  await assert.rejects(
    invokeUnlock(routes),
    (error) => error?.status === 401 && error?.code === 'ADMIN_REAUTH_FAILED',
  );
  assert.deepEqual(verificationWrites, []);
  assert.deepEqual(auditEntries, []);
});

test('Google reauthentication is unavailable without configured Google auth or a linked subject', async () => {
  const unlinked = {
    id: 'admin-2',
    email: 'ops@example.test',
    displayName: 'Operations Admin',
    role: 'ADMIN',
    status: 'ACTIVE',
    googleSubject: null,
    sessionJti: 'admin-session-jti-2',
  };
  const { routes, auditEntries, verificationWrites } = makeRoute({ user: unlinked });
  await assert.rejects(
    invokeUnlock(routes),
    (error) => error?.status === 401 && error?.code === 'ADMIN_REAUTH_FAILED',
  );
  assert.deepEqual(verificationWrites, []);
  assert.deepEqual(auditEntries, []);
});
