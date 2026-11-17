export const migration = {
  version: 27,
  name: 'google_identity',
  async up(client) {
    await client.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS google_subject TEXT');
    await client.query('CREATE UNIQUE INDEX IF NOT EXISTS users_google_subject_uq ON users(google_subject) WHERE google_subject IS NOT NULL');
  },
  async down(client) {
    await client.query('DROP INDEX IF EXISTS users_google_subject_uq');
    await client.query('ALTER TABLE users DROP COLUMN IF EXISTS google_subject');
  },
};
