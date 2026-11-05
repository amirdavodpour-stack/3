import test from 'node:test';
import assert from 'node:assert/strict';
import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';
import {
  decryptTotpSecret,
  generateRecoveryCodes,
  generateTotpCode,
  hashRecoveryCode,
} from '../src/security/admin_mfa.js';

const MFA_KEY = 'hope-admin-mfa-test-encryption-key-with-entropy';
const USER = Object.freeze({
  id: 'admin-mfa-user',
  email: 'ops@example.test',
  displayName: 'Operations Admin',
  role: 'ADMIN',
  status: 'ACTIVE',
  googleSubject: 'google-subject-admin',
  passwordHash: 'password-hash',
  sessionJti: 'admin-mfa-session-jti',
});

function makeHarness({ credential = null, alreadyEnabled = false } = {}) {
  const audit = [];
  const calls = [];
  let stored = credential;
  let accessVerification = null;
  let clock = Date.now();
  const route = createAdminRoutes({
    authUser: async () => USER,
    requireAdmin: (user) => user,
    readBody: async (req) => req.body || {},
    sendJson: async (_res, status, data) => ({ status, data }),
    HttpError,
    enumField: (value, allowed, field) => {
      if (!allowed.has(value)) throw new HttpError(400, 'INVALID_FIELD', field);
      return value;
    },
    adminUseCases: {},
    legacyAdmin: {},
    config: {
      adminPanelUsername: 'hope-admin',
      adminPanelAllowedEmail: 'owner@example.test',
      adminPanelVerificationMinutes: 15,
      adminPanelReadVerificationMinutes: 15,
      adminPanelWriteVerificationMinutes: 5,
      adminMfaRequired: true,
      adminMfaEncryptionKey: MFA_KEY,
      adminMfaEnrollmentMinutes: 10,
      authRateLimitMax: 20,
      rateLimitWindowMs: 60000,
      googleAuthEnabled: false,
      googleOAuthClientId: '',
    },
    now: () => new Date(clock).toISOString(),
    createAudit: async (...args) => audit.push(args),
    repo: {
      getAdminMfaStatus: async () => ({ enabled: alreadyEnabled || Boolean(stored?.enabled) }),
      beginAdminMfaEnrollment: async (userId, encryptedSecret, expiresAt) => {
        calls.push(['begin', userId, encryptedSecret, expiresAt]);
        stored = {
          enabled: false,
          pendingSecretCiphertext: encryptedSecret,
          pendingExpiresAt: expiresAt,
          lastTotpCounter: -1,
        };
        return true;
      },
      getAdminMfaCredential: async () => stored,
      completeAdminMfaEnrollment: async (userId, { secretCiphertext, recoveryCodeHashes, lastTotpCounter }) => {
        calls.push(['complete', userId, secretCiphertext, recoveryCodeHashes, lastTotpCounter]);
        stored = {
          enabled: true,
          secretCiphertext,
          recoveryCodeHashes,
          lastTotpCounter,
        };
        return true;
      },
      consumeAdminTotpCounter: async (userId, counter) => {
        calls.push(['totp', userId, counter]);
        if (counter <= (stored?.lastTotpCounter ?? -1)) return false;
        stored.lastTotpCounter = counter;
        return true;
      },
      consumeAdminRecoveryCode: async (userId, codeHash) => {
        calls.push(['recovery', userId, codeHash]);
        const codes = stored?.recoveryCodeHashes || [];
        if (!codes.includes(codeHash)) return false;
        stored.recoveryCodeHashes = codes.filter((item) => item !== codeHash);
        return true;
      },
      setAdminPanelVerified: async (...args) => {
        accessVerification = args;
        return { verifiedAt: new Date(now).toISOString() };
      },
      isAdminPanelVerified: async () => true,
      clearAdminPanelVerification: async () => true,
    },
    verifyPassword: async (password, hash) => password === 'current-password' && hash === USER.passwordHash,
    verifyGoogleIdToken: async () => { throw new Error('Google should not be used in this case'); },
    rateLimitAuth: async () => true,
    rateLimitAuthAccount: async () => true,
    DUMMY_PASSWORD_HASH: 'dummy-hash',
    PASSWORD_MAX_LENGTH: 128,
  });
  return { route, audit, calls, getStored: () => stored, getAccessVerification: () => accessVerification, get now() { return clock; }, advance(ms) { clock += ms; } };
}

function invoke(route, method, parts, body = {}) {
  return route({ method, url: '/api/v1/' + parts.join('/'), headers: { host: 'localhost' }, body }, {}, parts);
}

test('admin MFA setup encrypts a pending secret and returns an authenticator URI only once', async () => {
  const h = makeHarness();
  const result = await invoke(h.route, 'POST', ['admin','access','mfa','setup'], {
    name: USER.displayName,
    username: 'hope-admin',
    password: 'current-password',
  });
  assert.equal(result.status, 200);
  assert.equal(result.data.pending, true);
  assert.equal(result.data.secret.length, 32);
  assert.ok(result.data.otpauthUri.startsWith('otpauth://totp/'));
  const stored = h.getStored();
  assert.notEqual(stored.pendingSecretCiphertext, result.data.secret);
  assert.equal(decryptTotpSecret(stored.pendingSecretCiphertext, MFA_KEY), result.data.secret);
  assert.equal(h.audit[0][0], 'ADMIN_MFA_SETUP_STARTED');
});

