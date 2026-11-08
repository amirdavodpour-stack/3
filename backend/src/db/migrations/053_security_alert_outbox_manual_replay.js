export const migration = {
  version: 53,
  name: 'security_alert_outbox_manual_replay',
  async up(client) {
    await client.query(`
      ALTER TABLE outbox_events
        ADD COLUMN IF NOT EXISTS manual_replay_count SMALLINT NOT NULL DEFAULT 0,
        ADD COLUMN IF NOT EXISTS manual_replay_idempotency_key TEXT NULL;

      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
           WHERE conrelid='outbox_events'::regclass
             AND conname='outbox_manual_replay_consistency_check'
        ) THEN
          ALTER TABLE outbox_events
            ADD CONSTRAINT outbox_manual_replay_consistency_check
            CHECK (
              (manual_replay_count=0 AND manual_replay_idempotency_key IS NULL)
              OR
              (
                manual_replay_count=1
                AND manual_replay_idempotency_key IS NOT NULL
                AND length(btrim(manual_replay_idempotency_key)) BETWEEN 1 AND 200
              )
            );
        END IF;
      END $$;
    `);
  },
  async down(client) {
    const { rows } = await client.query(
      `SELECT COUNT(*)::int AS used_count
         FROM outbox_events
        WHERE manual_replay_count > 0`,
    );
    if (Number(rows[0]?.used_count || 0) > 0) {
      throw new Error(
        'Migration 053 cannot be rolled back after a security alert replay has been used.',
      );
    }
    await client.query(`
      ALTER TABLE outbox_events
        DROP CONSTRAINT IF EXISTS outbox_manual_replay_consistency_check,
        DROP COLUMN IF EXISTS manual_replay_idempotency_key,
        DROP COLUMN IF EXISTS manual_replay_count;
    `);
  },
};
