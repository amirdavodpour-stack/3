import test from 'node:test';
import assert from 'node:assert/strict';
import { createAuthRoutes } from '../src/routes/auth_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { requireFields, stringField } from '../src/policies/validation.js';

function createHarness() {
  const state = {
    users: [],
    tokens: [],
    delivered: [],
    issuedSessions: 0,
    audits: [],
    rateLimits: [],
  };
  let id = 0;
  const code = 'A1B2C3D4E5F';
  const routes = createAuthRoutes({
    authUser: async () => null,
    authUserView: (user) => ({ id: user.id, email: user.email, role: user.role, status: user.status }),
    getUserByEmail: async (email) => state.users.find((user) => user.email === email) || null,
    issueSession: async (user) => {
      state.issuedSessions += 1;
      return { accessToken: `access:${user.id}`, refreshToken: `refresh:${user.id}` };
    },
    deliverPasswordReset: async () => {},
    deliverEmailVerification: async (payload) => { state.delivered.push(payload); },
    findUser: async () => null,
    readBody: async (req) => req.body || {},
    sendJson: async (_res, status, data) => ({ status, data }),
    HttpError,
    requireFields,
    repo: {
      createUserWithProvider: async (user, provider) => {
        state.users.push(user);
        state.providers = [...(state.providers || []), provider];
        return user;
      },
      insertEmailVerificationToken: async (token) => { state.tokens.push(token); return token; },
      consumeEmailVerificationToken: async (tokenHash) => {
        const token = state.tokens.find((item) => item.tokenHash === tokenHash && !item.usedAt);
        if (!token || new Date(token.expiresAt).getTime() <= Date.now()) return null;
        token.usedAt = new Date().toISOString();
        const user = state.users.find((item) => item.id === token.userId);
        if (!user || user.status !== 'PENDING_EMAIL_VERIFICATION') return null;
        user.status = 'ACTIVE';
        return user;
      },
      invalidateEmailVerificationToken: async (tokenHash) => {
        const token = state.tokens.find((item) => item.tokenHash === tokenHash);
        if (token) token.usedAt = new Date().toISOString();
        return Boolean(token);
      },
    },
    config: {
      emailVerificationTokenTtlSeconds: 3600,
      authRateLimitMax: 10,
      rateLimitWindowMs: 60000,
      resetTokenTtlSeconds: 900,
      exposeResetTokenInDevelopment: false,
    },
    now: () => new Date().toISOString(),
    hashPassword: async () => 'test-password-hash',
    verifyPassword: async (password) => password === 'correct-password',
    passwordNeedsRehash: () => false,
    PASSWORD_MAX_LENGTH: 128,
    randomToken: () => code,
    sha256: (value) => `sha256:${value}`,
    signAccessToken: () => 'unused-test-token',
    createAudit: async (...args) => { state.audits.push(args); },
    DUMMY_PASSWORD_HASH: 'dummy-password-hash',
    logEvent: () => {},
    rateLimitAuth: async (...args) => { state.rateLimits.push(['ip', ...args]); return true; },
    rateLimitAuthAccount: async (...args) => { state.rateLimits.push(['account', ...args]); return true; },
    stringField,
    id: () => `test-id-${++id}`,
    legacy: {
      consumeEmailVerificationToken: async (tokenHash) => {
        const token = state.tokens.find((item) => item.tokenHash === tokenHash && !item.usedAt);
        if (!token || new Date(token.expiresAt).getTime() <= Date.now()) return null;
        const user = state.users.find((item) => item.id === token.userId);
        if (!user || user.status !== 'PENDING_EMAIL_VERIFICATION') return null;
        token.usedAt = new Date().toISOString();
        user.status = 'ACTIVE';
        return user;
      },
      createUserWithProvider: async (user, provider) => {
        state.users.push(user);
        state.providers = [...(state.providers || []), provider];
        return user;
      },
      insertEmailVerificationToken: async (token) => { state.tokens.push(token); return token; },
      consumeEmailVerificationToken: async () => null,
      invalidateEmailVerificationToken: async () => false,
    },
    verifyGoogleIdToken: async () => {},
  });
  return { routes, state, code };
}

test('password registration remains pending and issues no session until email ownership is proved', async () => {
  const { routes, state, code } = createHarness();
  const response = await routes({
    method: 'POST',
    body: { email: 'new-user@example.test', password: 'correct-password', displayName: 'New User' },
  }, {}, ['auth', 'register']);

  assert.equal(response.status, 202);
  assert.equal(response.data.verificationRequired, true);
  assert.equal(response.data.accessToken, undefined);
  assert.equal(response.data.refreshToken, undefined);
  assert.equal(state.users.length, 1);
  assert.equal(state.users[0].status, 'PENDING_EMAIL_VERIFICATION');
  assert.equal(state.issuedSessions, 0);
  assert.equal(state.tokens.length, 1);
  assert.equal(state.tokens[0].tokenHash, `sha256:${code}`);
  assert.equal(state.delivered.length, 1);
  assert.equal(state.delivered[0].code, code);
  assert.equal(state.delivered[0].user.email, 'new-user@example.test');
});

test('email verification activates the pending account and issues the first session', async () => {
  const { routes, state, code } = createHarness();
  await routes({
    method: 'POST',
    body: { email: 'verify@example.test', password: 'correct-password', displayName: 'Verify Me' },
  }, {}, ['auth', 'register']);

  const verified = await routes({
    method: 'POST',
    body: { code },
  }, {}, ['auth', 'email', 'verify']);

  assert.equal(verified.status, 200);
  assert.equal(verified.data.user.status, 'ACTIVE');
  assert.equal(verified.data.accessToken, 'access:test-id-1');
  assert.equal(state.issuedSessions, 1);
  assert.equal(state.users[0].status, 'ACTIVE');
});

test('email verification rejects expired, unknown and already-consumed codes without issuing a session', async () => {
  const { routes, state } = createHarness();
  await assert.rejects(
    routes({
      method: 'POST',
      body: { code: 'unknown-code' },
    }, {}, ['auth', 'email', 'verify']),
    (error) => error?.status === 400 && error?.code === 'EMAIL_VERIFICATION_INVALID',
  );
  assert.equal(state.issuedSessions, 0);
});

test('pending email registration cannot authenticate with a correct password', async () => {
  const { routes } = createHarness();
  await routes({
    method: 'POST',
    body: { email: 'pending@example.test', password: 'correct-password', displayName: 'Pending' },
  }, {}, ['auth', 'register']);

  const login = await routes({
    method: 'POST',
    body: { email: 'pending@example.test', password: 'correct-password' },
  }, {}, ['auth', 'login']);

  assert.equal(login.status, 401);
  assert.equal(login.data.error, 'INVALID_CREDENTIALS');
});
