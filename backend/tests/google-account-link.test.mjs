import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { createAuthRoutes } from '../src/routes/auth_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { requireFields, stringField } from '../src/policies/validation.js';

const originalDatabaseUrl = process.env.DATABASE_URL;
process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';
after(() => {
  if (originalDatabaseUrl === undefined) delete process.env.DATABASE_URL;
  else process.env.DATABASE_URL = originalDatabaseUrl;
});

function makeRoutes({
  user = { id: 'user-1', email: 'member@example.com', displayName: 'Member', role: 'USER', status: 'ACTIVE', googleSubject: null },
  identity = { subject: 'google-subject-1', email: 'member@example.com', email_verified: true, displayName: 'Member' },
  repository = {},
  authenticated = true,
  audit = async () => {},
  config = {},
  verifyFailure = null,
  legacy: legacyOverrides = {},
} = {}) {
  const repo = {
    findUserByGoogleSubject: async () => null,
    linkGoogleSubject: async (userId, subject) => ({ ...user, id: userId, googleSubject: subject }),
    ...repository,
  };
  const routes = createAuthRoutes({
    authUser: async () => authenticated ? user : null,
    authUserView: (value) => ({ id: value.id, email: value.email, googleSubject: value.googleSubject ?? null }),
    getUserByEmail: async () => null,
    issueSession: async () => ({ accessToken: 'unused', refreshToken: 'unused' }),
    deliverPasswordReset: async () => {},
    findUser: async () => null,
    readBody: async () => ({ idToken: 'verified-google-id-token' }),
    sendJson: async (_res, status, data) => ({ status, data }),
    HttpError,
    requireFields,
    repo,
    config: { googleAuthEnabled: true, googleOAuthClientId: 'test-client', ...config },
    now: () => '2026-10-28T00:00:00.000Z',
    hashPassword: async () => 'unused',
    verifyPassword: async () => false,
    passwordNeedsRehash: () => false,
    PASSWORD_MAX_LENGTH: 128,
    randomToken: () => 'r'.repeat(48),
    sha256: (value) => value,
    signAccessToken: () => 'unused',
    createAudit: audit,
    DUMMY_PASSWORD_HASH: 'dummy',
    logEvent: () => {},
    rateLimitAuthAccount: async () => true,
    stringField,
    id: () => 'unused',
    legacy: {
      findUserByGoogleSubject: async () => null,
      linkGoogleSubject: async (userId, subject) => ({ ...user, id: userId, googleSubject: subject }),
      save: async () => {},
      ...legacyOverrides,
    },
    verifyGoogleIdToken: async (idToken, audience) => {
      if (verifyFailure) throw verifyFailure;
      assert.equal(idToken, 'verified-google-id-token');
      assert.equal(audience, 'test-client');
      return identity;
    },
  });
  return { routes, repo };
}

const request = { method: 'POST' };
const response = {};

test('explicit Google account link binds a verified Google identity to the authenticated same-email user', async () => {
  let auditEntry;
  const { routes, repo } = makeRoutes({ audit: async (...args) => { auditEntry = args; } });
  let linked;
  repo.linkGoogleSubject = async (userId, subject) => {
    linked = { userId, subject };
    return { id: userId, email: 'member@example.com', displayName: 'Member', role: 'USER', status: 'ACTIVE', googleSubject: subject };
  };

  const result = await routes(request, response, ['auth', 'google', 'link']);

  assert.equal(result.status, 200);
  assert.equal(result.data.linked, true);
  assert.deepEqual(linked, { userId: 'user-1', subject: 'google-subject-1' });
  assert.equal(auditEntry[0], 'AUTH_GOOGLE_LINK');
  assert.equal(auditEntry[1], 'user-1');
});

test('Google account linking rejects a verified Google identity whose email differs from the signed-in account', async () => {
  let linked = false;
  const { routes, repo } = makeRoutes({
    identity: { subject: 'google-subject-1', email: 'attacker@example.com', email_verified: true, displayName: 'Other' },
  });
  repo.linkGoogleSubject = async () => { linked = true; return {}; };

  await assert.rejects(
    routes(request, response, ['auth', 'google', 'link']),
    (error) => error?.status === 403 && error?.code === 'GOOGLE_LINK_EMAIL_MISMATCH',
  );
  assert.equal(linked, false);
});

