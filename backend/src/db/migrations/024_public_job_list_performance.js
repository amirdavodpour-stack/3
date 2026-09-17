export const migration = {
  version: 24,
  name: 'public_job_list_performance',
  async up(client) {
    await client.query(`
      CREATE INDEX IF NOT EXISTS jobs_status_updated_idx
        ON jobs(status, updated_at DESC, id DESC);
    `);
  },
  async down(client) {
    await client.query(`DROP INDEX IF EXISTS jobs_status_updated_idx;`);
  },
};
