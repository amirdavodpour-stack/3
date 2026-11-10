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
      import('../src/repository.js'),
      import('../src/repository/notifications.js'),
    ])
  : [];
const dbModule = modules[0];
const repository = modules[1];
const notificationsRepo = modules[2];
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const uuid = () => crypto.randomUUID();

async function createUser() {
  const id = uuid();
  await pool.query(
    "INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at) VALUES($1,$2,'integration-only-hash','Outbox v2 test','USER','ACTIVE',0,NOW())",
    [id, `outbox-v2-${id}@example.test`],
  );
  return id;
}

async function createNotification(userId) {
  const id = uuid();
  const data = { canonicalMarker:'database-notification-data' };
  const { rows } = await pool.query(
    "INSERT INTO notifications(id,user_id,type,title,body,data,created_at) VALUES($1,$2,'OUTBOX_V2_TEST','Canonical notification title','Canonical notification body',$3::jsonb,NOW()) RETURNING id,user_id,type,title,body,data",
    [id,userId,JSON.stringify(data)],
  );
  return rows[0];
}

async function createDevice(userId) {
  const token = `notification-device-${uuid()}`;
  await pool.query(
    "INSERT INTO notification_devices(id,user_id,platform,token,enabled,created_at,updated_at) VALUES($1,$2,'ANDROID',$3,true,NOW(),NOW())",
    [uuid(),userId,token],
  );
  return token;
}

async function createEvent(notificationId, payload) {
  const id = uuid();
  const leaseToken = uuid();
  await pool.query(
    "INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,locked_at,lease_token,created_at) VALUES($1,'NOTIFICATION_DISPATCH','notification',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW())",
    [id,notificationId,`notification-outbox-v2-test:${id}`,JSON.stringify(payload),leaseToken],
  );
  return {
    id,
    event_type:'NOTIFICATION_DISPATCH',
    aggregate_type:'notification',
    aggregate_id:notificationId,
    status:'PROCESSING',
    lease_token:leaseToken,
    payload,
  };
}

async function cleanup(userId, notificationIds = [], eventIds = []) {
  if (!enabled) return;
  await pool.query("DELETE FROM outbox_events WHERE id=ANY($1::uuid[])",[eventIds]).catch(()=>{});
  await pool.query("DELETE FROM outbox_events WHERE event_type='NOTIFICATION_DISPATCH' AND aggregate_id=ANY($1::uuid[])",[notificationIds]).catch(()=>{});
  await pool.query("DELETE FROM notification_devices WHERE user_id=$1",[userId]).catch(()=>{});
  await pool.query("DELETE FROM notifications WHERE id=ANY($1::uuid[])",[notificationIds]).catch(()=>{});
  await pool.query("DELETE FROM users WHERE id=$1",[userId]).catch(()=>{});
}

test('new Notification Outbox events persist only versioned routing metadata',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  let notificationId=null;
  try {
    const result=await repository.queueNotification({
      userId,
      type:'OUTBOX_V2_TEST',
      title:'Private title that must not enter Outbox',
      body:'Private body that must not enter Outbox',
      data:{sensitiveMarker:'must-remain-in-notifications'},
      channels:['IN_APP','PUSH'],
    });
    notificationId=result.notification.id;
    const {rows}=await pool.query(
      "SELECT event_type,aggregate_type,aggregate_id,payload FROM outbox_events WHERE event_type='NOTIFICATION_DISPATCH' AND aggregate_id=$1 ORDER BY payload->>'channel'",
      [notificationId],
    );
    assert.equal(rows.length,2);
    for(const row of rows){
      assert.equal(row.aggregate_type,'notification');
      assert.equal(row.aggregate_id,notificationId);
      assert.deepEqual(row.payload,{schemaVersion:2,channel:row.payload.channel});
      assert.ok(['IN_APP','PUSH'].includes(row.payload.channel));
    }
  } finally {
    await cleanup(userId,notificationId?[notificationId]:[]);
  }
});

