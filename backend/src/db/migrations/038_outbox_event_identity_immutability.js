export const migration = {
  version: 38,
  name: 'outbox_event_identity_immutability',
  async up(client) {
    await client.query(`
      CREATE OR REPLACE FUNCTION hope_guard_outbox_event_identity_immutable() RETURNS trigger
      LANGUAGE plpgsql AS $body$
      BEGIN
        IF NEW.id IS DISTINCT FROM OLD.id
          OR NEW.event_type IS DISTINCT FROM OLD.event_type
          OR NEW.aggregate_type IS DISTINCT FROM OLD.aggregate_type
          OR NEW.aggregate_id IS DISTINCT FROM OLD.aggregate_id
          OR NEW.dedupe_key IS DISTINCT FROM OLD.dedupe_key
          OR NEW.payload IS DISTINCT FROM OLD.payload
          OR NEW.created_at IS DISTINCT FROM OLD.created_at
        THEN
          RAISE EXCEPTION 'outbox event identity and payload are immutable'
            USING ERRCODE='55000';
        END IF;
        RETURN NEW;
      END;
      $body$;

      DROP TRIGGER IF EXISTS outbox_event_identity_immutable_trigger ON outbox_events;
      CREATE TRIGGER outbox_event_identity_immutable_trigger
        BEFORE UPDATE ON outbox_events
        FOR EACH ROW EXECUTE FUNCTION hope_guard_outbox_event_identity_immutable();
    `);
  },
  async down(client) {
    await client.query(`
      DROP TRIGGER IF EXISTS outbox_event_identity_immutable_trigger ON outbox_events;
      DROP FUNCTION IF EXISTS hope_guard_outbox_event_identity_immutable();
    `);
  },
};
