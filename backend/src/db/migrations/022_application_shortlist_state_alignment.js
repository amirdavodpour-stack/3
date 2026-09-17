export const migration = {
  version: 22,
  name: 'application_shortlist_state_alignment',
  async up(client) {
    // SHORTLISTED is the canonical employer-review state used by the
    // application use cases and Flutter contract. SELECTED is a legacy
    // spelling retained in older persistence paths.
    await client.query(`
      UPDATE job_applications
      SET status='SHORTLISTED', updated_at=NOW()
      WHERE status='SELECTED';

      DROP INDEX IF EXISTS job_applications_pending_uq;
      CREATE UNIQUE INDEX IF NOT EXISTS job_applications_pending_uq
        ON job_applications(job_id,candidate_id)
        WHERE status IN ('PENDING','SHORTLISTED');
    `);
  },
  async down(client) {
    await client.query(`DROP INDEX IF EXISTS job_applications_pending_uq; CREATE UNIQUE INDEX IF NOT EXISTS job_applications_pending_uq
      ON job_applications(job_id,candidate_id)
      WHERE status IN ('PENDING','SELECTED');`);
  },
};
