export const migration = {
  version: 42,
  name: 'email_verification_tokens',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS email_verification_tokens (
        id UUID PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TIMESTAMPTZ NOT NULL,
        used_at TIMESTAMPTZ NULL,
        created_at TIMESTAMPTZ NOT NULL
      );
      CREATE INDEX IF NOT EXISTS email_verification_tokens_user_active_idx
        ON email_verification_tokens(user_id,expires_at)
        WHERE used_at IS NULL;
    `);
  },
  async down(client) {
    const { rows } = await client.query('SELECT 1 FROM email_verification_tokens LIMIT 1');
    if (rows.length) throw new Error('Cannot rollback email_verification_tokens while verification records exist');
    await client.query('DROP TABLE IF EXISTS email_verification_tokens');
  },
};
