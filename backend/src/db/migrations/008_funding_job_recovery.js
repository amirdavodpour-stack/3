export const migration = {
  version: 8,
  name: 'funding_job_recovery',
  async up(client) {
    await client.query(`
      ALTER TABLE payments
        ADD COLUMN IF NOT EXISTS funding_previous_job_status TEXT NULL;
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='payments_funding_previous_job_status_chk') THEN
          ALTER TABLE payments ADD CONSTRAINT payments_funding_previous_job_status_chk
            CHECK (funding_previous_job_status IS NULL OR funding_previous_job_status IN ('PUBLISHED','ASSIGNED'));
        END IF;
      END $$;
      CREATE INDEX IF NOT EXISTS payments_funding_recovery_idx
        ON payments(status,funding_previous_job_status)
        WHERE status='HOLD_FAILED';
    `);
  },
  async down(client) {
    await client.query(`DROP INDEX IF EXISTS payments_funding_recovery_idx; ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_funding_previous_job_status_chk; ALTER TABLE payments DROP COLUMN IF EXISTS funding_previous_job_status;`);
  },
};
