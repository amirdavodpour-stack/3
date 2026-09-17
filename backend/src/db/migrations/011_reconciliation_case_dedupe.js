export const migration = {
  version: 11,
  name: 'reconciliation_case_dedupe',
  async up(client) {
    await client.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS reconciliation_cases_active_resource_uq
        ON reconciliation_cases(case_type,resource_type,resource_id)
        WHERE status IN ('OPEN','INVESTIGATING');
    `);
  },
  async down(client) {
    await client.query(`DROP INDEX IF EXISTS reconciliation_cases_active_resource_uq;`);
  },
};
