import crypto from 'node:crypto';
import { withSqlTransaction } from '../db.js';
import { requirePool } from './context.js';

const notificationFromRow = (r) => ({
  id: r.id,
  userId: r.user_id,
  type: r.type,
  title: r.title,
  body: r.body,
  data: r.data || {},
  readAt: r.read_at ? (r.read_at.toISOString?.() ?? r.read_at) : null,
  createdAt: r.created_at?.toISOString?.() ?? r.created_at,
});

export async function ensureNotificationPreferences(userId) {
  const { rows } = await requirePool().query(`
    INSERT INTO notification_preferences(id,user_id) VALUES(gen_random_uuid(),$1)
    ON CONFLICT(user_id) DO UPDATE SET user_id=EXCLUDED.user_id
    RETURNING id,user_id,in_app,push,email,job_alerts,application_updates,payment_updates,marketing,updated_at
  `, [userId]);
  const r = rows[0];
  return {
    id:r.id,userId:r.user_id,inApp:r.in_app,push:r.push,email:r.email,jobAlerts:r.job_alerts,
    applicationUpdates:r.application_updates,paymentUpdates:r.payment_updates,marketing:r.marketing,
    updatedAt:r.updated_at?.toISOString?.() ?? r.updated_at,
  };
}

export async function getNotificationPreferences(userId) { return ensureNotificationPreferences(userId); }

export async function updateNotificationPreferences(userId, patch) {
  const current = await ensureNotificationPreferences(userId);
  const next = {...current, ...patch};
  const { rows } = await requirePool().query(
    `UPDATE notification_preferences SET in_app=$2,push=$3,email=$4,job_alerts=$5,application_updates=$6,payment_updates=$7,marketing=$8,updated_at=NOW() WHERE user_id=$1 RETURNING id,user_id,in_app,push,email,job_alerts,application_updates,payment_updates,marketing,updated_at`,
    [userId,!!next.inApp,!!next.push,!!next.email,!!next.jobAlerts,!!next.applicationUpdates,!!next.paymentUpdates,!!next.marketing],
  );
  return ensureNotificationPreferencesFromRow(rows[0]);
}

function ensureNotificationPreferencesFromRow(r) {
  return {
    id:r.id,userId:r.user_id,inApp:r.in_app,push:r.push,email:r.email,jobAlerts:r.job_alerts,
    applicationUpdates:r.application_updates,paymentUpdates:r.payment_updates,marketing:r.marketing,
    updatedAt:r.updated_at?.toISOString?.() ?? r.updated_at,
  };
}

