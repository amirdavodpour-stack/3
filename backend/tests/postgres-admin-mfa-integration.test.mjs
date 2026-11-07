import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { migration as recoveryDeliveryMigration } from '../src/db/migrations/051_admin_mfa_recovery_code_delivery.js';

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
    assert.equal(await repository.beginAdminMfaEnrollment(userId,ciphertext,expiresAt,null,null,0),false,
      'MFA setup must require a non-empty authenticated session JTI');
    assert.equal(await repository.beginAdminMfaEnrollment(userId,ciphertext,expiresAt,null,jti,null),false,
      'MFA setup must reject a missing session version rather than coercing null to zero');
    assert.equal(await repository.getAdminMfaCredential(userId),null,
      'rejected setup attempts must not persist pending MFA credentials');
    assert.equal(await repository.beginAdminMfaEnrollment(userId,ciphertext,expiresAt,{expiresInMinutes:10,sessionJti:jti},jti,0),true,
      'MFA setup accepts an authenticated JTI and the current explicit session version');

    const pending = await repository.getAdminMfaCredential(userId);
    assert.equal(pending.pendingSecretCiphertext,ciphertext);
    assert.equal(mfa.decryptTotpSecret(pending.pendingSecretCiphertext,encryptionKey),secret);

    const enrollmentCounter = Math.floor(Date.now()/30_000);
    const recovery = mfa.generateRecoveryCodes(10);
    const recoveryCiphertext = mfa.encryptRecoveryCodes(recovery.codes,encryptionKey);
    const recoveryDeliveryId = crypto.randomUUID();
    assert.equal(await repository.completeAdminMfaEnrollment(userId,{
      secretCiphertext:ciphertext,
      recoveryCodeHashes:recovery.hashes,
      recoveryCodesCiphertext:recoveryCiphertext,
      recoveryDeliveryId,
      lastTotpCounter:enrollmentCounter,
      sessionJti:jti,
      sessionVersion:null,
      auditMeta:{recoveryCodesIssued:recovery.codes.length,sessionJti:jti},
    }),false,'MFA confirmation must reject a missing session version rather than coercing null to zero');
    assert.equal((await repository.getAdminMfaCredential(userId)).pendingSecretCiphertext,ciphertext,
      'a rejected session provenance check must leave the pending enrollment intact');
    assert.equal(await repository.completeAdminMfaEnrollment(userId,{
      secretCiphertext:ciphertext,
      recoveryCodeHashes:recovery.hashes,
      recoveryCodesCiphertext:recoveryCiphertext,
      recoveryDeliveryId,
      lastTotpCounter:enrollmentCounter,
      sessionJti:jti,
      sessionVersion:0,
      auditMeta:{recoveryCodesIssued:recovery.codes.length,sessionJti:jti},
    }),true);

    const stored = await pool.query(
      `SELECT secret_ciphertext,recovery_code_hashes,recovery_codes_ciphertext,recovery_delivery_id,recovery_codes_acknowledged_at,last_totp_counter,enrolled_at
         FROM admin_mfa_credentials WHERE user_id=$1`,
      [userId],
    );
    assert.equal(stored.rows.length,1);
    assert.notEqual(stored.rows[0].secret_ciphertext,secret);
    assert.ok(stored.rows[0].enrolled_at);
    assert.equal(stored.rows[0].recovery_code_hashes.length,10);
    assert.ok(!stored.rows[0].recovery_code_hashes.includes(recovery.codes[0]));
    assert.notEqual(stored.rows[0].recovery_codes_ciphertext,JSON.stringify(recovery.codes));
    assert.deepEqual(mfa.decryptRecoveryCodes(stored.rows[0].recovery_codes_ciphertext,encryptionKey),recovery.codes);
    assert.equal(stored.rows[0].recovery_delivery_id,recoveryDeliveryId);
    assert.equal(stored.rows[0].recovery_codes_acknowledged_at,null);
    assert.equal(await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+1,'',0),null,
      'recovery retrieval must reject a missing session JTI without consuming the TOTP counter');
    assert.equal(await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+1,jti,null),null,
      'recovery retrieval must reject a missing session version rather than coercing null to zero');
    const firstDelivery=await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+1,jti,0);
    assert.equal(firstDelivery.ciphertext,stored.rows[0].recovery_codes_ciphertext);
    assert.equal(firstDelivery.deliveryId,recoveryDeliveryId);
    assert.equal(await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+1,jti,0),null,'the same TOTP counter must not retrieve recovery codes twice');
    const retryDelivery=await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+2,jti,0);
    assert.deepEqual(retryDelivery,firstDelivery,'a fresh TOTP counter may retry the same encrypted bundle after a lost response');
    assert.equal(await repository.acknowledgeAdminMfaRecoveryDelivery(userId,'',0,recoveryDeliveryId),false,
      'recovery ACK must reject a missing session JTI');
    assert.equal(await repository.acknowledgeAdminMfaRecoveryDelivery(userId,jti,null,recoveryDeliveryId),false,
      'recovery ACK must reject a missing session version rather than coercing null to zero');
    assert.ok((await repository.getAdminMfaCredential(userId)).recoveryCodesCiphertext,
      'rejected recovery ACK attempts must preserve the encrypted delivery bundle');
    await pool.query('UPDATE users SET session_version=1 WHERE id=$1',[userId]);
    assert.equal(await repository.acknowledgeAdminMfaRecoveryDelivery(userId,jti,0,recoveryDeliveryId),false,'a revoked access-token session cannot acknowledge delivery');
    assert.equal(await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+3,jti,0),null,'a revoked access-token session cannot retrieve codes');
    const renewedJti=crypto.randomUUID();
    const renewedDelivery=await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+3,renewedJti,1);
    assert.deepEqual(renewedDelivery,firstDelivery,'a new current session can resume the pending delivery');
    assert.equal(await repository.acknowledgeAdminMfaRecoveryDelivery(userId,renewedJti,1,recoveryDeliveryId),true);
    assert.equal(await repository.acknowledgeAdminMfaRecoveryDelivery(userId,renewedJti,1,recoveryDeliveryId),true,'ACK is idempotent after its HTTP response is lost');
    assert.equal(await repository.consumeAdminMfaRecoveryDelivery(userId,enrollmentCounter+3,jti,0),null,'acknowledged bundles cannot be retrieved again');
    const afterDeliveryAck=await repository.getAdminMfaCredential(userId);
    assert.equal(afterDeliveryAck.recoveryCodesCiphertext,null);
    assert.ok(afterDeliveryAck.recoveryCodesAcknowledgedAt);
    assert.equal((await repository.getAdminMfaStatus(userId)).recoveryCodesDeliveryPending,false);
    await assert.rejects(
      recoveryDeliveryMigration.down(pool),
      /Cannot rollback MFA recovery delivery while delivery state exists/,
      'the forward migration refuses rollback after a recovery delivery has been acknowledged',
    );
    assert.equal(Number(stored.rows[0].last_totp_counter),enrollmentCounter);

    const mfaAudit=await pool.query(
      `SELECT action,meta FROM audit_logs WHERE actor_id=$1 AND action IN ('ADMIN_MFA_SETUP_STARTED','ADMIN_MFA_ENROLLED') ORDER BY created_at`,
      [userId],
    );
    assert.deepEqual(mfaAudit.rows.map((row)=>row.action),['ADMIN_MFA_SETUP_STARTED','ADMIN_MFA_ENROLLED']);
    assert.equal(mfaAudit.rows[0]?.meta?.sessionJti,jti,'MFA setup audit records the authenticated session JTI');
    assert.equal(mfaAudit.rows[1]?.meta?.recoveryCodesIssued,10);
    assert.equal(mfaAudit.rows[1]?.meta?.sessionJti,jti,'MFA enrollment audit records the authenticated session JTI');
    const recoveryAudit=await pool.query(
      `SELECT action,meta FROM audit_logs WHERE actor_id=$1 AND action IN ('ADMIN_MFA_RECOVERY_CODES_RETRIEVED','ADMIN_MFA_RECOVERY_CODES_ACKNOWLEDGED') ORDER BY created_at`,
      [userId],
    );
    const retrievalAudit=recoveryAudit.rows.filter((row)=>row.action==='ADMIN_MFA_RECOVERY_CODES_RETRIEVED');
    const acknowledgementAudit=recoveryAudit.rows.filter((row)=>row.action==='ADMIN_MFA_RECOVERY_CODES_ACKNOWLEDGED');
    assert.equal(retrievalAudit.length,3,'each successful initial/retry/resumed retrieval is audited once');
    assert.equal(retrievalAudit.filter((row)=>row.meta?.sessionJti===jti).length,2,
      'both retrievals in the original session record its exact JTI');
    assert.equal(retrievalAudit.filter((row)=>row.meta?.sessionJti===renewedJti).length,1,
      'the resumed retrieval records the renewed session JTI');
    assert.equal(acknowledgementAudit.length,1,'idempotent ACK writes exactly one audit event');
    assert.equal(acknowledgementAudit[0]?.meta?.sessionJti,renewedJti,
      'recovery acknowledgement audit records the current session JTI');

    assert.equal(await repository.consumeAdminTotpCounter(userId,enrollmentCounter),false,
      'the enrollment counter must not be accepted for panel unlock again');
    assert.equal(await repository.consumeAdminTotpCounter(userId,enrollmentCounter+4),true);
    assert.equal(await repository.consumeAdminTotpCounter(userId,enrollmentCounter+4),false,
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
  const revokedSessionJti=`revoked-admin-mfa-session-${userId}`;
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at,google_subject)
     VALUES($1,$2,'integration-hash','Revoked MFA Admin','ADMIN','ACTIVE',0,NOW(),$3)`,
    [userId,email,`google-${userId}`],
  );
  try {
    assert.equal(await repository.beginAdminMfaEnrollment(userId,ciphertext,expiresAt,null,revokedSessionJti,0),true);
    await pool.query("UPDATE users SET role='USER',session_version=session_version+1,admin_panel_verified_at=NULL,admin_panel_verified_session_jti=NULL,admin_panel_verified_scope=NULL WHERE id=$1",[userId]);
    assert.equal(await repository.completeAdminMfaEnrollment(userId,{
      secretCiphertext:ciphertext,
      recoveryCodeHashes:recovery.hashes,
      recoveryCodesCiphertext:mfa.encryptRecoveryCodes(recovery.codes,encryptionKey),
      recoveryDeliveryId:crypto.randomUUID(),
      lastTotpCounter:counter,
      sessionJti:revokedSessionJti,
      sessionVersion:0,
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

test('PostgreSQL MFA setup and completion reject a revoked session version while preserving pending enrollment', {
  skip:!enabled,
  timeout:30_000,
}, async()=>{
  const userId=crypto.randomUUID();
  const email=`admin-mfa-session-revoked-${userId}@example.test`;
  const encryptionKey='hope-postgres-mfa-encryption-key-with-adequate-entropy';
  const oldSessionJti=`admin-mfa-session-${userId}`;
  const secret=mfa.generateTotpSecret();
  const ciphertext=mfa.encryptTotpSecret(secret,encryptionKey);
  const expiresAt=new Date(Date.now()+10*60_000).toISOString();
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at,google_subject)
     VALUES($1,$2,'integration-hash','Revoked Session MFA Admin','ADMIN','ACTIVE',0,NOW(),$3)`,
    [userId,email,`google-${userId}`],
  );
  try {
    assert.equal(await repository.beginAdminMfaEnrollment(userId,ciphertext,expiresAt,null,oldSessionJti,0),true);
    await pool.query('UPDATE users SET session_version=1 WHERE id=$1',[userId]);
    assert.equal(
      await repository.beginAdminMfaEnrollment(userId,mfa.encryptTotpSecret(mfa.generateTotpSecret(),encryptionKey),expiresAt,null,oldSessionJti,0),
      false,
      'a revoked session cannot replace the pending MFA secret',
    );
    const recovery=mfa.generateRecoveryCodes(10);
    assert.equal(await repository.completeAdminMfaEnrollment(userId,{
      secretCiphertext:ciphertext,
      recoveryCodeHashes:recovery.hashes,
      recoveryCodesCiphertext:mfa.encryptRecoveryCodes(recovery.codes,encryptionKey),
      recoveryDeliveryId:crypto.randomUUID(),
      lastTotpCounter:Math.floor(Date.now()/30_000),
      sessionJti:oldSessionJti,
      sessionVersion:0,
    }),false,'a revoked session cannot activate MFA');
    const stored=await repository.getAdminMfaCredential(userId);
    assert.equal(stored.enrolledAt,null);
    assert.equal(stored.pendingSecretCiphertext,ciphertext);
  } finally {
    await pool.query('DELETE FROM users WHERE id=$1',[userId]);
  }
});


