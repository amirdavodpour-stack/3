import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-auth-security-postgres-integration.json';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository.js'),
      import('../src/routes/auth_routes.js'),
      import('../src/routes/admin_routes.js'),
      import('../src/api/http_error.js'),
      import('../src/policies/validation.js'),
    ])
  : [];

const dbModule = modules[0];
const repository = modules[1];
const { createAuthRoutes } = modules[2] || {};
const { createAdminRoutes } = modules[3] || {};
const { HttpError } = modules[4] || {};
const { requireFields, stringField, requireAdmin } = modules[5] || {};

if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');

async function createUser({
  role = 'USER',
  passwordHash = 'google-only-unusable-password-hash',
  email = 'google-only-' + crypto.randomUUID() + '@example.test',
  displayName = 'Google-only integration user',
  googleSubject = 'google-subject-' + crypto.randomUUID(),
  sessionVersion = 0,
  verifiedAt = null,
  verifiedJti = null,
} = {}) {
  const id = crypto.randomUUID();
  await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,created_at,
       google_subject,admin_panel_verified_at,admin_panel_verified_session_jti
     ) VALUES($1,$2,$3,$4,$5,'ACTIVE',$6,NOW(),$7,$8,$9)`,
    [id,email,passwordHash,displayName,role,sessionVersion,googleSubject,verifiedAt,verifiedJti],
  );
  return { id,email,displayName,role,googleSubject };
}

async function insertExistingRefreshToken(userId, rawToken) {
  const id = crypto.randomUUID();
  const familyId = crypto.randomUUID();
  await pool.query(
    `INSERT INTO refresh_tokens(
       id,user_id,token_hash,family_id,expires_at,created_at,revoked_at,replaced_by
     ) VALUES($1,$2,$3,$4,NOW()+INTERVAL '30 days',NOW(),NULL,NULL)`,
    [id,userId,sha256(rawToken),familyId],
  );
  return { id,familyId,tokenHash:sha256(rawToken) };
}

async function createAudit(action, actorId, entityType, entityId, meta = {}) {
  await pool.query(
    `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
     VALUES($1,$2,$3,$4,$5,$6::jsonb,NOW())`,
    [crypto.randomUUID(),action,actorId,entityType,entityId,JSON.stringify(meta)],
  );
}

async function cleanupUser(userId) {
  await pool.query('DELETE FROM audit_logs WHERE actor_id=$1 OR entity_id=$1',[userId]).catch(() => {});
  await pool.query('DELETE FROM users WHERE id=$1',[userId]).catch(() => {});
}

function makeAuthRoutes(bodyState, onResetDelivery) {
  return createAuthRoutes({
    authUser: async () => null,
    authUserView: (user) => ({
      id:user.id,
      email:user.email,
      role:user.role,
      googleSubject:user.googleSubject || null,
    }),
    getUserByEmail: repository.findUserByEmail,
    issueSession: async (user) => ({
      accessToken:'integration-access-' + user.id,
      refreshToken:'integration-refresh-' + user.id,
    }),
    deliverPasswordReset: async ({ token }) => onResetDelivery(token),
    deliverEmailVerification: async () => {},
    findUser: async () => null,
    readBody: async () => bodyState.current,
    sendJson: async (_res,status,data) => ({status,data}),
    HttpError,
    requireFields,
    repo:repository,
    config:{
      googleAuthEnabled:true,
      googleOAuthClientId:'hope-postgres-integration-client',
      resetTokenTtlSeconds:3600,
      emailVerificationTokenTtlSeconds:3600,
      exposeResetTokenInDevelopment:false,
      authRateLimitMax:100,
      rateLimitWindowMs:60_000,
    },
    now:() => new Date().toISOString(),
    hashPassword:async (password) => 'integration-password-hash:' + password,
    verifyPassword:async (password,hash) => hash === 'integration-password-hash:' + password,
    passwordNeedsRehash:() => false,
    PASSWORD_MAX_LENGTH:128,
    randomToken:(length) => crypto.randomBytes(length).toString('hex'),
    sha256,
    signAccessToken:() => 'integration-signed-access-token',
    createAudit,
    DUMMY_PASSWORD_HASH:'integration-invalid-dummy-hash',
    logEvent:() => {},
    rateLimitAuth:async () => true,
    rateLimitAuthAccount:async () => true,
    stringField,
    id:() => crypto.randomUUID(),
    legacy:{},
    verifyGoogleIdToken:async (token,audience) => {
      assert.equal(token,'valid-google-id-token');
      assert.equal(audience,'hope-postgres-integration-client');
      return bodyState.googleIdentity;
    },
  });
}

test('PostgreSQL Google-only password recovery preserves Google identity and invalidates prior sessions atomically', {
  skip:!enabled,
  timeout:30_000,
}, async () => {
  const user = await createUser({
    role:'ADMIN',
    email:'google-only-recovery-' + crypto.randomUUID() + '@example.test',
    googleSubject:'google-recovery-' + crypto.randomUUID(),
    sessionVersion:7,
    verifiedAt:new Date(),
    verifiedJti:'pre-reset-admin-session',
  });
  const rawRefreshToken = 'previous-refresh-token-' + crypto.randomUUID();
  const refresh = await insertExistingRefreshToken(user.id,rawRefreshToken);
  const bodyState = {
    current:{},
    googleIdentity:{
      subject:user.googleSubject,
      email:user.email,
      email_verified:true,
      authoritativeEmail:true,
      displayName:user.displayName,
    },
  };
  let deliveredToken = null;
  const routes = makeAuthRoutes(bodyState,(token) => { deliveredToken = token; });

  try {
    bodyState.current = {email:user.email};
    const requested = await routes({method:'POST',headers:{}},{},['auth','password-reset','request']);
    assert.equal(requested.status,202);
    assert.equal(requested.data.ok,true);
    assert.equal(requested.data.resetToken,undefined,'the raw reset token must never be returned by the route');
    assert.ok(deliveredToken,'the reset token must be handed to the delivery boundary');

    const storedBeforeUse = await pool.query(
      'SELECT token_hash,used_at FROM reset_tokens WHERE user_id=$1',
      [user.id],
    );
    assert.equal(storedBeforeUse.rows.length,1);
    assert.equal(storedBeforeUse.rows[0].token_hash,sha256(deliveredToken));
    assert.equal(storedBeforeUse.rows[0].used_at,null);

    bodyState.current = {token:deliveredToken,password:'NewSecurePassword123'};
    const confirmed = await routes({method:'POST',headers:{}},{},['auth','password-reset','confirm']);
    assert.equal(confirmed.status,200);
    assert.equal(confirmed.data.ok,true);

    const state = await pool.query(
      `SELECT password_hash,google_subject,session_version,admin_panel_verified_at,
              admin_panel_verified_session_jti
         FROM users WHERE id=$1`,
      [user.id],
    );
    assert.equal(state.rows[0].password_hash,'integration-password-hash:NewSecurePassword123');
    assert.equal(state.rows[0].google_subject,user.googleSubject,'password reset must not unlink the Google identity');
    assert.equal(Number(state.rows[0].session_version),8,'password reset must advance the session version');
    assert.equal(state.rows[0].admin_panel_verified_at,null,'password reset must clear admin step-up verification');
    assert.equal(state.rows[0].admin_panel_verified_session_jti,null,'password reset must clear the bound admin session');

    const refreshState = await pool.query(
      'SELECT revoked_at FROM refresh_tokens WHERE id=$1 AND user_id=$2',
      [refresh.id,user.id],
    );
    assert.ok(refreshState.rows[0]?.revoked_at,'all previously valid refresh tokens must be revoked');

    const tokenAfterUse = await pool.query(
      'SELECT used_at FROM reset_tokens WHERE user_id=$1',
      [user.id],
    );
    assert.ok(tokenAfterUse.rows[0]?.used_at,'the reset token must be consumed');

    await assert.rejects(
      routes({method:'POST',headers:{}},{},['auth','password-reset','confirm']),
      (error) => error?.status === 400 && error?.code === 'INVALID_RESET_TOKEN',
      'a consumed reset token must not be reusable',
    );

    bodyState.current = {email:user.email,password:'NewSecurePassword123'};
    const passwordLogin = await routes({method:'POST',headers:{}},{},['auth','login']);
    assert.equal(passwordLogin.status,200);
    assert.equal(passwordLogin.data.user.googleSubject,user.googleSubject);
    assert.equal(passwordLogin.data.accessToken,'integration-access-' + user.id);

    bodyState.current = {idToken:'valid-google-id-token'};
    const googleLogin = await routes({method:'POST',headers:{}},{},['auth','google']);
    assert.equal(googleLogin.status,200);
    assert.equal(googleLogin.data.user.googleSubject,user.googleSubject);
    assert.equal(googleLogin.data.accessToken,'integration-access-' + user.id);
  } finally {
    await cleanupUser(user.id);
  }
});

test('PostgreSQL Google admin reauthentication persists step-up verification for only the current session', {
  skip:!enabled,
  timeout:30_000,
}, async () => {
  const user = await createUser({
    role:'ADMIN',
    email:'ops-google-admin-' + crypto.randomUUID() + '@example.test',
    displayName:'Google Operations Admin',
    googleSubject:'google-admin-subject-' + crypto.randomUUID(),
  });
  const originalSessionJti = 'admin-session-' + crypto.randomUUID();
  let activeSessionJti = originalSessionJti;
  const bodyState = {
    current:{
      name:user.displayName,
      username:'hope-admin',
      idToken:'fresh-google-admin-token',
    },
  };
  const adminRoutes = createAdminRoutes({
    authUser:async () => ({...user,sessionJti:activeSessionJti}),
    requireAdmin,
    readBody:async () => bodyState.current,
    sendJson:async (_res,status,data) => ({status,data}),
    HttpError,
    config:{
      adminPanelUsername:'hope-admin',
      adminPanelAllowedEmail:'amir.davodpour@gmail.com',
      adminPanelVerificationMinutes:15,
      authRateLimitMax:20,
      rateLimitWindowMs:60_000,
      googleAuthEnabled:true,
      googleOAuthClientId:'hope-admin-postgres-integration-client',
    },
    repo:repository,
    createAudit,
    verifyPassword:async () => false,
    verifyGoogleIdToken:async (token,audience) => {
      assert.equal(token,'fresh-google-admin-token');
      assert.equal(audience,'hope-admin-postgres-integration-client');
      return {
        subject:user.googleSubject,
        email:user.email,
        issuedAt:Math.floor(Date.now()/1000),
      };
    },
    rateLimitAuth:async () => true,
    rateLimitAuthAccount:async () => true,
    DUMMY_PASSWORD_HASH:'integration-invalid-dummy-hash',
    PASSWORD_MAX_LENGTH:128,
  });

  try {
    const unlocked = await adminRoutes({method:'POST',headers:{}},{},['admin','access']);
    assert.equal(unlocked.status,200);
    assert.equal(unlocked.data.verified,true);

    const sameSession = await adminRoutes({method:'GET',headers:{}},{},['admin','access']);
    assert.equal(sameSession.status,200);
    assert.equal(sameSession.data.verified,true,'the session that completed Google step-up must be verified');

    const persisted = await pool.query(
      'SELECT admin_panel_verified_at,admin_panel_verified_session_jti FROM users WHERE id=$1',
      [user.id],
    );
    assert.ok(persisted.rows[0]?.admin_panel_verified_at);
    assert.equal(persisted.rows[0]?.admin_panel_verified_session_jti,originalSessionJti);

    activeSessionJti = 'different-admin-session-' + crypto.randomUUID();
    const otherSession = await adminRoutes({method:'GET',headers:{}},{},['admin','access']);
    assert.equal(otherSession.status,200);
    assert.equal(otherSession.data.verified,false,'a different session must not inherit another session\'s step-up verification');

    const audit = await pool.query(
      `SELECT action,meta FROM audit_logs
        WHERE actor_id=$1 AND action='ADMIN_PANEL_UNLOCK'
        ORDER BY created_at DESC LIMIT 1`,
      [user.id],
    );
    assert.equal(audit.rows[0]?.action,'ADMIN_PANEL_UNLOCK');
    assert.equal(audit.rows[0]?.meta?.method,'google');
  } finally {
    await cleanupUser(user.id);
  }
});

after(async () => {
  if (enabled) await dbModule.db.close();
});