test('Google account linking rejects a subject already associated with a different user', async () => {
  let linked = false;
  const { routes, repo } = makeRoutes({
    repository: { findUserByGoogleSubject: async () => ({ id: 'another-user', email: 'other@example.com', googleSubject: 'google-subject-1' }) },
  });
  repo.linkGoogleSubject = async () => { linked = true; return {}; };

  await assert.rejects(
    routes(request, response, ['auth', 'google', 'link']),
    (error) => error?.status === 409 && error?.code === 'GOOGLE_IDENTITY_ALREADY_LINKED',
  );
  assert.equal(linked, false);
});

test('Google account linking requires an authenticated HOPE account', async () => {
  const { routes } = makeRoutes({ authenticated: false });
  await assert.rejects(
    routes(request, response, ['auth', 'google', 'link']),
    (error) => error?.status === 401,
  );
});


test('Google account linking maps a uniqueness race to a stable conflict response', async () => {
  const { routes } = makeRoutes({
    repository: {
      linkGoogleSubject: async () => {
        const error = new Error('duplicate google subject');
        error.code = '23505';
        throw error;
      },
    },
  });
  await assert.rejects(
    routes(request, response, ['auth', 'google', 'link']),
    (error) => error?.status === 409 && error?.code === 'GOOGLE_IDENTITY_ALREADY_LINKED',
  );
});

test('Google account linking is idempotent when the same identity is already linked', async () => {
  const user = { id: 'user-1', email: 'member@example.com', displayName: 'Member', role: 'USER', status: 'ACTIVE', googleSubject: 'google-subject-1' };
  const { routes } = makeRoutes({ user });
  const result = await routes(request, response, ['auth', 'google', 'link']);
  assert.equal(result.status, 200);
  assert.equal(result.data.linked, true);
  assert.equal(result.data.alreadyLinked, true);
});

test('Google account linking refuses to replace a different Google identity', async () => {
  const user = { id: 'user-1', email: 'member@example.com', displayName: 'Member', role: 'USER', status: 'ACTIVE', googleSubject: 'previous-subject' };
  const { routes } = makeRoutes({ user });
  await assert.rejects(
    routes(request, response, ['auth', 'google', 'link']),
    (error) => error?.status === 409 && error?.code === 'GOOGLE_ACCOUNT_ALREADY_LINKED',
  );
});

test('Google account linking rejects invalid identity tokens before persistence', async () => {
  let linked = false;
  const { routes } = makeRoutes({
    verifyFailure: new Error('INVALID_GOOGLE_TOKEN'),
    repository: { linkGoogleSubject: async () => { linked = true; return {}; } },
  });
  await assert.rejects(
    routes(request, response, ['auth', 'google', 'link']),
    (error) => error?.status === 401 && error?.code === 'INVALID_GOOGLE_TOKEN',
  );
  assert.equal(linked, false);
});

test('Google account linking fails closed when Google authentication is disabled', async () => {
  const { routes } = makeRoutes({ config: { googleAuthEnabled: false } });
  await assert.rejects(
    routes(request, response, ['auth', 'google', 'link']),
    (error) => error?.status === 503 && error?.code === 'GOOGLE_AUTH_UNAVAILABLE',
  );
});

test('Google account linking works in the legacy adapter path and persists the association', async () => {
  const original = process.env.DATABASE_URL;
  delete process.env.DATABASE_URL;
  try {
    let saved = false;
    let linked;
    const { routes } = makeRoutes({
      legacy: {
        findUserByGoogleSubject: async () => null,
        linkGoogleSubject: async (userId, subject) => {
          linked = { userId, subject };
          return { id: userId, email: 'member@example.com', displayName: 'Member', googleSubject: subject };
        },
        save: async () => { saved = true; },
      },
    });
    const result = await routes(request, response, ['auth', 'google', 'link']);
    assert.equal(result.status, 200);
    assert.deepEqual(linked, { userId: 'user-1', subject: 'google-subject-1' });
    assert.equal(saved, true);
  } finally {
    process.env.DATABASE_URL = original;
  }
});
