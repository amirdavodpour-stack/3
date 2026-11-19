export const migration = {
  version: 61,
  name: 'serverless_maintenance_runs',
  async up(client) {
    await client.query(`
      CREATE TABLE maintenance_runs (
        request_id UUID PRIMARY KEY,
        status TEXT NOT NULL CHECK (status IN ('RUNNING','COMPLETED','FAILED')),
        started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        finished_at TIMESTAMPTZ,
        result JSONB,
        failure_code TEXT,
        CONSTRAINT maintenance_runs_terminal_state_check CHECK (
          (status='RUNNING' AND finished_at IS NULL)
          OR (status IN ('COMPLETED','FAILED') AND finished_at IS NOT NULL)
        ),
        CONSTRAINT maintenance_runs_failure_code_check CHECK (
          failure_code IS NULL OR failure_code ~ '^[A-Z0-9_]{1,80}$'
        )
      );
      CREATE INDEX maintenance_runs_started_at_idx ON maintenance_runs(started_at);
      CREATE INDEX maintenance_runs_status_started_at_idx ON maintenance_runs(status,started_at);
    `);
  },
  async down(client) {
    const { rows } = await client.query('SELECT 1 FROM maintenance_runs LIMIT 1');
    if (rows.length) {
      throw new Error('Cannot rollback serverless maintenance while request replay history exists');
    }
    await client.query('DROP TABLE maintenance_runs');
  },
};
