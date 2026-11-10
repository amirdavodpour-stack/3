export const migration = {
  version: 55,
  name: 'outbox_terminal_clock',
  async up(client) {
    await client.query(`
      ALTER TABLE outbox_events
        ADD COLUMN IF NOT EXISTS terminal_at TIMESTAMPTZ NULL;

      ALTER TABLE outbox_events
        ADD CONSTRAINT outbox_events_terminal_at_status_check
        CHECK (
          terminal_at IS NULL
          OR status IN ('DONE','FAILED','CANCELLED')
        ) NOT VALID;

      ALTER TABLE outbox_events
        VALIDATE CONSTRAINT outbox_events_terminal_at_status_check;

      CREATE OR REPLACE FUNCTION hope_set_outbox_terminal_at()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $body$
      BEGIN
        IF TG_OP = 'INSERT' THEN
          IF NEW.status IN ('DONE','FAILED','CANCELLED') THEN
            NEW.terminal_at := COALESCE(NEW.terminal_at, NOW());
          ELSE
            NEW.terminal_at := NULL;
          END IF;
          RETURN NEW;
        END IF;

        IF NEW.status IS DISTINCT FROM OLD.status THEN
          IF NEW.status IN ('DONE','FAILED','CANCELLED') THEN
            NEW.terminal_at := NOW();
          ELSE
            NEW.terminal_at := NULL;
          END IF;
        ELSE
          -- Keep the first timestamp for duplicate callbacks and prevent
          -- callers from rewriting terminal history without a state change.
          NEW.terminal_at := OLD.terminal_at;
        END IF;

        RETURN NEW;
      END;
      $body$;

      DROP TRIGGER IF EXISTS outbox_events_terminal_clock_trigger ON outbox_events;
      CREATE TRIGGER outbox_events_terminal_clock_trigger
        BEFORE INSERT OR UPDATE ON outbox_events
        FOR EACH ROW
        EXECUTE FUNCTION hope_set_outbox_terminal_at();
    `);
  },
  async down(client) {
    await client.query('LOCK TABLE outbox_events IN ACCESS EXCLUSIVE MODE');
    const { rows } = await client.query(
      'SELECT COUNT(*)::int AS used_count FROM outbox_events WHERE terminal_at IS NOT NULL',
    );
    if (Number(rows[0]?.used_count || 0) > 0) {
      throw new Error('migration 055 cannot be rolled back after terminal timestamps have been recorded');
    }
    await client.query(`
      DROP TRIGGER IF EXISTS outbox_events_terminal_clock_trigger ON outbox_events;
      DROP FUNCTION IF EXISTS hope_set_outbox_terminal_at();
      ALTER TABLE outbox_events
        DROP CONSTRAINT IF EXISTS outbox_events_terminal_at_status_check;
      ALTER TABLE outbox_events
        DROP COLUMN IF EXISTS terminal_at;
    `);
  },
};
