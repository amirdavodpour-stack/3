import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

process.env.NODE_ENV = 'test';
const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository.js'),
      import('../src/security/admin_mfa.js'),
    ])
  : [];
const dbModule = modules[0];
const repository = modules[1];
const mfa = modules[2];
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;

test('PostgreSQL admin MFA stores only encrypted secrets and one-way recovery hashes, and enforces counter/scope replay guards', {
  skip:!enabled,
  timeout:30_000,
}, async () => {
  const userId = crypto.randomUUID();
  const email = `admin-mfa-${userId}@example.test`;
  const secretKey = 'hope-postgres-mfa-integration-key-with-entropy';
  const encryptionKey = 'hope-postgres-mfa-encryption-key-with-adequate-entropy';
  const jti = `admin-mfa-session-${userId}`;
  const { rows: inserted } = await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at,google_subject)
     VALUES($1,$2,'integration-hash','MFA Integration Admin','ADMIN','ACTIVE',0,NOW(),$3)
     RETURNING id`,
    [userId,email,`google-${userId}`],
  );
  assert.equal(inserted.length,1);

  try {
    const secret = mfa.generateTotpSecret();
    const ciphertext = mfa.encryptTotpSecret(secret,encryptionKey);
    assert.notEqual(ciphertext,secret);
    const expiresAt = new Date(Date.now()+10*60_000).toISOString();
    assert.equal(await repository.beginAdminMfaEnrollment(userId,ciphertext,expiresAt,{expiresInMinutes:10}),true);

    const pending = await repository.getAdminMfaCredential(userId);
    assert.equal(pending.pendingSecretCiphertext,ciphertext);
    assert.equal(mfa.decryptTotpSecret(pending.pendingSecretCiphertext,encryptionKey),secret);

    const enrollmentCounter = Math.floor(Date.now()/30_000);
    const recovery = mfa.generateRecoveryCodes(10);
    assert.equal(await repository.completeAdminMfaEnrollment(userId,{
      secretCiphertext:ciphertext,
      recoveryCodeHashes:recovery.hashes,
      lastTotpCounter:enrollmentCounter,
      auditMeta:{recoveryCodesIssued:recovery.codes.length},
    }),true);

    const stored = await pool.query(
      `SELECT secret_ciphertext,recovery_code_hashes,last_totp_counter,enrolled_at
         FROM admin_mfa_credentials WHERE user_id=$1`,
      [userId],
    );
    assert.equal(stored.rows.length,1);
    assert.notEqual(stored.rows[0].secret_ciphertext,secret);
    assert.ok(stored.rows[0].enrolled_at);
    assert.equal(stored.rows[0].recovery_code_hashes.length,10);
    assert.ok(!stored.rows[0].recovery_code_hashes.includes(recovery.codes[0]));
    assert.equal(Number(stored.rows[0].last_totp_counter),enrollmentCounter);

    const mfaAudit=await pool.query(
      `SELECT action,meta FROM audit_logs WHERE actor_id=$1 AND action IN ('ADMIN_MFA_SETUP_STARTED','ADMIN_MFA_ENROLLED') ORDER BY created_at`,
      [userId],
    );
    assert.deepEqual(mfaAudit.rows.map((row)=>row.action),['ADMIN_MFA_SETUP_STARTED','ADMIN_MFA_ENROLLED']);
    assert.equal(mfaAudit.rows[1]?.meta?.recoveryCodesIssued,10);

    assert.equal(await repository.consumeAdminTotpCounter(userId,enrollmentCounter),false,
      'the enrollment counter must not be accepted for panel unlock again');
    assert.equal(await repository.consumeAdminTotpCounter(userId,enrollmentCounter+1),true);
    assert.equal(await repository.consumeAdminTotpCounter(userId,enrollmentCounter+1),false,
      'the same TOTP counter must not be accepted twice');

    const recoveryHash = mfa.hashRecoveryCode(recovery.codes[0]);
    assert.equal(await repository.consumeAdminRecoveryCode(userId,recoveryHash),true);
    assert.equal(await repository.consumeAdminRecoveryCode(userId,recoveryHash),false,
      'a recovery code must be single-use');
    const afterRecovery = await repository.getAdminMfaCredential(userId);
    assert.equal(afterRecovery.recoveryCodeHashes.length,9);

    assert.ok(await repository.setAdminPanelVerified(userId,jti,'WRITE'));
    assert.equal(await repository.isAdminPanelVerified(userId,5,jti,'WRITE'),true);
    assert.equal(await repository.isAdminPanelVerified(userId,15,jti,'READ'),true);
    assert.equal(await repository.isAdminPanelVerified(userId,15,'different-session','READ'),false);

    await pool.query(
      `UPDATE users SET admin_panel_verified_at=NOW()-INTERVAL '6 minutes' WHERE id=$1`,
      [userId],
    );
    assert.equal(await repository.isAdminPanelVerified(userId,15,jti,'READ'),true,
      'a six-minute-old WRITE proof remains within the 15-minute read window');
    assert.equal(await repository.isAdminPanelVerified(userId,5,jti,'WRITE'),false,
      'a six-minute-old WRITE proof must not authorize another mutation');

    assert.ok(await repository.setAdminPanelVerified(userId,jti,'READ'));
    assert.equal(await repository.isAdminPanelVerified(userId,15,jti,'READ'),true);
    assert.equal(await repository.isAdminPanelVerified(userId,5,jti,'WRITE'),false,
      'a READ proof must never authorize a write');
  } finally {
    await pool.query('DELETE FROM users WHERE id=$1',[userId]);
  }
});

after(async () => {
  if (enabled) await dbModule.db.close();
});

test('PostgreSQL MFA enrollment completion fails when the administrator role is revoked after setup starts', {
  skip:!enabled,
  timeout:30_000,
}, async () => {
  const userId=crypto.randomUUID();
  const email=`admin-mfa-revoked-${userId}@example.test`;
  const encryptionKey='hope-postgres-mfa-encryption-key-with-adequate-entropy';
  const secret=mfa.generateTotpSecret();
  const ciphertext=mfa.encryptTotpSecret(secret,encryptionKey);
  const expiresAt=new Date(Date.now()+10*60_000).toISOString();
  const recovery=mfa.generateRecoveryCodes(10);
  const counter=Math.floor(Date.now()/30_000);
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at,google_subject)
     VALUES($1,$2,'integration-hash','Revoked MFA Admin','ADMIN','ACTIVE',0,NOW(),$3)`,
    [userId,email,`google-${userId}`],
  );
  try {
    assert.equal(await repository.beginAdminMfaEnrollment(userId,ciphertext,expiresAt),true);
    await pool.query("UPDATE users SET role='USER',session_version=session_version+1,admin_panel_verified_at=NULL,admin_panel_verified_session_jti=NULL,admin_panel_verified_scope=NULL WHERE id=$1",[userId]);
    assert.equal(await repository.completeAdminMfaEnrollment(userId,{
      secretCiphertext:ciphertext,
      recoveryCodeHashes:recovery.hashes,
      lastTotpCounter:counter,
    }),false,'a user whose ADMIN role was revoked must not complete administrator MFA enrollment');
    const stored=await pool.query(
      'SELECT enrolled_at,pending_secret_ciphertext,recovery_code_hashes FROM admin_mfa_credentials WHERE user_id=$1',
      [userId],
    );
    assert.equal(stored.rows.length,1);
    assert.equal(stored.rows[0].enrolled_at,null);
    assert.equal(stored.rows[0].pending_secret_ciphertext,ciphertext,
      'the incomplete setup remains pending rather than being activated for a non-admin account');
    assert.equal(stored.rows[0].recovery_code_hashes.length,0);
  } finally {
    await pool.query('DELETE FROM users WHERE id=$1',[userId]).catch(()=>{});
  }
});
