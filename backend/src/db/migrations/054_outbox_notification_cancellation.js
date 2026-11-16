export const migration = {
  version: 54,
  name: 'outbox_notification_cancellation',
  async up(client) {
    await client.query(
      `ALTER TABLE outbox_events
         ADD CONSTRAINT outbox_events_status_cancelled_check
         CHECK(
           status IN ('PENDING','PROCESSING','DONE','FAILED','CANCELLED')
           AND (
             status <> 'CANCELLED'
             OR (event_type='NOTIFICATION_DISPATCH' AND aggregate_type='notification')
           )
         )
         NOT VALID`,
    );
    await client.query(
      `ALTER TABLE outbox_events
         DROP CONSTRAINT IF EXISTS outbox_events_status_check`,
    );
    await client.query(
      `ALTER TABLE outbox_events
         VALIDATE CONSTRAINT outbox_events_status_cancelled_check`,
    );
    await client.query(
      `ALTER TABLE outbox_events
         RENAME CONSTRAINT outbox_events_status_cancelled_check
         TO outbox_events_status_check`,
    );
  },
  async down(client) {
    await client.query('LOCK TABLE outbox_events IN ACCESS EXCLUSIVE MODE');
    const { rows } = await client.query(
      `SELECT 1 FROM outbox_events WHERE status='CANCELLED' LIMIT 1`,
    );
    if (rows.length) {
      throw new Error('Cannot rollback notification cancellation while CANCELLED Outbox events exist');
    }
    await client.query(
      `ALTER TABLE outbox_events
         ADD CONSTRAINT outbox_events_status_revert_check
         CHECK(status IN ('PENDING','PROCESSING','DONE','FAILED'))
         NOT VALID`,
    );
    await client.query(
      `ALTER TABLE outbox_events
         DROP CONSTRAINT IF EXISTS outbox_events_status_check`,
    );
    await client.query(
      `ALTER TABLE outbox_events
         VALIDATE CONSTRAINT outbox_events_status_revert_check`,
    );
    await client.query(
      `ALTER TABLE outbox_events
         RENAME CONSTRAINT outbox_events_status_revert_check
         TO outbox_events_status_check`,
    );
  },
};
