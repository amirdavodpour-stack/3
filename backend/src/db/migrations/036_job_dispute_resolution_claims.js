export const migration = {
  version: 36,
  name: 'job_dispute_resolution_claims',
  async up(client) {
    await client.query(`
      ALTER TABLE job_disputes
        ADD COLUMN IF NOT EXISTS resolution_lease_token UUID NULL,
        ADD COLUMN IF NOT EXISTS resolution_lease_until TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS resolution_started_at TIMESTAMPTZ NULL;

      ALTER TABLE job_disputes
        DROP CONSTRAINT IF EXISTS job_disputes_status_check;
      ALTER TABLE job_disputes
        ADD CONSTRAINT job_disputes_status_check
        CHECK (status IN ('OPEN','AI_ANALYZED','ADMIN_REVIEW','RESOLVING','RESOLVED','ESCALATED'));

      ALTER TABLE job_disputes
        ADD CONSTRAINT job_disputes_resolution_claim_check
        CHECK (
          (
            status='RESOLVING'
            AND resolution IS NOT NULL
            AND resolved_by IS NOT NULL
            AND resolution_lease_token IS NOT NULL
            AND resolution_lease_until IS NOT NULL
          )
          OR
          (
            status<>'RESOLVING'
            AND resolution_lease_token IS NULL
            AND resolution_lease_until IS NULL
          )
        );

      CREATE INDEX IF NOT EXISTS job_disputes_resolution_lease_idx
        ON job_disputes(status,resolution_lease_until)
        WHERE status='RESOLVING';
    `);
  },
  async down() {
    throw new Error('Migration 036 is forward-only: dispute resolution claims are durable workflow history.');
  },
};
