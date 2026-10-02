export const migration = {
  version: 31,
  name: 'admin_panel_verification',
  async up(client) {
    await client.query(`
      ALTER TABLE users
        ADD COLUMN IF NOT EXISTS admin_panel_verified_at TIMESTAMPTZ NULL;
      CREATE INDEX IF NOT EXISTS users_admin_panel_verified_idx
        ON users(role,admin_panel_verified_at);
    `);
  },
  async down(client) {
    await client.query(`
      DROP INDEX IF EXISTS users_admin_panel_verified_idx;
      ALTER TABLE users DROP COLUMN IF EXISTS admin_panel_verified_at;
    `);
  },
};