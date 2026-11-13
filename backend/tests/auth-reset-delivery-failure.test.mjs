import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { createAuthRoutes } from '../src/routes/auth_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { requireFields, stringField } from '../src/policies/validation.js';

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

test('PostgreSQL reset delivery failure invalidates the exact token even after an ambiguous provider timeout', async () => {
  const originalDatabaseUrl = process.env.DATABASE_URL;
  process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';

  const user = {
    id: 'reset-delivery-user',
    email: 'reset-delivery@example.test',
    role: 'USER',
    status: 'ACTIVE',
  };
  let persisted = null;
  let deliveredToken = null;
  let invalidatedHash = null;

  const routes = createAuthRoutes({
    authUser: async () => null,
    authUserView: (value) => ({ id: value.id, email: value.email }),
    getUserByEmail: async (email) => email === user.email ? user : null,
    issueSession: async () => ({ accessToken: 'unused', refreshToken: 'unused' }),
    deliverPasswordReset: async ({ token }) => {
      deliveredToken = token;
      // Simulate a provider that accepted the payload, then timed out before
      // returning a success acknowledgement to the HOPE backend.
      throw new Error('provider acknowledgement timeout after acceptance');
    },
    deliverEmailVerification: async () => {},
    findUser: async () => null,
    readBody: async () => ({ email: user.email }),
    sendJson: async (_res, status, data) => ({ status, data }),
    HttpError,
    requireFields,
    repo: {
      insertResetToken: async (token) => { persisted = token; return token; },
      invalidateResetToken: async (tokenHash) => {
        invalidatedHash = tokenHash;
        return true;
      },
    },
    config: {
      resetTokenTtlSeconds: 3600,
      authRateLimitMax: 10,
      rateLimitWindowMs: 60_000,
      exposeResetTokenInDevelopment: false,
    },
    now: () => new Date().toISOString(),
    randomToken: () => crypto.randomBytes(32).toString('hex'),
    sha256,
    id: () => crypto.randomUUID(),
    stringField,
    rateLimitAuthAccount: async () => true,
    createAudit: async () => {},
    logEvent: () => {},
    legacy: {},
  });

  try {
    const response = await routes({ method: 'POST', headers: {} }, {}, ['auth', 'password-reset', 'request']);
    assert.equal(response.status, 202, 'the public response must remain generic after delivery failure');
    assert.equal(response.data.resetToken, undefined, 'the raw reset token must never be returned');
    assert.ok(persisted, 'the reset token should have been persisted before delivery');
    assert.ok(deliveredToken, 'the delivery boundary should receive the one-time token');
    assert.equal(persisted.tokenHash, sha256(deliveredToken));
    assert.equal(invalidatedHash, persisted.tokenHash, 'the exact persisted token hash must be invalidated');
  } finally {
    if (originalDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDatabaseUrl;
  }
});
