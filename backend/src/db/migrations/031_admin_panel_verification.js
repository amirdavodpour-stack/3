export const migration = {
  version: 31,
  name: 'admin_panel_verification',
  async up(client) {
    await client.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS admin_username TEXT NULL,
        ADD COLUMN IF NOT EXISTS admin_panel_verified_at TIMESTAMPTZ NULL;
      CREATE UNIQUE INDEX IF NOT EXISTS users_admin_username_uq
        ON users(LOWER(admin_username))
        WHERE admin_username IS NOT NULL AND admin_username <> '';
      CREATE INDEX IF NOT EXISTS users_admin_panel_verified_idx
        ON users(role,admin_panel_verified_at);
      UPDATE users
      SET admin_username = LOWER(SPLIT_PART(email,'@',1))
      WHERE role='ADMIN'
        AND (admin_username IS NULL OR admin_username='')
        AND email IS NOT NULL;
    `);
  },
  async down(client) {
    await client.query(`
      DROP INDEX IF EXISTS users_admin_panel_verified_idx;
      DROP INDEX IF EXISTS users_admin_username_uq;
      ALTER TABLE users
        DROP COLUMN IF EXISTS admin_panel_verified_at,
        DROP COLUMN IF EXISTS admin_username;
    `);
  },
};