export async function listNotifications(userId, limit=50, offset=0) {
  const {rows} = await requirePool().query(
    `SELECT * FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [userId,Math.min(Math.max(Number(limit)||50,1),100),Math.max(Number(offset)||0,0)],
  );
  return rows.map(notificationFromRow);
}

export async function markNotificationRead(id,userId) {
  const {rows} = await requirePool().query(
    `UPDATE notifications SET read_at=COALESCE(read_at,NOW()) WHERE id=$1 AND user_id=$2 RETURNING *`,
    [id,userId],
  );
  return rows[0] ? notificationFromRow(rows[0]) : null;
}

export async function markAllNotificationsRead(userId) {
  const {rowCount}=await requirePool().query(
    `UPDATE notifications SET read_at=COALESCE(read_at,NOW()) WHERE user_id=$1 AND read_at IS NULL`, [userId],
  );
  return {updated:rowCount};
}

export async function countUnreadNotifications(userId) {
  const {rows}=await requirePool().query(
    `SELECT COUNT(*)::int AS count FROM notifications WHERE user_id=$1 AND read_at IS NULL`, [userId],
  );
  return Number(rows[0]?.count||0);
}

export async function registerNotificationDevice({id,userId,platform,token,enabled=true}) {
  return withSqlTransaction(async(client)=>{
    const {rows:existingRows}=await client.query(`SELECT * FROM notification_devices WHERE token=$1 FOR UPDATE`,[token]);
    const existing=existingRows[0];
    if(existing && existing.user_id !== userId){
      const error=new Error('Notification device token belongs to another user');
      error.code='NOTIFICATION_DEVICE_OWNERSHIP';
      throw error;
    }
    const {rows}=existing
      ? await client.query(`UPDATE notification_devices SET platform=$2,enabled=$3,updated_at=NOW() WHERE id=$1 RETURNING *`,[existing.id,platform,enabled])
      : await client.query(`INSERT INTO notification_devices(id,user_id,platform,token,enabled) VALUES($1,$2,$3,$4,$5) RETURNING *`,[id,userId,platform,token,enabled]);
    const r=rows[0];
    return {id:r.id,userId:r.user_id,platform:r.platform,token:r.token,enabled:r.enabled,createdAt:r.created_at?.toISOString?.() ?? r.created_at,updatedAt:r.updated_at?.toISOString?.() ?? r.updated_at};
  });
}

export async function listNotificationDevices(userId) {
  const {rows}=await requirePool().query(
    `SELECT id,user_id,platform,token,enabled,created_at,updated_at FROM notification_devices WHERE user_id=$1 AND enabled=true ORDER BY updated_at DESC`, [userId],
  );
  return rows.map(r=>({id:r.id,userId:r.user_id,platform:r.platform,token:r.token,enabled:r.enabled,createdAt:r.created_at?.toISOString?.() ?? r.created_at,updatedAt:r.updated_at?.toISOString?.() ?? r.updated_at}));
}

export async function getUserEmail(userId) {
  const {rows}=await requirePool().query(`SELECT email FROM users WHERE id=$1 LIMIT 1`,[userId]);
  return rows[0]?.email || null;
}

async function cancelNotificationOutboxWithClient(client, { eventId, leaseToken, userId, channel, reason }) {
  const { rowCount } = await client.query(
    `UPDATE outbox_events
        SET status='CANCELLED',
            processed_at=NOW(),
            locked_at=NULL,
            lease_token=NULL,
            last_error=$3
      WHERE id=$1 AND status='PROCESSING' AND lease_token=$2`,
    [eventId, leaseToken, reason],
  );
  if (rowCount !== 1) return { processed:false, stale:true, reason:'STALE_LEASE' };

  await client.query(
    `INSERT INTO audit_logs(id,action,actor_id,entity_type,entity_id,meta,created_at)
     VALUES(
       gen_random_uuid(),
       $1,
       NULL,
       'user',
       $2,
       $3::jsonb,
       NOW()
     )`,
    [
      reason === 'ACCOUNT_ERASED'
        ? 'NOTIFICATION_OUTBOX_CANCELLED_ACCOUNT_ERASURE'
        : 'NOTIFICATION_OUTBOX_CANCELLED_SUPPRESSED',
      userId || null,
      JSON.stringify({ eventCount:1, reason, channel }),
    ],
  );
  return { processed:true, cancelled:true, reason, targetCount:0 };
}

async function completeNotificationOutboxWithClient(client, { eventId, leaseToken }) {
  const { rowCount } = await client.query(
    `UPDATE outbox_events
        SET status='DONE',
            processed_at=NOW(),
            locked_at=NULL,
            lease_token=NULL,
            last_error=NULL
      WHERE id=$1 AND status='PROCESSING' AND lease_token=$2`,
    [eventId, leaseToken],
  );
  return rowCount === 1
    ? { processed:true, delivered:true }
    : { processed:false, stale:true, reason:'STALE_LEASE' };
}

/**
 * Serialize notification delivery with account erasure.
 *
 * Lock order is user FOR SHARE -> Outbox row FOR UPDATE, matching the
 * erasure transaction's user FOR NO KEY UPDATE -> Outbox update order.
 * The recipient lock intentionally remains held across the bounded provider
 * attempt so erasure cannot commit while a new dispatch is being submitted.
 */
export async function dispatchNotificationOutbox(event, deliverTargets, { providerConfigured = true } = {}) {
  const eventId = String(event?.id || '');
  const payload = event?.payload || {};
  const notificationId = String(event?.aggregate_id || '');
  const channel = String(payload.channel || '').toUpperCase();
  const leaseToken = event?.lease_token;

  if (!eventId || !notificationId || !leaseToken) {
    throw new Error('NOTIFICATION_OUTBOX_EVENT_INVALID');
  }
  if (!['IN_APP','PUSH','EMAIL'].includes(channel)) {
    throw new Error('NOTIFICATION_CHANNEL_UNSUPPORTED');
  }
  if (channel !== 'IN_APP' && providerConfigured && typeof deliverTargets !== 'function') {
    throw new Error('NOTIFICATION_DELIVERY_CALLBACK_REQUIRED');
  }

  return withSqlTransaction(async (client) => {
    // The immutable aggregate_id is the only notification identity source.
    // Discover the recipient without locking, then take the recipient barrier
    // before the Outbox row, matching account erasure's lock order.
    const { rows: identityRows } = await client.query(
      `SELECT user_id FROM notifications WHERE id=$1`,
      [notificationId],
    );
    const userId = String(identityRows[0]?.user_id || '');
    let recipient = null;
    if (userId) {
      const { rows: userRows } = await client.query(
        `SELECT id,email,status FROM users WHERE id=$1 FOR SHARE`,
        [userId],
      );
      recipient = userRows[0] || null;
    }

    const { rows: eventRows } = await client.query(
      `SELECT event_type,aggregate_type,aggregate_id,status,lease_token
         FROM outbox_events
        WHERE id=$1
        FOR UPDATE`,
      [eventId],
    );
    const current = eventRows[0];
    if (!current) return { processed:false, stale:true, reason:'OUTBOX_NOT_FOUND' };
    if (current.status === 'CANCELLED') {
      return { processed:true, cancelled:true, reason:'ALREADY_CANCELLED', targetCount:0 };
    }
    if (current.status === 'DONE') {
      return { processed:true, alreadyDone:true, delivered:true };
    }
    if (
      current.event_type !== 'NOTIFICATION_DISPATCH'
      || current.aggregate_type !== 'notification'
      || String(current.aggregate_id || '') !== notificationId
    ) {
      return { processed:false, stale:true, reason:'OUTBOX_IDENTITY_MISMATCH' };
    }
    if (current.status !== 'PROCESSING') {
      return { processed:false, stale:true, reason:'INVALID_OUTBOX_STATE' };
    }
    if (String(current.lease_token || '') !== String(leaseToken)) {
      return { processed:false, stale:true, reason:'STALE_LEASE' };
    }

    if (!userId) {
      return cancelNotificationOutboxWithClient(client, {
        eventId, leaseToken, userId:null, channel, reason:'NOTIFICATION_MISSING',
      });
    }
    if (!recipient || String(recipient.status || '').toUpperCase() === 'DELETED') {
      return cancelNotificationOutboxWithClient(client, {
        eventId, leaseToken, userId, channel, reason:'ACCOUNT_ERASED',
      });
    }

    const { rows: notificationRows } = await client.query(
      `SELECT id,user_id,type,title,body,data
         FROM notifications
        WHERE id=$1 AND user_id=$2
        FOR KEY SHARE`,
      [notificationId, userId],
    );
    const notificationRow = notificationRows[0];
    if (!notificationRow) {
      return cancelNotificationOutboxWithClient(client, {
        eventId, leaseToken, userId, channel, reason:'NOTIFICATION_MISSING',
      });
    }
    const notification = {
      id:String(notificationRow.id),
      userId:String(notificationRow.user_id),
      type:notificationRow.type,
      title:notificationRow.title,
      body:notificationRow.body,
      data:notificationRow.data || {},
    };

    if (channel === 'IN_APP') {
      const completed = await completeNotificationOutboxWithClient(client, { eventId, leaseToken });
      return { ...completed, channel, notification, targetCount:completed.processed ? 1 : 0 };
    }

    if (channel === 'EMAIL' && String(recipient.email || '').trim().toLowerCase().endsWith('@invalid.local')) {
      return cancelNotificationOutboxWithClient(client, {
        eventId, leaseToken, userId, channel, reason:'EMAIL_RECIPIENT_INVALIDATED',
      });
    }

    if (!providerConfigured) {
      const completed = await completeNotificationOutboxWithClient(client, { eventId, leaseToken });
      return { ...completed, providerNotConfigured:true, channel, notification, targetCount:0 };
    }

    let targets = [];
    if (channel === 'PUSH') {
      const { rows } = await client.query(
        `SELECT id,user_id,platform,token,enabled,created_at,updated_at
           FROM notification_devices
          WHERE user_id=$1 AND enabled=true
          ORDER BY updated_at DESC`,
        [userId],
      );
      targets = rows.map((row) => ({
        id:row.id,
        userId:row.user_id,
        platform:row.platform,
        token:row.token,
        enabled:row.enabled,
        createdAt:row.created_at?.toISOString?.() ?? row.created_at,
        updatedAt:row.updated_at?.toISOString?.() ?? row.updated_at,
      }));
    } else if (recipient.email) {
      targets = [{ email:recipient.email }];
    }

    if (!targets.length) {
      const completed = await completeNotificationOutboxWithClient(client, { eventId, leaseToken });
      return { ...completed, noTarget:true, channel, notification, targetCount:0 };
    }

    // deliverTargets delegates to deliverNotification, whose configured
    // timeout/retry budget bounds how long the recipient barrier is held.
    await deliverTargets({ channel, targets, notificationId, userId, notification });
    const completed = await completeNotificationOutboxWithClient(client, { eventId, leaseToken });
    return { ...completed, channel, notification, targetCount:targets.length };
  });
}

export async function disableNotificationDevice(id,userId) {
  const {rows}=await requirePool().query(`UPDATE notification_devices SET enabled=false,updated_at=NOW() WHERE id=$1 AND user_id=$2 RETURNING *`,[id,userId]);
  const r=rows[0];
  return r?{id:r.id,userId:r.user_id,platform:r.platform,token:r.token,enabled:r.enabled,createdAt:r.created_at?.toISOString?.() ?? r.created_at,updatedAt:r.updated_at?.toISOString?.() ?? r.updated_at}:null;
}

export async function queueNotificationWithClient(client,{userId,type,title,body,data={},dedupeKey=null,channels=['IN_APP']}) {
  if(!userId) return {created:false,reason:'NO_RECIPIENT'};
  // Lock the recipient before creating content or an Outbox event. A matching
  // account-erasure transaction takes FOR NO KEY UPDATE on this row first.
  const { rows: recipientRows } = await client.query(
    `SELECT id,status FROM users WHERE id=$1 FOR SHARE`,
    [userId],
  );
  if (!recipientRows[0] || String(recipientRows[0].status || '').toUpperCase() === 'DELETED') {
    return { created:false, reason:'RECIPIENT_UNAVAILABLE' };
  }
  const id=crypto.randomUUID();
  if(dedupeKey){
    const {rows:existing}=await client.query(`SELECT * FROM notifications WHERE user_id=$1 AND (data->>'dedupeKey')=$2 ORDER BY created_at DESC LIMIT 1`,[userId,dedupeKey]);
    if(existing[0]) return {notification:notificationFromRow(existing[0]),created:false};
  }
  const notifyChannels=Array.from(new Set(channels));
  const payload={...data,dedupeKey:dedupeKey||undefined,channels:notifyChannels};
  const {rows}=await client.query(`INSERT INTO notifications(id,user_id,type,title,body,data,created_at) VALUES($1,$2,$3,$4,$5,$6::jsonb,NOW()) RETURNING *`,[id,userId,type,title,body,JSON.stringify(payload)]);
  for(const channel of notifyChannels.filter(Boolean)){
    const eventId=crypto.randomUUID();
    const eventPayload = { schemaVersion:2, channel };
    await client.query(`INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at) VALUES($1,'NOTIFICATION_DISPATCH','notification',$2,$3,$4::jsonb,'PENDING',0,NOW(),NOW()) ON CONFLICT(dedupe_key) DO NOTHING`,[eventId,id,`NOTIFICATION:${id}:${channel}`,JSON.stringify(eventPayload)]);
  }
  return {notification:notificationFromRow(rows[0]),created:true};
}

export async function queueNotification(options) {
  return withSqlTransaction((client)=>queueNotificationWithClient(client,options));
}
