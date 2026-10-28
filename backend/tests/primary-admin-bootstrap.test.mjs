import test from 'node:test';
import assert from 'node:assert/strict';
import { isPrimaryAdminEmail, shouldBootstrapPrimaryAdmin } from '../src/application/admin_panel_access.js';
import { createAuthRoutes } from '../src/routes/auth_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { requireFields, stringField } from '../src/policies/validation.js';

test('the designated primary admin email is recognized case-insensitively', () => {
  assert.equal(isPrimaryAdminEmail('amir.davodpour@gmail.com'), true);
  assert.equal(isPrimaryAdminEmail('AMIR.DAVODPOUR@GMAIL.COM'), true);
  assert.equal(isPrimaryAdminEmail('other@example.com'), false);
});

test('only the designated email bootstraps as ADMIN', () => {
  assert.equal(shouldBootstrapPrimaryAdmin({ email: 'amir.davodpour@gmail.com', verifiedIdentity: true, googleSubject: 'verified-subject' }), true);
  assert.equal(shouldBootstrapPrimaryAdmin({ email: 'amir.davodpour@gmail.com', verifiedIdentity: true }), false);
  assert.equal(shouldBootstrapPrimaryAdmin({ email: 'amir.davodpour@gmail.com', verifiedIdentity: false, googleSubject: 'verified-subject' }), false);
  assert.equal(shouldBootstrapPrimaryAdmin('other@example.com'), false);
});

test('password registration cannot claim the primary-admin email role without a verified identity', async () => {
  const storedUsers = [];
  const saveUser = async (user) => {
    storedUsers.push(user);
    return user;
  };
  const routes = createAuthRoutes({
    authUser: async () => null,
    authUserView: (user) => ({ id: user.id, email: user.email, role: user.role }),
    getUserByEmail: async () => null,
    issueSession: async () => ({ accessToken: 'test-access', refreshToken: 'test-refresh' }),
    deliverPasswordReset: async () => {},
    findUser: async () => null,
    readBody: async () => ({
      email: 'amir.davodpour@gmail.com',
      password: 'test-password-123',
      displayName: 'Unverified claimant',
    }),
    sendJson: async (_res, status, data) => ({ status, data }),
    HttpError,
    requireFields,
    repo: { createUserWithProvider: saveUser },
    config: {},
    now: () => '2026-10-26T00:00:00.000Z',
    hashPassword: async () => 'test-password-hash',
    verifyPassword: async () => true,
    passwordNeedsRehash: () => false,
    PASSWORD_MAX_LENGTH: 128,
    randomToken: () => 'r'.repeat(48),
    sha256: (value) => value,
    signAccessToken: () => 'test-token',
    createAudit: async () => {},
    DUMMY_PASSWORD_HASH: 'dummy',
    logEvent: () => {},
    rateLimitAuthAccount: async () => true,
    stringField,
    id: () => 'test-user-id',
    legacy: { createUserWithProvider: saveUser },
    verifyGoogleIdToken: async () => {},
  });

  const originalDatabaseUrl = process.env.DATABASE_URL;
  process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';
  let response;
  try {
    response = await routes({ method: 'POST' }, {}, ['auth', 'register']);
  } finally {
    if (originalDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDatabaseUrl;
  }

  assert.equal(response.status, 201);
  assert.equal(response.data.user.role, 'USER');
  assert.equal(storedUsers[0].role, 'USER');
});
