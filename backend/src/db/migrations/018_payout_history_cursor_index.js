export const migration = {
  version: 18,
  name: 'payout_history_cursor_index',
  async up(client) {
    await client.query(`CREATE INDEX IF NOT EXISTS payouts_user_created_cursor_idx ON payouts(user_id, created_at DESC, id DESC);`);
  },
  async down(client) {
    await client.query(`DROP INDEX IF EXISTS payouts_user_created_cursor_idx;`);
  },
};
