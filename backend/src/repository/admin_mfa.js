import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';

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
    `SELECT enrolled_at,pending_expires_at,
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
  };
}

export async function getAdminMfaCredential(userId) {
  const { rows } = await requirePool().query(
    `SELECT secret_ciphertext,pending_secret_ciphertext,pending_expires_at,
            recovery_code_hashes,last_totp_counter,enrolled_at
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
  };
}

export async function beginAdminMfaEnrollment(userId, encryptedPendingSecret, expiresAt) {
  const ciphertext = String(encryptedPendingSecret ?? '').trim();
  const expiry = new Date(expiresAt);
  if (!ciphertext || ciphertext.length > 2048 || !Number.isFinite(expiry.getTime())) return false;
  return withSqlTransaction(async (client) => {
    const { rows: users } = await client.query(
      `SELECT role,status FROM users WHERE id=$1 FOR UPDATE`,
      [userId],
    );
    if (!users[0] || users[0].role !== 'ADMIN' || users[0].status !== 'ACTIVE') return false;
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
    return rows.length === 1;
  });
}

export async function completeAdminMfaEnrollment(userId, {
  secretCiphertext,
  recoveryCodeHashes,
  lastTotpCounter,
} = {}) {
  const ciphertext = String(secretCiphertext ?? '').trim();
  const hashes = normalizeHashes(recoveryCodeHashes);
  const counter = Number(lastTotpCounter);
  if (!ciphertext || ciphertext.length > 2048 || !Number.isSafeInteger(counter) || counter < 0 || hashes.length !== 10) return false;
  return withSqlTransaction(async (client) => {
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
              last_totp_counter=$4,
              enrolled_at=NOW(),
              updated_at=NOW()
        WHERE user_id=$1 AND enrolled_at IS NULL`,
      [userId,ciphertext,JSON.stringify(hashes),counter],
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
