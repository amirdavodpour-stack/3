import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';
import { lockAuthorizedAdminActor } from './admin_authorization.js';

function normalizeHashes(values) {
  if (!Array.isArray(values) || values.length > 20) throw new TypeError('Invalid recovery-code hash list');
  const hashes = values.map((value) => String(value ?? '').trim().toLowerCase());
  if (hashes.some((value) => !/^[a-f0-9]{64}$/.test(value)) || new Set(hashes).size !== hashes.length) {
    throw new TypeError('Invalid recovery-code hash list');
  }
  return hashes;
}

export async function getAdminMfaStatus(userId) {
  const { rows } = await requirePool().query(
    `SELECT enrolled_at,pending_expires_at,recovery_codes_ciphertext,
            jsonb_array_length(recovery_code_hashes)::int AS recovery_codes_remaining
       FROM admin_mfa_credentials WHERE user_id=$1`,
    [userId],
  );
  const row = rows[0];
  return {
    enabled: Boolean(row?.enrolled_at),
    enrollmentPending: Boolean(row?.pending_expires_at),
    pendingExpiresAt: row?.pending_expires_at?.toISOString?.() ?? row?.pending_expires_at ?? null,
    recoveryCodesRemaining: Number(row?.recovery_codes_remaining || 0),
    recoveryCodesDeliveryPending: Boolean(row?.recovery_codes_ciphertext),
  };
}

export async function getAdminMfaCredential(userId) {
  const { rows } = await requirePool().query(
    `SELECT secret_ciphertext,pending_secret_ciphertext,pending_expires_at,
            recovery_code_hashes,last_totp_counter,enrolled_at,
            recovery_codes_ciphertext,recovery_delivery_id,recovery_codes_acknowledged_at
       FROM admin_mfa_credentials WHERE user_id=$1`,
    [userId],
  );
  const row = rows[0];
  if (!row) return null;
  return {
    secretCiphertext: row.secret_ciphertext,
    pendingSecretCiphertext: row.pending_secret_ciphertext,
    pendingExpiresAt: row.pending_expires_at?.toISOString?.() ?? row.pending_expires_at ?? null,
    recoveryCodeHashes: Array.isArray(row.recovery_code_hashes) ? row.recovery_code_hashes : [],
    lastTotpCounter: Number(row.last_totp_counter ?? -1),
    enrolledAt: row.enrolled_at?.toISOString?.() ?? row.enrolled_at ?? null,
    recoveryCodesCiphertext: row.recovery_codes_ciphertext ?? null,
    recoveryDeliveryId: row.recovery_delivery_id ?? null,
    recoveryCodesAcknowledgedAt: row.recovery_codes_acknowledged_at?.toISOString?.() ?? row.recovery_codes_acknowledged_at ?? null,
  };
}

export async function beginAdminMfaEnrollment(userId, encryptedPendingSecret, expiresAt, auditMeta = null, sessionJti = null, sessionVersion = null) {
  const ciphertext = String(encryptedPendingSecret ?? '').trim();
  const expiry = new Date(expiresAt);
  const sessionId = String(sessionJti ?? '').trim();
  const version = Number(sessionVersion);
  if (!ciphertext || ciphertext.length > 2048 || !Number.isFinite(expiry.getTime()) ||
      !sessionId || sessionVersion === null || sessionVersion === undefined || !Number.isSafeInteger(version)) return false;
  return withSqlTransaction(async (client) => {
    try {
      await lockAuthorizedAdminActor(client,{actorId:userId,sessionJti:sessionId,requireStepUp:false});
    } catch (error) {
      if (['ADMIN_REQUIRED','PRIMARY_ADMIN_IDENTITY_REQUIRED'].includes(error?.code)) return false;
      throw error;
    }
    const {rows:sessionRows}=await client.query('SELECT session_version FROM users WHERE id=$1',[userId]);
    if(!sessionRows[0] || Number(sessionRows[0].session_version)!==version) return false;
    const { rows } = await client.query(
      `INSERT INTO admin_mfa_credentials(
         user_id,pending_secret_ciphertext,pending_expires_at,updated_at
       ) VALUES($1,$2,$3,NOW())
       ON CONFLICT(user_id) DO UPDATE
         SET pending_secret_ciphertext=EXCLUDED.pending_secret_ciphertext,
             pending_expires_at=EXCLUDED.pending_expires_at,
             updated_at=NOW()
       WHERE admin_mfa_credentials.enrolled_at IS NULL
       RETURNING user_id`,
      [userId,ciphertext,expiry],
    );
    if(rows.length===1 && auditMeta) {
      await client.query(
        `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
         VALUES(gen_random_uuid(),'ADMIN_MFA_SETUP_STARTED',$1,'admin',$1,$2::jsonb,NOW())`,
        [userId,JSON.stringify(auditMeta)],
      );
    }
    return rows.length === 1;
  });
}

