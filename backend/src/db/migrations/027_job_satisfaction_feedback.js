export const migration = {
  version: 27,
  name: 'job_satisfaction_feedback',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS job_satisfaction_feedback (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE RESTRICT,
        user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        role TEXT NOT NULL CHECK (role IN ('WORKER','EMPLOYER')),
        overall_rating SMALLINT NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
        completed_as_agreed BOOLEAN NOT NULL,
        communication_rating SMALLINT NOT NULL CHECK (communication_rating BETWEEN 1 AND 5),
        report_text TEXT NOT NULL DEFAULT '',
        ai_summary TEXT NOT NULL DEFAULT '',
        ai_satisfaction_score SMALLINT NOT NULL DEFAULT 0 CHECK (ai_satisfaction_score BETWEEN 0 AND 100),
        ai_sentiment TEXT NOT NULL DEFAULT 'NEEDS_REVIEW'
          CHECK (ai_sentiment IN ('SATISFIED','MIXED','UNSATISFIED','NEEDS_REVIEW')),
        ai_tags JSONB NOT NULL DEFAULT '[]'::jsonb,
        ai_risk_flags JSONB NOT NULL DEFAULT '[]'::jsonb,
        status TEXT NOT NULL DEFAULT 'ANALYZED'
          CHECK (status IN ('SUBMITTED','ANALYZED','ANALYSIS_FAILED')),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE(job_id,user_id)
      );
      CREATE INDEX IF NOT EXISTS job_satisfaction_job_idx
        ON job_satisfaction_feedback(job_id,created_at);
      CREATE INDEX IF NOT EXISTS job_satisfaction_user_idx
        ON job_satisfaction_feedback(user_id,created_at DESC);
    `);
  },
  async down(client) {
    const { rows } = await client.query(`SELECT 1 FROM job_satisfaction_feedback LIMIT 1`);
    if (rows.length) throw new Error('Cannot rollback job_satisfaction_feedback while it contains data');
    await client.query(`DROP TABLE IF EXISTS job_satisfaction_feedback`);
  },
};
