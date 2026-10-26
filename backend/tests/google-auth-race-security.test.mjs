import test from 'node:test';
import assert from 'node:assert/strict';
import { createAuthRoutes } from '../src/routes/auth_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { requireFields, stringField } from '../src/policies/validation.js';

test('Google-registration uniqueness race never issues a session for a disabled account', async () => {
  const originalDatabaseUrl = process.env.DATABASE_URL;
  process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';
  try {
    const racedDisabledUser = {
      id: 'disabled-user',
      email: 'race@example.com',
      displayName: 'Disabled',
      role: 'USER',
      status: 'DISABLED',
      sessionVersion: 0,
    };
    let subjectLookups = 0;
    let issuedSessions = 0;
    const repo = {
      findUserByGoogleSubject: async () => {
        subjectLookups += 1;
        return subjectLookups === 1 ? null : racedDisabledUser;
      },
      createUserWithProvider: async () => {
        const error = new Error('duplicate google subject');
        error.code = '23505';
        throw error;
      },
    };
    const routes = createAuthRoutes({
      authUser: async () => null,
      authUserView: (user) => ({ id: user.id, email: user.email, role: user.role, status: user.status }),
      getUserByEmail: async () => null,
      issueSession: async () => {
        issuedSessions += 1;
        return { accessToken: 'test-access', refreshToken: 'test-refresh' };
      },
      deliverPasswordReset: async () => {},
      findUser: async () => null,
      readBody: async () => ({ idToken: 'verified-google-id-token' }),
      sendJson: async (_res, status, data) => ({ status, data }),
      HttpError,
      requireFields,
      repo,
      config: { googleAuthEnabled: true, googleOAuthClientId: 'test-client' },
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
      legacy: { createUserWithProvider: async () => racedDisabledUser },
      verifyGoogleIdToken: async () => ({
        subject: 'google-subject-1',
        email: 'race@example.com',
        email_verified: true,
        displayName: 'Race User',
      }),
    });

    await assert.rejects(
      routes({ method: 'POST' }, {}, ['auth', 'google']),
      (error) => error?.status === 401 && error?.code === 'INVALID_CREDENTIALS',
    );
    assert.equal(issuedSessions, 0);
    assert.equal(subjectLookups, 2);
  } finally {
    if (originalDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDatabaseUrl;
  }
});
