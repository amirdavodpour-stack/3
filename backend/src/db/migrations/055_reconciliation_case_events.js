export const migration = {
  version: 55,
  name: 'reconciliation_case_events',
  async up(client) {
    await client.query(`
      CREATE TABLE reconciliation_case_events (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        case_id UUID NOT NULL REFERENCES reconciliation_cases(id) ON DELETE RESTRICT,
        event_id UUID NOT NULL REFERENCES outbox_events(id) ON DELETE RESTRICT,
        actor_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
        actor_session_jti TEXT NOT NULL
          CHECK (length(trim(actor_session_jti)) BETWEEN 1 AND 200),
        action TEXT NOT NULL
          CHECK (action='INVESTIGATION_NOTE_ADDED'),
        reason TEXT NOT NULL
          CHECK (length(trim(reason)) BETWEEN 10 AND 1000),
        evidence_reference TEXT NOT NULL
          CHECK (length(trim(evidence_reference)) BETWEEN 8 AND 500),
        verification JSONB NOT NULL
          CHECK (jsonb_typeof(verification)='object'),
        idempotency_key TEXT NOT NULL
          CHECK (idempotency_key ~ '^[A-Za-z0-9._:-]{16,128}$'),
        request_hash TEXT NOT NULL
          CHECK (request_hash ~ '^[0-9a-f]{64}$'),
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        UNIQUE(actor_id,idempotency_key)
      );
      CREATE INDEX reconciliation_case_events_case_created_idx
        ON reconciliation_case_events(case_id,created_at DESC,id DESC);
      CREATE INDEX reconciliation_case_events_event_created_idx
        ON reconciliation_case_events(event_id,created_at DESC,id DESC);
      CREATE OR REPLACE FUNCTION prevent_reconciliation_case_event_mutation()
      RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'RECONCILIATION_CASE_EVENTS_APPEND_ONLY';
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER reconciliation_case_events_append_only
        BEFORE UPDATE OR DELETE ON reconciliation_case_events
        FOR EACH ROW EXECUTE FUNCTION prevent_reconciliation_case_event_mutation();
      CREATE TRIGGER reconciliation_case_events_no_truncate
        BEFORE TRUNCATE ON reconciliation_case_events
        FOR EACH STATEMENT EXECUTE FUNCTION prevent_reconciliation_case_event_mutation();
    `);
  },
  async down(client) {
    const { rows } = await client.query(
      'SELECT 1 FROM reconciliation_case_events LIMIT 1',
    );
    if (rows.length) {
      throw new Error('Cannot rollback reconciliation case events while investigation evidence exists');
    }
    await client.query('DROP TABLE reconciliation_case_events');
    await client.query('DROP FUNCTION prevent_reconciliation_case_event_mutation()');
  },
};
