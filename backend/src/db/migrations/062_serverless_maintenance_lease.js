export const migration = {
  version: 62,
  name: 'serverless_maintenance_lease',
  async up(client) {
    await client.query(`
      CREATE TABLE maintenance_leases (
        lock_name TEXT PRIMARY KEY,
        owner_request_id UUID NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT maintenance_leases_single_lock_name_check
          CHECK (lock_name = 'serverless-maintenance')
      );
      CREATE INDEX maintenance_leases_expires_at_idx ON maintenance_leases(expires_at);
    `);
  },
  async down(client) {
    const { rows } = await client.query('SELECT 1 FROM maintenance_leases LIMIT 1');
    if (rows.length) {
      throw new Error('Cannot rollback serverless maintenance lease while a lease record exists');
    }
    await client.query('DROP TABLE maintenance_leases');
  },
};
