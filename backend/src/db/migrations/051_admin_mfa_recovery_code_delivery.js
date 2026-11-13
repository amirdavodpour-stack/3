export const migration = {
  version: 51,
  name: 'admin_mfa_recovery_code_delivery',
  async up(client) {
    await client.query(`
      ALTER TABLE admin_mfa_credentials
        ADD COLUMN IF NOT EXISTS recovery_codes_ciphertext TEXT NULL,
        ADD COLUMN IF NOT EXISTS recovery_delivery_id UUID NULL,
        ADD COLUMN IF NOT EXISTS recovery_codes_acknowledged_at TIMESTAMPTZ NULL;
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conrelid='admin_mfa_credentials'::regclass
            AND conname='admin_mfa_recovery_delivery_pair_check'
        ) THEN
          ALTER TABLE admin_mfa_credentials
            ADD CONSTRAINT admin_mfa_recovery_delivery_pair_check
            CHECK (
              (recovery_codes_ciphertext IS NOT NULL AND recovery_delivery_id IS NOT NULL AND recovery_codes_acknowledged_at IS NULL)
              OR
              (recovery_codes_ciphertext IS NULL AND recovery_delivery_id IS NULL AND recovery_codes_acknowledged_at IS NULL)
              OR
              (recovery_codes_ciphertext IS NULL AND recovery_delivery_id IS NOT NULL AND recovery_codes_acknowledged_at IS NOT NULL)
            );
        END IF;
      END $$;
      CREATE INDEX IF NOT EXISTS admin_mfa_recovery_delivery_pending_idx
        ON admin_mfa_credentials(user_id)
        WHERE recovery_codes_ciphertext IS NOT NULL;
    `);
  },
  async down(client) {
    const { rows } = await client.query(`
      SELECT EXISTS(
        SELECT 1 FROM admin_mfa_credentials
        WHERE recovery_delivery_id IS NOT NULL
      ) AS has_delivery_state
    `);
    if (rows[0]?.has_delivery_state) {
      throw new Error('Cannot rollback MFA recovery delivery while delivery state exists');
    }
    await client.query(`
      DROP INDEX IF EXISTS admin_mfa_recovery_delivery_pending_idx;
      ALTER TABLE admin_mfa_credentials
        DROP CONSTRAINT IF EXISTS admin_mfa_recovery_delivery_pair_check,
        DROP COLUMN IF EXISTS recovery_codes_ciphertext,
        DROP COLUMN IF EXISTS recovery_delivery_id,
        DROP COLUMN IF EXISTS recovery_codes_acknowledged_at;
    `);
  },
};
