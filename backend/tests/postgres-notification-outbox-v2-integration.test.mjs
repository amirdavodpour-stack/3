import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-notification-outbox-v2-postgres.json';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository/notifications.js'),
      import('../src/repository/privacy.js'),
    ])
  : [];
const dbModule = modules[0];
const notifications = modules[1];
const privacy = modules[2];
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const uuid = () => crypto.randomUUID();

async function createUser() {
  const id = uuid();
  await pool.query(
    "INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at) VALUES($1,$2,'integration-only-hash','Notification v2 test','USER','ACTIVE',0,NOW())",
    [id, `notification-v2-${id}@example.test`],
  );
  return id;
}

async function createNotification(userId) {
  const id = uuid();
  await pool.query(
    "INSERT INTO notifications(id,user_id,type,title,body,data,created_at) VALUES($1,$2,'TEST','Stored title','Stored private body',$3::jsonb,NOW())",
    [id, userId, JSON.stringify({ privateMarker:'db-only-notification-content' })],
  );
  return id;
}

async function createV2Event(notificationId, channel = 'PUSH', status = 'PROCESSING') {
  const id = uuid();
  const leaseToken = status === 'PROCESSING' ? uuid() : null;
  const payload = { schemaVersion:2, channel };
  await pool.query(
    "INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,locked_at,lease_token,created_at) VALUES($1,'NOTIFICATION_DISPATCH','notification',$2,$3,$4::jsonb,$5,1,NOW(),CASE WHEN $5='PROCESSING' THEN NOW() ELSE NULL END,$6,NOW())",
    [id, notificationId, `notification-v2-test:${id}`, JSON.stringify(payload), status, leaseToken],
  );
  return {
    id,
    event_type:'NOTIFICATION_DISPATCH',
    aggregate_type:'notification',
    aggregate_id:notificationId,
    status,
    lease_token:leaseToken,
    payload,
  };
}

async function createDevice(userId) {
  const token = `notification-v2-device-${uuid()}`;
  await pool.query(
    "INSERT INTO notification_devices(id,user_id,platform,token,enabled,created_at,updated_at) VALUES($1,$2,'ANDROID',$3,true,NOW(),NOW())",
    [uuid(), userId, token],
  );
  return token;
}

async function cleanup(userId, eventIds = [], notificationIds = []) {
  if (!enabled) return;
  await pool.query('DELETE FROM outbox_events WHERE id=ANY($1::uuid[])', [eventIds]).catch(() => {});
  await pool.query('DELETE FROM audit_logs WHERE entity_id=$1', [userId]).catch(() => {});
  await pool.query('DELETE FROM notification_devices WHERE user_id=$1', [userId]).catch(() => {});
  await pool.query('DELETE FROM notifications WHERE id=ANY($1::uuid[])', [notificationIds]).catch(() => {});
  await pool.query('DELETE FROM users WHERE id=$1', [userId]).catch(() => {});
}

test('v2 Outbox payload resolves recipient and notification content from the locked database records', { skip:!enabled, timeout:30_000 }, async () => {
  const userId = await createUser();
  const notificationId = await createNotification(userId);
  const deviceToken = await createDevice(userId);
  const event = await createV2Event(notificationId);
  let captured = null;
  try {
    assert.deepEqual(event.payload, { schemaVersion:2, channel:'PUSH' });
    const result = await notifications.dispatchNotificationOutbox(event, async (delivery) => {
      captured = delivery;
    });
    assert.equal(result.delivered, true);
    assert.equal(captured.userId, userId);
    assert.equal(captured.notificationId, notificationId);
    assert.equal(captured.channel, 'PUSH');
    assert.equal(captured.targets.length, 1);
    assert.equal(captured.targets[0].token, deviceToken);
    assert.deepEqual(captured.notification, {
      title:'Stored title',
      body:'Stored private body',
      data:{ privateMarker:'db-only-notification-content' },
    });
    const stored = await pool.query('SELECT payload,status FROM outbox_events WHERE id=$1', [event.id]);
    assert.deepEqual(stored.rows[0].payload, { schemaVersion:2, channel:'PUSH' });
    assert.equal(stored.rows[0].status, 'DONE');
  } finally {
    await cleanup(userId, [event.id], [notificationId]);
  }
});

test('account erasure cancels v2 notification Outbox rows using aggregate ownership after payload minimization', { skip:!enabled, timeout:30_000 }, async () => {
  const userId = await createUser();
  const notificationId = await createNotification(userId);
  const event = await createV2Event(notificationId, 'EMAIL', 'PENDING');
  try {
    const result = await privacy.deleteUserPrivacyBundle(userId, {
      email:`deleted+${userId}@invalid.local`,
      passwordHash:'integration-only-deleted-account-hash',
    });
    assert.equal(result.deleted, true);
    const stored = await pool.query('SELECT status,payload,lease_token,locked_at FROM outbox_events WHERE id=$1', [event.id]);
    assert.equal(stored.rows[0].status, 'CANCELLED');
    assert.deepEqual(stored.rows[0].payload, { schemaVersion:2, channel:'EMAIL' });
    assert.equal(stored.rows[0].lease_token, null);
    assert.equal(stored.rows[0].locked_at, null);
  } finally {
    await cleanup(userId, [event.id], [notificationId]);
  }
});

after(async () => {
  if (enabled) await dbModule.db.close();
});
