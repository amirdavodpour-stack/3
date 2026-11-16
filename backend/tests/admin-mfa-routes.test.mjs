import test from 'node:test';
import assert from 'node:assert/strict';
import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';
import {
  decryptRecoveryCodes,
  decryptTotpSecret,
  encryptRecoveryCodes,
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
  sessionVersion: 0,
});

function makeHarness({ credential = null, alreadyEnabled = false, dropConfirmResponse = false, dropAckResponse = false, failUnlockAudit = false } = {}) {
  const audit = [];
  const calls = [];
  let stored = credential;
  let accessVerification = null;
  let clock = Date.now();
  let loseConfirmResponse=dropConfirmResponse;
  let loseAckResponse=dropAckResponse;
  let rejectUnlockAudit=failUnlockAudit;
  const route = createAdminRoutes({
    authUser: async () => USER,
    requireAdmin: (user) => user,
    readBody: async (req) => req.body || {},
    sendJson: async (_res, status, data) => {
      if(loseConfirmResponse && Array.isArray(data?.recoveryCodes)){loseConfirmResponse=false;throw new Error('SIMULATED_CONFIRM_RESPONSE_LOST');}
      if(loseAckResponse && data?.acknowledged===true){loseAckResponse=false;throw new Error('SIMULATED_ACK_RESPONSE_LOST');}
      return {status,data};
    },
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
      getAdminMfaStatus: async () => ({ enabled: alreadyEnabled || Boolean(stored?.enabled), recoveryCodesDeliveryPending:Boolean(stored?.recoveryCodesCiphertext) }),
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
      consumeAdminMfaRecoveryDelivery: async (userId, counter, sessionJti, sessionVersion) => {
        calls.push(['recovery-delivery', userId, counter, sessionJti, sessionVersion]);
        if (sessionVersion !== USER.sessionVersion || !stored?.recoveryCodesCiphertext || counter <= (stored.lastTotpCounter ?? -1)) return null;
        stored.lastTotpCounter = counter;
        return {ciphertext:stored.recoveryCodesCiphertext,deliveryId:stored.recoveryDeliveryId};
      },
      acknowledgeAdminMfaRecoveryDelivery: async (userId, sessionJti, sessionVersion, deliveryId) => {
        calls.push(['recovery-ack',userId,sessionJti,sessionVersion,deliveryId]);
        if(sessionVersion !== USER.sessionVersion || !stored || stored.recoveryDeliveryId!==deliveryId) return false;
        if(stored.recoveryCodesAcknowledgedAt) return true;
        if(!stored.recoveryCodesCiphertext) return false;
        stored.recoveryCodesCiphertext=null;
        stored.recoveryCodesAcknowledgedAt=new Date(clock).toISOString();
        return true;
      },
      completeAdminMfaEnrollment: async (userId, { secretCiphertext, recoveryCodeHashes, recoveryCodesCiphertext, recoveryDeliveryId, lastTotpCounter }) => {
        calls.push(['complete', userId, secretCiphertext, recoveryCodeHashes, lastTotpCounter]);
        stored = {
          enabled: true,
          secretCiphertext,
          recoveryCodeHashes,
          recoveryCodesCiphertext,
          recoveryDeliveryId,
          recoveryCodesAcknowledgedAt:null,
          lastTotpCounter,
          enrolledAt: new Date().toISOString(),
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
      verifyAdminPanelMfaAndUnlock: async (userId, options) => {
        const {sessionJti,sessionVersion,scope,factor,auditMeta}=options;
        calls.push(['atomic-mfa-unlock',userId,sessionJti,sessionVersion,scope,factor.method]);
        if (sessionVersion!==USER.sessionVersion || !stored?.enabled || stored.recoveryCodesCiphertext) return null;
        const previousStored=structuredClone(stored);
        const previousVerification=accessVerification;
        if (factor.method==='totp') {
          calls.push(['totp',userId,factor.counter]);
          if (factor.secretCiphertext!==stored.secretCiphertext || factor.counter<=(stored.lastTotpCounter??-1)) return null;
          stored.lastTotpCounter=factor.counter;
        } else {
          calls.push(['recovery',userId,factor.recoveryCodeHash]);
          const codes=stored.recoveryCodeHashes||[];
          if (!codes.includes(factor.recoveryCodeHash)) return null;
          stored.recoveryCodeHashes=codes.filter((item)=>item!==factor.recoveryCodeHash);
        }
        if (rejectUnlockAudit) {
          stored=previousStored;
          accessVerification=previousVerification;
          throw new Error('SIMULATED_ADMIN_PANEL_UNLOCK_AUDIT_FAILURE');
        }
        accessVerification=[userId,sessionJti,scope];
        audit.push(['ADMIN_PANEL_UNLOCK',userId,'admin',userId,{...auditMeta,scope,sessionJti}]);
        return {verifiedAt:new Date(clock).toISOString(),scope};
      },
      setAdminPanelVerified: async (...args) => {
        accessVerification = args;
        return { verifiedAt: new Date(clock).toISOString() };
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
  return { route, audit, calls, getStored: () => stored, getAccessVerification: () => accessVerification, setFailUnlockAudit(value) { rejectUnlockAudit=Boolean(value); }, get now() { return clock; }, advance(ms) { clock += ms; } };
}

function invoke(route, method, parts, body = {}) {
  return route({ method, url: '/api/v1/' + parts.join('/'), headers: { host: 'localhost' }, body }, {}, parts);
}

async function acknowledgeRecovery(h, deliveryId) {
  return invoke(h.route,'POST',['admin','access','mfa','recovery-codes','ack'],{
    name:USER.displayName,username:'hope-admin',password:'current-password',recoveryDeliveryId:deliveryId,
  });
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
  assert.ok(confirmed.data.recoveryDeliveryId);
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
  const enrollment=await invoke(h.route, 'POST', ['admin','access','mfa','confirm'], { code:firstCode });
  await acknowledgeRecovery(h,enrollment.data.recoveryDeliveryId);
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
  const enrollment=await invoke(h.route, 'POST', ['admin','access','mfa','confirm'], { code:enrollmentCode });
  await acknowledgeRecovery(h,enrollment.data.recoveryDeliveryId);
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
  await acknowledgeRecovery(h,enrollment.data.recoveryDeliveryId);
  const recovery = enrollment.data.recoveryCodes[0];
  const first = await invoke(h.route, 'POST', ['admin','access'], {
    name:USER.displayName, username:'hope-admin', password:'current-password', recoveryCode:recovery,
  });
  assert.equal(first.status, 200);
  await assert.rejects(
    invoke(h.route, 'POST', ['admin','access'], {
      name:USER.displayName, username:'hope-admin', password:'current-password', recoveryCode:recovery,
    }),
    (error) => error?.status === 401 && error?.code === 'ADMIN_MFA_CODE_INVALID',
  );
});


test('lost MFA enrollment and ACK responses can be retried securely without losing recovery codes', async () => {
  const h=makeHarness({dropConfirmResponse:true,dropAckResponse:true});
  const setup=await invoke(h.route,'POST',['admin','access','mfa','setup'],{name:USER.displayName,username:'hope-admin',password:'current-password'});
  const enrollmentCode=generateTotpCode(setup.data.secret,h.now);
  await assert.rejects(
    invoke(h.route,'POST',['admin','access','mfa','confirm'],{code:enrollmentCode}),
    /SIMULATED_CONFIRM_RESPONSE_LOST/,
  );
  const status=await invoke(h.route,'GET',['admin','access','mfa']);
  assert.equal(status.data.enabled,true);
  assert.equal(status.data.recoveryCodesDeliveryPending,true);
  const stored=h.getStored();
  const expected=decryptRecoveryCodes(stored.recoveryCodesCiphertext,MFA_KEY);
  assert.equal(expected.length,10);
  assert.ok(stored.recoveryDeliveryId);
  h.advance(30000);
  const retryCode=generateTotpCode(setup.data.secret,h.now);
  const delivered=await invoke(h.route,'POST',['admin','access','mfa','recovery-codes','retrieve'],{code:retryCode});
  assert.equal(delivered.status,200);
  assert.deepEqual(delivered.data.recoveryCodes,expected);
  assert.equal(delivered.data.recoveryDeliveryId,stored.recoveryDeliveryId);

  await assert.rejects(
    invoke(h.route,'POST',['admin','access'],{
      name:USER.displayName,username:'hope-admin',password:'current-password',totpCode:retryCode,
    }),
    (error)=>error?.status===409&&error?.code==='ADMIN_MFA_RECOVERY_CODES_ACK_REQUIRED',
  );

  await assert.rejects(acknowledgeRecovery(h,delivered.data.recoveryDeliveryId),/SIMULATED_ACK_RESPONSE_LOST/);
  const retriedAck=await acknowledgeRecovery(h,delivered.data.recoveryDeliveryId);
  assert.equal(retriedAck.data.acknowledged,true);
  assert.equal(h.getStored().recoveryCodesCiphertext,null);
  const acknowledgedStatus=await invoke(h.route,'GET',['admin','access','mfa']);
  assert.equal(acknowledgedStatus.data.recoveryCodesDeliveryPending,false);

  h.advance(30000);
  const unlockCode=generateTotpCode(setup.data.secret,h.now);
  const unlocked=await invoke(h.route,'POST',['admin','access'],{
    name:USER.displayName,username:'hope-admin',password:'current-password',totpCode:unlockCode,
  });
  assert.equal(unlocked.status,200);
  assert.equal(unlocked.data.verified,true);
});


test('admin MFA factor and panel unlock remain reusable when the unlock audit transaction fails', async () => {
  const h=makeHarness({failUnlockAudit:true});
  const setup=await invoke(h.route,'POST',['admin','access','mfa','setup'],{
    name:USER.displayName,username:'hope-admin',password:'current-password',
  });
  const enrollmentCode=generateTotpCode(setup.data.secret,h.now);
  const enrollment=await invoke(h.route,'POST',['admin','access','mfa','confirm'],{code:enrollmentCode});
  await acknowledgeRecovery(h,enrollment.data.recoveryDeliveryId);
  h.advance(30000);
  const retryCounter=Math.floor(h.now/30000);
  const retryCode=generateTotpCode(setup.data.secret,h.now);
  const before=h.getStored().lastTotpCounter;

  await assert.rejects(
    invoke(h.route,'POST',['admin','access'],{
      name:USER.displayName,username:'hope-admin',password:'current-password',totpCode:retryCode,
    }),
    /SIMULATED_ADMIN_PANEL_UNLOCK_AUDIT_FAILURE/,
  );
  assert.equal(h.getStored().lastTotpCounter,before,
    'a failed unlock/audit transaction must roll back TOTP counter consumption');
  assert.equal(h.getAccessVerification(),null,
    'a failed unlock/audit transaction must not persist panel verification');

  h.setFailUnlockAudit(false);
  const unlocked=await invoke(h.route,'POST',['admin','access'],{
    name:USER.displayName,username:'hope-admin',password:'current-password',totpCode:retryCode,
  });
  assert.equal(unlocked.status,200);
  assert.equal(h.getAccessVerification()[1],USER.sessionJti);
  assert.ok(retryCounter>before);
});
