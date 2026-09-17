import { config } from './config.js';
import { withSqlTransaction } from './db.js';
import { processOutboxEvent } from './outbox_handlers.js';

async function claimLatestPaymentRelease() {
  return withSqlTransaction(async (client) => {
    const { rows } = await client.query(
      `WITH candidate AS (
         SELECT id FROM outbox_events
         WHERE event_type='PAYMENT_RELEASE'
           AND status IN ('PENDING','PROCESSING')
           AND (status='PENDING' OR locked_at < NOW() - make_interval(secs => $1))
           AND available_at <= NOW()
         ORDER BY created_at DESC
         FOR UPDATE SKIP LOCKED
         LIMIT 1
       )
       UPDATE outbox_events o
       SET status='PROCESSING', attempts=o.attempts+1, locked_at=NOW(), lease_token=gen_random_uuid()
       FROM candidate c
       WHERE o.id=c.id
       RETURNING o.*`,
      [config.outboxLeaseSeconds],
    );
    return rows[0] || null;
  });
}

export async function processLatestPaymentReleaseNow() {
  const event = await claimLatestPaymentRelease();
  if (!event) return false;
  await processOutboxEvent(event);
  return true;
}
