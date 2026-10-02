export const migration = {
  version: 28,
  name: 'recommendation_profile',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS recommendation_profiles (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        resume_text TEXT NOT NULL DEFAULT '',
        skills JSONB NOT NULL DEFAULT '[]'::jsonb,
        interests JSONB NOT NULL DEFAULT '[]'::jsonb,
        preferred_categories JSONB NOT NULL DEFAULT '[]'::jsonb,
        preferred_cities JSONB NOT NULL DEFAULT '[]'::jsonb,
        desired_kinds JSONB NOT NULL DEFAULT '[]'::jsonb,
        work_mode TEXT,
        availability TEXT,
        salary_min NUMERIC,
        salary_max NUMERIC,
        experience_level TEXT,
        goals TEXT NOT NULL DEFAULT '',
        onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
        source_version TEXT NOT NULL DEFAULT '1.0',
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);
    await client.query(`
      CREATE INDEX IF NOT EXISTS recommendation_profiles_updated_idx
      ON recommendation_profiles(updated_at DESC);
    `);
  },
  async down(client) {
    await client.query('DROP INDEX IF EXISTS recommendation_profiles_updated_idx');
    await client.query('DROP TABLE IF EXISTS recommendation_profiles');
  },
};