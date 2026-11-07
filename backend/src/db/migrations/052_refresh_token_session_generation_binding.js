export const migration = {
  version: 52,
  name: 'refresh_token_session_generation_binding',
  async up(client) {
    await client.query(\`
      ALTER TABLE refresh_tokens
        ADD COLUMN IF NOT EXISTS session_version INTEGER;

      UPDATE refresh_tokens rt
         SET session_version=u.session_version
        FROM users u
       WHERE u.id=rt.user_id
         AND rt.session_version IS NULL;

      UPDATE refresh_tokens
         SET session_version=0
       WHERE session_version IS NULL;

      ALTER TABLE refresh_tokens
        ALTER COLUMN session_version SET DEFAULT 0,
        ALTER COLUMN session_version SET NOT NULL;

      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
           WHERE conrelid='refresh_tokens'::regclass
             AND conname='refresh_tokens_session_version_nonnegative_check'
        ) THEN
          ALTER TABLE refresh_tokens
            ADD CONSTRAINT refresh_tokens_session_version_nonnegative_check
            CHECK (session_version >= 0);
        END IF;
      END $$;
    \`);
  },
  async down() {
    throw new Error(
      'Migration 052 binds issued refresh tokens to account session generations and cannot be rolled back safely.',
    );
  },
};
