export const migration = {
  version:58,
  name:'outbox_retention_holds',
  async up(client) {
    await client.query(`
      CREATE TABLE IF NOT EXISTS outbox_retention_holds (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        target_kind TEXT NOT NULL
          CHECK(target_kind IN ('EVENT','AGGREGATE')),
        event_id UUID NULL,
        aggregate_type TEXT NOT NULL,
        aggregate_id UUID NULL,
        hold_kind TEXT NOT NULL
          CHECK(hold_kind IN ('LEGAL','ADMIN')),
        reason_code TEXT NOT NULL
          CHECK(reason_code IN (
            'LEGAL_REQUEST',
            'COURT_ORDER',
            'REGULATORY_REQUEST',
            'DISPUTE',
            'FRAUD_REVIEW',
            'SECURITY_INCIDENT',
            'AUDIT_REQUEST',
            'ADMIN_REVIEW',
            'INVESTIGATION',
            'CASE_CLOSED',
            'HOLD_SCOPE_CHANGED'
          )),
        created_by UUID NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT outbox_retention_hold_target_check CHECK (
          (target_kind='EVENT' AND event_id IS NOT NULL)
          OR
          (target_kind='AGGREGATE' AND event_id IS NULL AND aggregate_id IS NOT NULL)
        )
      );

      CREATE TABLE IF NOT EXISTS outbox_retention_hold_releases (
        hold_id UUID PRIMARY KEY
          REFERENCES outbox_retention_holds(id) ON DELETE RESTRICT,
        released_by UUID NOT NULL,
        reason_code TEXT NOT NULL
          CHECK(reason_code IN (
            'LEGAL_REQUEST',
            'COURT_ORDER',
            'REGULATORY_REQUEST',
            'DISPUTE',
            'FRAUD_REVIEW',
            'SECURITY_INCIDENT',
            'AUDIT_REQUEST',
            'ADMIN_REVIEW',
            'INVESTIGATION',
            'CASE_CLOSED',
            'HOLD_SCOPE_CHANGED'
          )),
        released_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS outbox_retention_holds_event_active_idx
        ON outbox_retention_holds(event_id,created_at)
        WHERE target_kind='EVENT';
      CREATE INDEX IF NOT EXISTS outbox_retention_holds_aggregate_active_idx
        ON outbox_retention_holds(aggregate_type,aggregate_id,created_at)
        WHERE target_kind='AGGREGATE';
      CREATE INDEX IF NOT EXISTS outbox_retention_holds_target_kind_idx
        ON outbox_retention_holds(target_kind,hold_kind,created_at);

      CREATE OR REPLACE FUNCTION hope_reject_outbox_retention_ledger_mutation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $body$
      BEGIN
        RAISE EXCEPTION USING
          ERRCODE='55000',
          MESSAGE='OUTBOX_RETENTION_LEDGER_IMMUTABLE';
      END;
      $body$;

      DROP TRIGGER IF EXISTS outbox_retention_holds_immutable_trigger
        ON outbox_retention_holds;
      CREATE TRIGGER outbox_retention_holds_immutable_trigger
        BEFORE UPDATE OR DELETE ON outbox_retention_holds
        FOR EACH ROW
        EXECUTE FUNCTION hope_reject_outbox_retention_ledger_mutation();

      DROP TRIGGER IF EXISTS outbox_retention_hold_releases_immutable_trigger
        ON outbox_retention_hold_releases;
      CREATE TRIGGER outbox_retention_hold_releases_immutable_trigger
        BEFORE UPDATE OR DELETE ON outbox_retention_hold_releases
        FOR EACH ROW
        EXECUTE FUNCTION hope_reject_outbox_retention_ledger_mutation();
    `);
  },
  async down(client) {
    await client.query('LOCK TABLE outbox_retention_holds,outbox_retention_hold_releases IN ACCESS EXCLUSIVE MODE');
    const { rows } = await client.query(`
      SELECT
        EXISTS(SELECT 1 FROM outbox_retention_holds) AS has_holds,
        EXISTS(SELECT 1 FROM outbox_retention_hold_releases) AS has_releases
    `);
    if (rows[0]?.has_holds || rows[0]?.has_releases) {
      throw new Error('Cannot roll back Outbox retention holds after immutable hold evidence exists');
    }
    await client.query(`
      DROP TRIGGER IF EXISTS outbox_retention_hold_releases_immutable_trigger
        ON outbox_retention_hold_releases;
      DROP TRIGGER IF EXISTS outbox_retention_holds_immutable_trigger
        ON outbox_retention_holds;
      DROP TABLE IF EXISTS outbox_retention_hold_releases;
      DROP TABLE IF EXISTS outbox_retention_holds;
      DROP FUNCTION IF EXISTS hope_reject_outbox_retention_ledger_mutation();
    `);
  },
};