export async function completeAdminMfaEnrollment(userId, {
  secretCiphertext,
  recoveryCodeHashes,
  recoveryCodesCiphertext,
  recoveryDeliveryId,
  lastTotpCounter,
  sessionJti,
  sessionVersion,
  auditMeta = null,
} = {}) {
  const ciphertext = String(secretCiphertext ?? '').trim();
  const hashes = normalizeHashes(recoveryCodeHashes);
  const counter = Number(lastTotpCounter);
  const recoveryCiphertext = String(recoveryCodesCiphertext ?? '').trim();
  const deliveryId = String(recoveryDeliveryId ?? '').trim().toLowerCase();
  const sessionId = String(sessionJti ?? '').trim();
  const version = Number(sessionVersion);
  if (!ciphertext || ciphertext.length > 2048 || !recoveryCiphertext || !deliveryId ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(deliveryId) ||
      recoveryCiphertext.length > 4096 || !Number.isSafeInteger(counter) || counter < 0 || hashes.length !== 10 ||
      !sessionId || sessionVersion === null || sessionVersion === undefined || !Number.isSafeInteger(version)) return false;
  return withSqlTransaction(async (client) => {
    try {
      await lockAuthorizedAdminActor(client,{actorId:userId,sessionJti:sessionId,requireStepUp:false});
    } catch (error) {
      if (['ADMIN_REQUIRED','PRIMARY_ADMIN_IDENTITY_REQUIRED'].includes(error?.code)) return false;
      throw error;
    }
    const {rows:sessionRows}=await client.query('SELECT session_version FROM users WHERE id=$1',[userId]);
    if(!sessionRows[0] || Number(sessionRows[0].session_version)!==version) return false;
    const { rows } = await client.query(
      `SELECT pending_secret_ciphertext,pending_expires_at,enrolled_at
         FROM admin_mfa_credentials WHERE user_id=$1 FOR UPDATE`,
      [userId],
    );
    const row = rows[0];
    if (
      !row ||
      row.enrolled_at ||
      row.pending_secret_ciphertext !== ciphertext ||
      !row.pending_expires_at ||
      new Date(row.pending_expires_at).getTime() <= Date.now()
    ) return false;
    const { rowCount } = await client.query(
      `UPDATE admin_mfa_credentials
          SET secret_ciphertext=$2,
              pending_secret_ciphertext=NULL,
              pending_expires_at=NULL,
              recovery_code_hashes=$3::jsonb,
              recovery_codes_ciphertext=$4,
              recovery_delivery_id=$5,
              recovery_codes_acknowledged_at=NULL,
              last_totp_counter=$6,
              enrolled_at=NOW(),
              updated_at=NOW()
        WHERE user_id=$1 AND enrolled_at IS NULL`,
      [userId,ciphertext,JSON.stringify(hashes),recoveryCiphertext,deliveryId,counter],
    );
    if (rowCount !== 1) return false;
    await client.query(
      `UPDATE users
          SET admin_panel_verified_at=NULL,
              admin_panel_verified_session_jti=NULL,
              admin_panel_verified_scope=NULL
        WHERE id=$1`,
      [userId],
    );
    if(auditMeta) {
      await client.query(
        `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
         VALUES(gen_random_uuid(),'ADMIN_MFA_ENROLLED',$1,'admin',$1,$2::jsonb,NOW())`,
        [userId,JSON.stringify(auditMeta)],
      );
    }
    return true;
  });
}

export async function consumeAdminMfaRecoveryDelivery(userId, counter, sessionJti, sessionVersion) {
  const value = Number(counter);
  const sessionId = String(sessionJti ?? '').trim();
  const version = Number(sessionVersion);
  if (!Number.isSafeInteger(value) || value < 0 || !sessionId ||
      sessionVersion === null || sessionVersion === undefined || !Number.isSafeInteger(version)) return null;
  return withSqlTransaction(async (client) => {
    try { await lockAuthorizedAdminActor(client,{actorId:userId,sessionJti:sessionId,requireStepUp:false}); }
    catch (error) { if (['ADMIN_REQUIRED','PRIMARY_ADMIN_IDENTITY_REQUIRED'].includes(error?.code)) return null; throw error; }
    const {rows:sessionRows}=await client.query('SELECT session_version FROM users WHERE id=$1',[userId]);
    if(!sessionRows[0] || Number(sessionRows[0].session_version)!==version) return null;
    const { rows } = await client.query(
      `SELECT recovery_codes_ciphertext,recovery_delivery_id,last_totp_counter
         FROM admin_mfa_credentials WHERE user_id=$1 AND enrolled_at IS NOT NULL FOR UPDATE`,
      [userId],
    );
    const row=rows[0];
    if (!row?.recovery_codes_ciphertext || !row.recovery_delivery_id || Number(row.last_totp_counter ?? -1) >= value) return null;
    const { rowCount } = await client.query(
      `UPDATE admin_mfa_credentials SET last_totp_counter=$2,updated_at=NOW()
        WHERE user_id=$1 AND enrolled_at IS NOT NULL AND last_totp_counter < $2`,
      [userId,value],
    );
    if(rowCount!==1) return null;
    await client.query(
      `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
       VALUES(gen_random_uuid(),'ADMIN_MFA_RECOVERY_CODES_RETRIEVED',$1,'admin',$1,$2::jsonb,NOW())`,
      [userId,JSON.stringify({deliveryId:row.recovery_delivery_id,counter:value,sessionJti:sessionId})],
    );
    return {ciphertext:row.recovery_codes_ciphertext,deliveryId:row.recovery_delivery_id};
  });
}

