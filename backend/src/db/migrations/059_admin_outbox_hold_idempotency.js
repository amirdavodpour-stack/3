export const migration = {
  version:59,
  name:'admin_outbox_hold_idempotency',
  async up(client) {
    await client.query(`
      CREATE TABLE admin_outbox_retention_hold_idempotency (
        actor_id UUID NOT NULL,
        key_digest BYTEA NOT NULL CHECK(octet_length(key_digest)=32),
        request_digest BYTEA NOT NULL CHECK(octet_length(request_digest)=32),
        hold_id UUID NOT NULL UNIQUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        PRIMARY KEY(actor_id,key_digest),
        CONSTRAINT admin_outbox_hold_idempotency_hold_fk
          FOREIGN KEY(hold_id)
          REFERENCES outbox_retention_holds(id)
          ON DELETE RESTRICT
          DEFERRABLE INITIALLY DEFERRED
      );

      CREATE TRIGGER admin_outbox_retention_hold_idempotency_immutable_trigger
        BEFORE UPDATE OR DELETE ON admin_outbox_retention_hold_idempotency
        FOR EACH ROW
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
      throw new Error('Cannot roll back Admin Outbox hold idempotency after immutable hold evidence exists');
    }
    await client.query(`
      DROP TRIGGER IF EXISTS admin_outbox_retention_hold_idempotency_immutable_trigger
        ON admin_outbox_retention_hold_idempotency;
      DROP TABLE IF EXISTS admin_outbox_retention_hold_idempotency;
    `);
  },
};
