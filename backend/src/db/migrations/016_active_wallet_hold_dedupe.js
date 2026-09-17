export const migration = {
  version: 16,
  name: 'active_wallet_hold_dedupe',
  async up(client) {
    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS wallet_holds_active_reference_uq
      ON wallet_holds(reference_type, reference_id)
      WHERE status='ACTIVE' AND reference_id IS NOT NULL;
    `);
  },
  async down(client) {
    await client.query(`DROP INDEX IF EXISTS wallet_holds_active_reference_uq;`);
  },
};
