export const migration = {
  version: 47,
  name: 'privacy_shared_record_anonymization',
  async up(client) {
    await client.query(`
      ALTER TABLE trust_reports
        ALTER COLUMN reporter_id DROP NOT NULL,
        ADD COLUMN IF NOT EXISTS reporter_deleted_at TIMESTAMPTZ NULL;

      ALTER TABLE job_satisfaction_feedback
        ALTER COLUMN user_id DROP NOT NULL,
        ADD COLUMN IF NOT EXISTS author_deleted_at TIMESTAMPTZ NULL;

      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conrelid='trust_reports'::regclass
            AND conname='trust_reports_reporter_anonymization_check'
        ) THEN
          ALTER TABLE trust_reports
            ADD CONSTRAINT trust_reports_reporter_anonymization_check
            CHECK (
              (reporter_id IS NOT NULL AND reporter_deleted_at IS NULL)
              OR
              (reporter_id IS NULL AND reporter_deleted_at IS NOT NULL)
            );
        END IF;
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conrelid='job_satisfaction_feedback'::regclass
            AND conname='job_satisfaction_author_anonymization_check'
        ) THEN
          ALTER TABLE job_satisfaction_feedback
            ADD CONSTRAINT job_satisfaction_author_anonymization_check
            CHECK (
              (user_id IS NOT NULL AND author_deleted_at IS NULL)
              OR
              (user_id IS NULL AND author_deleted_at IS NOT NULL)
            );
        END IF;
      END $$;

      CREATE INDEX IF NOT EXISTS trust_reports_anonymized_review_idx
        ON trust_reports(status,created_at DESC)
        WHERE reporter_id IS NULL;
      CREATE INDEX IF NOT EXISTS job_satisfaction_anonymized_job_idx
        ON job_satisfaction_feedback(job_id,created_at)
        WHERE user_id IS NULL;
    `);
  },
  async down(client) {
    const { rows } = await client.query(`
      SELECT
        EXISTS (SELECT 1 FROM trust_reports WHERE reporter_id IS NULL OR reporter_deleted_at IS NOT NULL)
          AS has_anonymized_trust_reports,
        EXISTS (SELECT 1 FROM job_satisfaction_feedback WHERE user_id IS NULL OR author_deleted_at IS NOT NULL)
          AS has_anonymized_satisfaction_feedback
    `);
    if (rows[0]?.has_anonymized_trust_reports || rows[0]?.has_anonymized_satisfaction_feedback) {
      throw new Error(
        'Cannot rollback shared-record anonymization while anonymized trust or satisfaction history exists',
      );
    }

    await client.query(`
      DROP INDEX IF EXISTS job_satisfaction_anonymized_job_idx;
      DROP INDEX IF EXISTS trust_reports_anonymized_review_idx;
      ALTER TABLE job_satisfaction_feedback
        DROP CONSTRAINT IF EXISTS job_satisfaction_author_anonymization_check,
        DROP COLUMN IF EXISTS author_deleted_at,
        ALTER COLUMN user_id SET NOT NULL;
      ALTER TABLE trust_reports
        DROP CONSTRAINT IF EXISTS trust_reports_reporter_anonymization_check,
        DROP COLUMN IF EXISTS reporter_deleted_at,
        ALTER COLUMN reporter_id SET NOT NULL;
    `);
  },
};