test('admin MFA enrollment confirms TOTP and returns ten recovery codes once while storing only hashes', async () => {
  const h = makeHarness();
  const setup = await invoke(h.route, 'POST', ['admin','access','mfa','setup'], {
    name: USER.displayName, username: 'hope-admin', password: 'current-password',
  });
  const secret = setup.data.secret;
  const code = generateTotpCode(secret, h.now);
  const confirmed = await invoke(h.route, 'POST', ['admin','access','mfa','confirm'], { code });
  assert.equal(confirmed.status, 200);
  assert.equal(confirmed.data.enabled, true);
  assert.equal(confirmed.data.recoveryCodes.length, 10);
  const completed = h.calls.find((call) => call[0] === 'complete');
  assert.ok(completed);
  assert.equal(completed[3].length, 10);
  for (const raw of confirmed.data.recoveryCodes) {
    assert.ok(completed[3].includes(hashRecoveryCode(raw)));
    assert.ok(!completed[3].includes(raw));
  }
  assert.equal(h.audit.at(-1)[0], 'ADMIN_MFA_ENROLLED');
});

test('admin MFA enrollment rejects invalid TOTP without activating the account', async () => {
  const h = makeHarness();
  await invoke(h.route, 'POST', ['admin','access','mfa','setup'], {
    name: USER.displayName, username: 'hope-admin', password: 'current-password',
  });
  await assert.rejects(
    invoke(h.route, 'POST', ['admin','access','mfa','confirm'], { code: '000000' }),
    (error) => error?.status === 401 && error?.code === 'ADMIN_MFA_CODE_INVALID',
  );
  assert.equal(h.getStored().enabled, false);
  assert.equal(h.calls.some((call) => call[0] === 'complete'), false);
});

test('admin panel unlock requires primary reauthentication and a valid TOTP factor', async () => {
  const h = makeHarness();
  const setup = await invoke(h.route, 'POST', ['admin','access','mfa','setup'], {
    name: USER.displayName, username:'hope-admin', password:'current-password',
  });
  const firstCode = generateTotpCode(setup.data.secret, h.now);
  await invoke(h.route, 'POST', ['admin','access','mfa','confirm'], { code:firstCode });
  h.advance(30000);
  const counter = Math.floor(h.now / 30000);
  const code = generateTotpCode(setup.data.secret, h.now);
  const unlocked = await invoke(h.route, 'POST', ['admin','access'], {
    name: USER.displayName, username:'hope-admin', password:'current-password', totpCode:code,
  });
  assert.equal(unlocked.status, 200);
  assert.equal(unlocked.data.verified, true);
  assert.deepEqual(h.getAccessVerification(), [USER.id, USER.sessionJti, 'WRITE']);
  assert.ok(h.calls.some((call) => call[0] === 'totp' && call[2] === counter));
});

test('admin MFA unlock rejects replayed counters and does not set panel verification', async () => {
  const h = makeHarness();
  const setup = await invoke(h.route, 'POST', ['admin','access','mfa','setup'], {
    name: USER.displayName, username:'hope-admin', password:'current-password',
  });
  const enrollmentCode = generateTotpCode(setup.data.secret, h.now);
  await invoke(h.route, 'POST', ['admin','access','mfa','confirm'], { code:enrollmentCode });
  h.advance(30000);
  const code = generateTotpCode(setup.data.secret, h.now);
  const next = await invoke(h.route, 'POST', ['admin','access'], {
    name: USER.displayName, username:'hope-admin', password:'current-password', totpCode:code,
  });
  assert.equal(next.status, 200);
  await assert.rejects(
    invoke(h.route, 'POST', ['admin','access'], {
      name: USER.displayName, username:'hope-admin', password:'current-password', totpCode:code,
    }),
    (error) => error?.status === 401 && error?.code === 'ADMIN_MFA_CODE_INVALID',
  );
});

test('admin MFA unlock consumes a recovery code exactly once', async () => {
  const h = makeHarness();
  const setup = await invoke(h.route, 'POST', ['admin','access','mfa','setup'], {
    name: USER.displayName, username:'hope-admin', password:'current-password',
  });
  const code = generateTotpCode(setup.data.secret, h.now);
  const enrollment = await invoke(h.route, 'POST', ['admin','access','mfa','confirm'], { code });
  const recovery = enrollment.data.recoveryCodes[0];
  const first = await invoke(h.route, 'POST', ['admin','access'], {
    name:USER.displayName, username:'hope-admin', password:'current-password', recoveryCode:recovery,
  });
  assert.equal(first.status, 200);
  const second = await invoke(h.route, 'POST', ['admin','access'], {
    name:USER.displayName, username:'hope-admin', password:'current-password', recoveryCode:recovery,
  });
  assert.equal(second.status, 401);
});
