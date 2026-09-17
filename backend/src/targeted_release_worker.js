import { config } from './config.js';
import { withSqlTransaction } from './db.js';
import { processOutboxEvent } from './outbox_handlers.js';

async function claimPaymentRelease(eventId) {
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(
      `WITH candidate AS (
         SELECT id FROM outbox_events
         WHERE id=$1
           AND event_type='PAYMENT_RELEASE'
           AND status IN ('PENDING','PROCESSING')
           AND (status='PENDING' OR locked_at < NOW() - make_interval(secs => $2))
           AND available_at <= NOW()
         FOR UPDATE SKIP LOCKED
       )
       UPDATE outbox_events o
       SET status='PROCESSING', attempts=o.attempts+1, locked_at=NOW(), lease_token=gen_random_uuid()
       FROM candidate c
       WHERE o.id=c.id
       RETURNING o.*`,
      [eventId, config.outboxLeaseSeconds],
    );
    return rows[0] || null;
  });
}

export async function processPaymentReleaseNow(eventId) {
  const id = String(eventId || '').trim();
  if (!id) return false;
  const event = await claimPaymentRelease(id);
  if (!event) return false;
  await processOutboxEvent(event);
  return true;
}