test('v2 dispatch obtains recipient and notification content from canonical database rows',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  let notificationId=null;
  let eventId=null;
  try {
    const notification=await createNotification(userId);
    notificationId=notification.id;
    const token=await createDevice(userId);
    const event=await createEvent(notificationId,{schemaVersion:2,channel:'PUSH'});
    eventId=event.id;
    let delivery=null;
    const result=await notificationsRepo.dispatchNotificationOutbox(event,async(value)=>{delivery=value;});
    const terminalRow=await pool.query('SELECT status,terminal_at FROM outbox_events WHERE id=$1',[event.id]);
    assert.equal(terminalRow.rows[0].status,'DONE');
    assert.ok(terminalRow.rows[0].terminal_at,'successful notification delivery must stamp its terminal time');
    assert.equal(result.delivered,true);
    assert.equal(delivery.channel,'PUSH');
    assert.equal(delivery.targets.length,1);
    assert.equal(delivery.targets[0].token,token);
    assert.deepEqual(delivery.notification,{
      id:notification.id,
      userId,
      type:notification.type,
      title:notification.title,
      body:notification.body,
      data:notification.data,
    });
  } finally {
    await cleanup(userId,notificationId?[notificationId]:[],eventId?[eventId]:[]);
  }
});

test('legacy v1 dispatch ignores copied payload content and remains database-backed',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  let notificationId=null;
  let eventId=null;
  try {
    const notification=await createNotification(userId);
    notificationId=notification.id;
    const token=await createDevice(userId);
    const event=await createEvent(notificationId,{
      notificationId,
      userId:uuid(),
      type:'STALE_PAYLOAD_TYPE',
      channel:'PUSH',
      title:'Stale payload title must be ignored',
      body:'Stale payload body must be ignored',
      data:{staleMarker:'must-be-ignored'},
    });
    eventId=event.id;
    let delivery=null;
    const result=await notificationsRepo.dispatchNotificationOutbox(event,async(value)=>{delivery=value;});
    assert.equal(result.delivered,true);
    assert.equal(delivery.targets[0].token,token);
    assert.deepEqual(delivery.notification,{
      id:notification.id,
      userId,
      type:notification.type,
      title:notification.title,
      body:notification.body,
      data:notification.data,
    });
  } finally {
    await cleanup(userId,notificationId?[notificationId]:[],eventId?[eventId]:[]);
  }
});


test('account erasure cancels new content-free v2 notification Outbox events by canonical aggregate identity',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  let notificationId=null;
  let eventIds=[];
  try {
    const result=await repository.queueNotification({
      userId,
      type:'OUTBOX_V2_ERASURE_TEST',
      title:'Private title retained only in notification row',
      body:'Private body retained only in notification row',
      data:{sensitiveMarker:'do-not-copy-to-outbox'},
      channels:['IN_APP','PUSH'],
    });
    notificationId=result.notification.id;
    const before=await pool.query(
      "SELECT id,status,payload,lease_token FROM outbox_events WHERE event_type='NOTIFICATION_DISPATCH' AND aggregate_id=$1 ORDER BY payload->>'channel'",
      [notificationId],
    );
    eventIds=before.rows.map(row=>row.id);
    assert.equal(before.rowCount,2);
    for(const row of before.rows) {
      assert.deepEqual(row.payload,{schemaVersion:2,channel:row.payload.channel});
    }

    const erased=await repository.deleteUserPrivacyBundle(userId,{
      email:`deleted+${userId}@invalid.local`,
      passwordHash:'integration-only-erased-account-hash',
    });
    assert.equal(erased.deleted,true);

    const afterRows=await pool.query(
      'SELECT id,status,processed_at,lease_token,payload,terminal_at FROM outbox_events WHERE id=ANY($1::uuid[]) ORDER BY id',
      [eventIds],
    );
    assert.equal(afterRows.rowCount,2);
    for(const row of afterRows.rows) {
      assert.equal(row.status,'CANCELLED');
      assert.ok(row.processed_at);
      assert.ok(row.terminal_at,'account erasure cancellation must stamp its terminal time');
      assert.equal(row.lease_token,null);
      const original=before.rows.find(item=>item.id===row.id);
      assert.deepEqual(row.payload,original.payload,'erasure must preserve immutable v2 Outbox payload');
    }
    const audit=await pool.query(
      "SELECT meta FROM audit_logs WHERE action='NOTIFICATION_OUTBOX_CANCELLED_ACCOUNT_ERASURE' AND entity_id=$1",
      [userId],
    );
    assert.equal(audit.rowCount,1);
    assert.equal(audit.rows[0].meta.eventCount,2);
  } finally {
    await cleanup(userId,notificationId?[notificationId]:[],eventIds);
  }
});

after(async()=>{
  if(enabled) await dbModule.db.close();
});
