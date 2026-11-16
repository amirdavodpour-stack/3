export const migration = {
  version: 41,
  name: 'admin_panel_session_binding',
  async up(client) {
    await client.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS admin_panel_verified_session_jti TEXT NULL;
      CREATE INDEX IF NOT EXISTS users_admin_panel_verified_session_idx
        ON users(id,admin_panel_verified_session_jti)
        WHERE admin_panel_verified_session_jti IS NOT NULL;
    `);
  },
  async down(client) {
    await client.query(`
      DROP INDEX IF EXISTS users_admin_panel_verified_session_idx;
      ALTER TABLE users
        DROP COLUMN IF EXISTS admin_panel_verified_session_jti;
    `);
  },
};
