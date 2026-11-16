export const migration = {
  version: 49,
  name: 'chat_retention_dry_run_cursor_index',
  async up(client) {
    await client.query(`
      CREATE INDEX IF NOT EXISTS chat_conversations_retention_cursor_idx
        ON chat_conversations(created_at,id)
        WHERE kind='JOB';
    `);
  },
  async down(client) {
    await client.query('DROP INDEX IF EXISTS chat_conversations_retention_cursor_idx');
  },
};
