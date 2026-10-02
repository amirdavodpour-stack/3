export const migration = {
  version: 30,
  name: 'job_disputes',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS job_disputes (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        job_id UUID NOT NULL UNIQUE REFERENCES jobs(id) ON DELETE RESTRICT,
        opened_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
        trigger_type TEXT NOT NULL DEFAULT 'USER'
          CHECK (trigger_type IN ('USER','SATISFACTION_CONFLICT','ADMIN')),
        status TEXT NOT NULL DEFAULT 'OPEN'
          CHECK (status IN ('OPEN','AI_ANALYZED','ADMIN_REVIEW','RESOLVED','ESCALATED')),
        ai_decision TEXT NULL
          CHECK (ai_decision IS NULL OR ai_decision IN ('RELEASE','REFUND','HOLD')),
        ai_confidence NUMERIC(5,4) NULL
          CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1)),
        ai_report JSONB NOT NULL DEFAULT '{}'::jsonb,
        legal_ruleset_version TEXT NOT NULL DEFAULT 'IR-2026-10-02-v1',
        resolution TEXT NULL
          CHECK (resolution IS NULL OR resolution IN ('RELEASE','REFUND','HOLD')),
        resolution_reason TEXT NOT NULL DEFAULT '',
        resolved_by UUID NULL REFERENCES users(id) ON DELETE SET NULL,
        resolved_at TIMESTAMPTZ NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS job_disputes_status_idx
        ON job_disputes(status,created_at DESC);
      CREATE INDEX IF NOT EXISTS job_disputes_opened_by_idx
        ON job_disputes(opened_by,created_at DESC);
    `);
  },
  async down(client) {
    await client.query(`DROP TABLE IF EXISTS job_disputes`);
  },
};