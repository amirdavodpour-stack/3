export const migration = {
  version:60,
  name:'outbox_retention_evidence_no_truncate',
  async up(client) {
    await client.query(`
      CREATE TRIGGER outbox_retention_holds_no_truncate_trigger
        BEFORE TRUNCATE ON outbox_retention_holds
        FOR EACH STATEMENT
        EXECUTE FUNCTION hope_reject_outbox_retention_ledger_mutation();

      CREATE TRIGGER outbox_retention_hold_releases_no_truncate_trigger
        BEFORE TRUNCATE ON outbox_retention_hold_releases
        FOR EACH STATEMENT
        EXECUTE FUNCTION hope_reject_outbox_retention_ledger_mutation();

      CREATE TRIGGER admin_outbox_retention_hold_idempotency_no_truncate_trigger
        BEFORE TRUNCATE ON admin_outbox_retention_hold_idempotency
        FOR EACH STATEMENT
        EXECUTE FUNCTION hope_reject_outbox_retention_ledger_mutation();
    `);
  },
  async down(client) {
    await client.query(`
      LOCK TABLE
        admin_outbox_retention_hold_idempotency,
        outbox_retention_holds,
        outbox_retention_hold_releases
      IN ACCESS EXCLUSIVE MODE
    `);
    const { rows } = await client.query(`
      SELECT
        EXISTS(SELECT 1 FROM admin_outbox_retention_hold_idempotency) AS has_idempotency,
        EXISTS(SELECT 1 FROM outbox_retention_holds) AS has_holds,
        EXISTS(SELECT 1 FROM outbox_retention_hold_releases) AS has_releases
    `);
    if (rows[0]?.has_idempotency || rows[0]?.has_holds || rows[0]?.has_releases) {
      throw new Error('Cannot remove Outbox retention evidence protection while immutable records exist');
    }
    await client.query(`
      DROP TRIGGER IF EXISTS admin_outbox_retention_hold_idempotency_no_truncate_trigger
        ON admin_outbox_retention_hold_idempotency;
      DROP TRIGGER IF EXISTS outbox_retention_hold_releases_no_truncate_trigger
        ON outbox_retention_hold_releases;
      DROP TRIGGER IF EXISTS outbox_retention_holds_no_truncate_trigger
        ON outbox_retention_holds;
    `);
  },
};