export async function acknowledgeAdminMfaRecoveryDelivery(userId, sessionJti, sessionVersion, deliveryId) {
  const receipt=String(deliveryId??'').trim().toLowerCase();
  const sessionId = String(sessionJti ?? '').trim();
  const version = Number(sessionVersion);
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(receipt) ||
      !sessionId || sessionVersion === null || sessionVersion === undefined || !Number.isSafeInteger(version)) return false;
  return withSqlTransaction(async(client)=>{
    try { await lockAuthorizedAdminActor(client,{actorId:userId,sessionJti:sessionId,requireStepUp:false}); }
    catch(error) { if(['ADMIN_REQUIRED','PRIMARY_ADMIN_IDENTITY_REQUIRED'].includes(error?.code)) return false; throw error; }
    const {rows:sessionRows}=await client.query('SELECT session_version FROM users WHERE id=$1',[userId]);
    if(!sessionRows[0] || Number(sessionRows[0].session_version)!==version) return false;
    const {rows}=await client.query(
      `SELECT recovery_delivery_id,recovery_codes_ciphertext,recovery_codes_acknowledged_at
         FROM admin_mfa_credentials WHERE user_id=$1 AND enrolled_at IS NOT NULL FOR UPDATE`,
      [userId],
    );
    const row=rows[0];
    if(!row || row.recovery_delivery_id!==receipt) return false;
    if(row.recovery_codes_acknowledged_at) return true;
    if(!row.recovery_codes_ciphertext) return false;
    const {rowCount}=await client.query(
      `UPDATE admin_mfa_credentials
          SET recovery_codes_ciphertext=NULL,recovery_codes_acknowledged_at=NOW(),updated_at=NOW()
        WHERE user_id=$1 AND recovery_delivery_id=$2 AND recovery_codes_acknowledged_at IS NULL`,
      [userId,receipt],
    );
    if(rowCount!==1) return false;
    await client.query(
      `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
       VALUES(gen_random_uuid(),'ADMIN_MFA_RECOVERY_CODES_ACKNOWLEDGED',$1,'admin',$1,$2::jsonb,NOW())`,
      [userId,JSON.stringify({deliveryId:receipt,sessionJti:sessionId})],
    );
    return true;
  });
}
export async function consumeAdminTotpCounter(userId, counter) {
  const value = Number(counter);
  if (!Number.isSafeInteger(value) || value < 0) return false;
  const { rows } = await requirePool().query(
    `UPDATE admin_mfa_credentials
        SET last_totp_counter=$2,updated_at=NOW()
      WHERE user_id=$1 AND enrolled_at IS NOT NULL AND secret_ciphertext IS NOT NULL
        AND last_totp_counter < $2
      RETURNING user_id`,
    [userId,value],
  );
  return rows.length === 1;
}

export async function consumeAdminRecoveryCode(userId, codeHash) {
  const hash = String(codeHash ?? '').trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(hash)) return false;
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(
      `SELECT recovery_code_hashes,enrolled_at
         FROM admin_mfa_credentials WHERE user_id=$1 FOR UPDATE`,
      [userId],
    );
    const row = rows[0];
    if (!row?.enrolled_at) return false;
    const hashes = Array.isArray(row.recovery_code_hashes) ? row.recovery_code_hashes : [];
    if (!hashes.includes(hash)) return false;
    const remaining = hashes.filter((value) => value !== hash);
    const { rowCount } = await client.query(
      `UPDATE admin_mfa_credentials
          SET recovery_code_hashes=$2::jsonb,updated_at=NOW()
        WHERE user_id=$1 AND enrolled_at IS NOT NULL`,
      [userId,JSON.stringify(remaining)],
    );
    return rowCount === 1;
  });
}
