export const migration = {
  version: 44,
  name: 'admin_mfa_credentials_and_step_up_scope',
  async up(client) {
    await client.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS admin_panel_verified_scope TEXT NULL;
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conrelid='users'::regclass
            AND conname='users_admin_panel_verified_scope_check'
        ) THEN
          ALTER TABLE users
            ADD CONSTRAINT users_admin_panel_verified_scope_check
            CHECK (admin_panel_verified_scope IS NULL OR admin_panel_verified_scope IN ('READ','WRITE'));
        END IF;
      END $$;
      UPDATE users
         SET admin_panel_verified_at=NULL,
             admin_panel_verified_session_jti=NULL,
             admin_panel_verified_scope=NULL
       WHERE admin_panel_verified_at IS NOT NULL
          OR admin_panel_verified_session_jti IS NOT NULL;

      CREATE TABLE IF NOT EXISTS admin_mfa_credentials (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        secret_ciphertext TEXT NULL,
        pending_secret_ciphertext TEXT NULL,
        pending_expires_at TIMESTAMPTZ NULL,
        recovery_code_hashes JSONB NOT NULL DEFAULT '[]'::jsonb,
        last_totp_counter BIGINT NOT NULL DEFAULT -1,
        enrolled_at TIMESTAMPTZ NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT admin_mfa_recovery_codes_array_check
          CHECK (jsonb_typeof(recovery_code_hashes)='array'),
        CONSTRAINT admin_mfa_pending_pair_check
          CHECK (
            (pending_secret_ciphertext IS NULL AND pending_expires_at IS NULL)
            OR
            (pending_secret_ciphertext IS NOT NULL AND pending_expires_at IS NOT NULL)
          ),
        CONSTRAINT admin_mfa_enrollment_state_check
          CHECK (
            (enrolled_at IS NULL AND secret_ciphertext IS NULL)
            OR
            (enrolled_at IS NOT NULL AND secret_ciphertext IS NOT NULL)
          )
      );
      CREATE INDEX IF NOT EXISTS admin_mfa_enrollment_expiry_idx
        ON admin_mfa_credentials(pending_expires_at)
        WHERE pending_secret_ciphertext IS NOT NULL;
    `);
  },
  async down(client) {
    const { rows } = await client.query(`
      SELECT EXISTS(
        SELECT 1 FROM admin_mfa_credentials
        WHERE enrolled_at IS NOT NULL
           OR pending_secret_ciphertext IS NOT NULL
           OR jsonb_array_length(recovery_code_hashes)>0
      ) AS has_mfa_state
    `);
    if (rows[0]?.has_mfa_state) {
      throw new Error('Cannot rollback admin MFA migration while enrollment or recovery state exists');
    }
    await client.query(`
      DROP INDEX IF EXISTS admin_mfa_enrollment_expiry_idx;
      DROP TABLE IF EXISTS admin_mfa_credentials;
      ALTER TABLE users DROP CONSTRAINT IF EXISTS users_admin_panel_verified_scope_check;
      ALTER TABLE users DROP COLUMN IF EXISTS admin_panel_verified_scope;
    `);
  },
};