test('PostgreSQL MFA factor consumption, exact-session unlock and audit commit or roll back together', {
  skip:!enabled,
  timeout:30_000,
}, async () => {
  const userId=crypto.randomUUID();
  const email=`admin-mfa-unlock-atomic-${userId}@example.test`;
  const sessionJti=`admin-mfa-unlock-session-${userId}`;
  const encryptionKey='hope-postgres-mfa-encryption-key-with-adequate-entropy';
  const secret=mfa.generateTotpSecret();
  const secretCiphertext=mfa.encryptTotpSecret(secret,encryptionKey);
  const nowMs=Date.now();
  const counter=Math.floor(nowMs/30_000);
  const totpCode=mfa.generateTotpCode(secret,nowMs);
  const factor=mfa.verifyTotpCode(secret,totpCode,nowMs,{lastAcceptedCounter:counter-1});
  assert.equal(factor.valid,true);
  const recovery=mfa.generateRecoveryCodes(10);
  const recoveryCiphertext=mfa.encryptRecoveryCodes(recovery.codes,encryptionKey);
  const deliveryId=crypto.randomUUID();
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at,google_subject)
     VALUES($1,$2,'integration-hash','Atomic MFA Unlock Admin','ADMIN','ACTIVE',0,NOW(),$3)`,
    [userId,email,`google-${userId}`],
  );
  const functionName=`fail_mfa_unlock_audit_${userId.replaceAll('-','')}`;
  const triggerName=`fail_mfa_unlock_audit_trigger_${userId.replaceAll('-','')}`;

  try {
    assert.equal(await repository.beginAdminMfaEnrollment(
      userId,secretCiphertext,new Date(nowMs+10*60_000).toISOString(),
      {expiresInMinutes:10,sessionJti},sessionJti,0,
    ),true);
    assert.equal(await repository.completeAdminMfaEnrollment(userId,{
      secretCiphertext,
      recoveryCodeHashes:recovery.hashes,
      recoveryCodesCiphertext:recoveryCiphertext,
      recoveryDeliveryId:deliveryId,
      lastTotpCounter:counter-1,
      sessionJti,
      sessionVersion:0,
      auditMeta:{recoveryCodesIssued:10,sessionJti},
    }),true);
    await pool.query(
      `UPDATE admin_mfa_credentials
          SET recovery_codes_ciphertext=NULL,
              recovery_codes_acknowledged_at=NOW()
        WHERE user_id=$1`,
      [userId],
    );

    await pool.query(`CREATE FUNCTION ${functionName}() RETURNS trigger AS $body$
      BEGIN
        IF NEW.action='ADMIN_PANEL_UNLOCK' AND NEW.actor_id::text=TG_ARGV[0] THEN
          RAISE EXCEPTION 'R05 forced ADMIN_PANEL_UNLOCK audit failure';
        END IF;
        RETURN NEW;
      END;
    $body$ LANGUAGE plpgsql`);
    await pool.query(
      `CREATE TRIGGER ${triggerName} BEFORE INSERT ON audit_logs
       FOR EACH ROW EXECUTE FUNCTION ${functionName}('${userId}')`,
    );

    await assert.rejects(
      repository.verifyAdminPanelMfaAndUnlock(userId,{
        sessionJti,
        sessionVersion:0,
        scope:'WRITE',
        factor:{method:'totp',counter:factor.counter,secretCiphertext},
        auditMeta:{expiresInMinutes:5,method:'password',mfaMethod:'totp'},
      }),
      /R05 forced ADMIN_PANEL_UNLOCK audit failure/,
      'an audit failure must abort factor consumption and unlock state together',
    );

    const {rows:afterRollback}=await pool.query(
      `SELECT c.last_totp_counter,u.admin_panel_verified_at,
              u.admin_panel_verified_session_jti,u.admin_panel_verified_scope
         FROM admin_mfa_credentials c
         JOIN users u ON u.id=c.user_id
        WHERE c.user_id=$1`,
      [userId],
    );
    assert.equal(Number(afterRollback[0].last_totp_counter),counter-1,
      'the TOTP counter must remain reusable when the unlock audit rolls back');
    assert.equal(afterRollback[0].admin_panel_verified_at,null);
    assert.equal(afterRollback[0].admin_panel_verified_session_jti,null);
    assert.equal(afterRollback[0].admin_panel_verified_scope,null);
    const {rows:missingAudit}=await pool.query(
      `SELECT id FROM audit_logs WHERE action='ADMIN_PANEL_UNLOCK' AND actor_id=$1`,
      [userId],
    );
    assert.equal(missingAudit.length,0);

    await pool.query(`DROP TRIGGER ${triggerName} ON audit_logs`);
    await pool.query(`DROP FUNCTION ${functionName}()`);
    const unlocked=await repository.verifyAdminPanelMfaAndUnlock(userId,{
      sessionJti,
      sessionVersion:0,
      scope:'WRITE',
      factor:{method:'totp',counter:factor.counter,secretCiphertext},
      auditMeta:{expiresInMinutes:5,method:'password',mfaMethod:'totp'},
    });
    assert.ok(unlocked);
    assert.equal(unlocked.scope,'WRITE');

    const {rows:afterCommit}=await pool.query(
      `SELECT c.last_totp_counter,u.admin_panel_verified_session_jti,
              u.admin_panel_verified_scope,a.action,a.meta
         FROM admin_mfa_credentials c
         JOIN users u ON u.id=c.user_id
         JOIN audit_logs a ON a.actor_id=u.id
        WHERE c.user_id=$1 AND a.action='ADMIN_PANEL_UNLOCK'`,
      [userId],
    );
    assert.equal(afterCommit.length,1);
    assert.equal(Number(afterCommit[0].last_totp_counter),factor.counter);
    assert.equal(afterCommit[0].admin_panel_verified_session_jti,sessionJti);
    assert.equal(afterCommit[0].admin_panel_verified_scope,'WRITE');
    assert.equal(afterCommit[0].action,'ADMIN_PANEL_UNLOCK');
    assert.equal(afterCommit[0].meta.sessionJti,sessionJti);
    assert.equal(afterCommit[0].meta.mfaMethod,'totp');

    assert.equal(await repository.verifyAdminPanelMfaAndUnlock(userId,{
      sessionJti,
      sessionVersion:0,
      scope:'WRITE',
      factor:{method:'totp',counter:factor.counter,secretCiphertext},
      auditMeta:{expiresInMinutes:5,method:'password',mfaMethod:'totp'},
    }),null,'a successfully consumed TOTP counter cannot unlock the panel twice');
  } finally {
    await pool.query(`DROP TRIGGER IF EXISTS ${triggerName} ON audit_logs`).catch(()=>{});
    await pool.query(`DROP FUNCTION IF EXISTS ${functionName}()`).catch(()=>{});
    await pool.query('DELETE FROM audit_logs WHERE actor_id=$1 OR entity_id=$1',[userId]).catch(()=>{});
    await pool.query('DELETE FROM users WHERE id=$1',[userId]).catch(()=>{});
  }
});
