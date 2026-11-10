import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-notification-erasure-postgres.json';
process.env.NOTIFICATION_EMAIL_URL = 'https://notification.mock.invalid/email';
process.env.NOTIFICATION_PUSH_URL = 'https://notification.mock.invalid/push';
process.env.NOTIFICATION_PROVIDER_TOKEN = 'integration-only-notification-token';
process.env.NOTIFICATION_MAX_ATTEMPTS = '1';
process.env.NOTIFICATION_RETRY_BASE_MS = '0';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository.js'),
      import('../src/outbox_handlers.js'),
    ])
  : [];
const dbModule = modules[0];
const repository = modules[1];
const handlers = modules[2];
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const uuid = () => crypto.randomUUID();

async function createUser(email = `notification-erasure-${uuid()}@example.test`) {
  const id = uuid();
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES($1,$2,'integration-only-hash','Notification erasure test','USER','ACTIVE',0,NOW())`,
    [id,email],
  );
  return id;
}

async function createNotification(userId) {
  const id = uuid();
  await pool.query(
    `INSERT INTO notifications(id,user_id,type,title,body,data,created_at)
     VALUES($1,$2,'TEST','Private notification title','Private notification body',$3::jsonb,NOW())`,
    [id,userId,JSON.stringify({privateMarker:'immutable-payload-test'})],
  );
  return id;
}

async function createEvent({userId,notificationId,channel,status='PROCESSING'}) {
  const id = uuid();
  const leaseToken = status === 'PROCESSING' ? uuid() : null;
  const payload = {
    notificationId,
    userId,
    type:'TEST',
    channel,
    title:'Private notification title',
    body:'Private notification body',
    data:{privateMarker:'immutable-payload-test'},
  };
  const {rows} = await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,
       attempts,available_at,locked_at,lease_token,created_at
     ) VALUES(
       $1,'NOTIFICATION_DISPATCH','notification',$2,$3,$4::jsonb,$5,
       1,NOW(),CASE WHEN $5='PROCESSING' THEN NOW() ELSE NULL END,$6,NOW()
     )
     RETURNING id,status,lease_token`,
    [id,notificationId,`notification-erasure-test:${id}`,JSON.stringify(payload),status,leaseToken],
  );
  return {
    id:rows[0].id,
    event_type:'NOTIFICATION_DISPATCH',
    aggregate_type:'notification',
    aggregate_id:notificationId,
    status:rows[0].status,
    lease_token:rows[0].lease_token,
    payload,
  };
}

async function createDevice(userId, token = `device-token-${uuid()}`) {
  await pool.query(
    `INSERT INTO notification_devices(id,user_id,platform,token,enabled,created_at,updated_at)
     VALUES($1,$2,'ANDROID',$3,true,NOW(),NOW())`,
    [uuid(),userId,token],
  );
  return token;
}

function deletionReplacement(userId) {
  return {
    email:`deleted+${userId}@invalid.local`,
    passwordHash:'integration-only-deleted-account-hash',
  };
}

async function erase(userId) {
  return repository.deleteUserPrivacyBundle(userId,deletionReplacement(userId));
}

async function cleanup(userId,eventIds=[],notificationIds=[]) {
  if (!enabled) return;
  await pool.query('DELETE FROM outbox_events WHERE id=ANY($1::uuid[])',[eventIds]).catch(()=>{});
  await pool.query(
    'DELETE FROM audit_logs WHERE entity_id=$1 OR entity_id=ANY($2::uuid[])',
    [userId,eventIds],
  ).catch(()=>{});
  await pool.query('DELETE FROM notification_devices WHERE user_id=$1',[userId]).catch(()=>{});
  await pool.query('DELETE FROM notifications WHERE id=ANY($1::uuid[])',[notificationIds]).catch(()=>{});
  await pool.query('DELETE FROM users WHERE id=$1',[userId]).catch(()=>{});
}

test('migration 054 admits CANCELLED as a distinct Outbox terminal status',{skip:!enabled,timeout:30_000},async()=>{
  const id=uuid();
  try {
    await pool.query(
      `INSERT INTO outbox_events(id,event_type,aggregate_type,dedupe_key,payload,status,attempts,available_at,created_at)
       VALUES($1,'NOTIFICATION_DISPATCH','notification',$2,'{}'::jsonb,'CANCELLED',0,NOW(),NOW())`,
      [id,`cancelled-status-test:${id}`],
    );
    const {rows}=await pool.query('SELECT status FROM outbox_events WHERE id=$1',[id]);
    assert.equal(rows[0]?.status,'CANCELLED');
  } finally {
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[id]).catch(()=>{});
  }
});

test('only notification Outbox events may use the CANCELLED terminal status',{skip:!enabled,timeout:30_000},async()=>{
  const eventId=uuid();
  await assert.rejects(
    pool.query(
      `INSERT INTO outbox_events(
         id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,
         attempts,available_at,created_at
       ) VALUES(
         $1,'PAYMENT_RELEASE','payment',$2,$3,'{}'::jsonb,'CANCELLED',0,NOW(),NOW()
       )`,
      [eventId,uuid(),`cancelled-payment-must-be-rejected:${eventId}`],
    ),
    (error)=>error?.code==='23514' && error?.constraint==='outbox_events_status_check',
  );
});

test('account erasure cancels only PENDING and PROCESSING notification events, clears leases, audits counts, and preserves immutable payloads',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  const notificationId=await createNotification(userId);
  const pending=await createEvent({userId,notificationId,channel:'PUSH',status:'PENDING'});
  const processing=await createEvent({userId,notificationId,channel:'EMAIL',status:'PROCESSING'});
  const paymentId=uuid();
  const paymentEventId=uuid();
  const paymentLease=uuid();
  const paymentPayload={userId,amount:125,currency:'TOMAN',idempotencyKey:'payment-must-remain-untouched'};
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,
       attempts,available_at,locked_at,lease_token,created_at
     ) VALUES($1,'PAYMENT_RELEASE','payment',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW())`,
    [paymentEventId,paymentId,`payment-preservation-test:${paymentEventId}`,JSON.stringify(paymentPayload),paymentLease],
  );
  const eventIds=[pending.id,processing.id,paymentEventId];
  const before=await pool.query('SELECT id,payload FROM outbox_events WHERE id=ANY($1::uuid[]) ORDER BY id',[eventIds]);
  try {
    await erase(userId);
    const latePendingFailure=await repository.failOutboxEvent({eventId:pending.id,error:'late worker failure after erasure',maxAttempts:1});
    const lateProcessingFailure=await repository.failOutboxEvent({eventId:processing.id,error:'late worker failure after erasure',maxAttempts:1});
    assert.equal(latePendingFailure.alreadyCancelled,true);
    assert.equal(lateProcessingFailure.alreadyCancelled,true);
    const {rows}=await pool.query(
      'SELECT id,event_type,status,locked_at,lease_token,processed_at,payload FROM outbox_events WHERE id=ANY($1::uuid[]) ORDER BY id',
      [eventIds],
    );
    const rowsById=new Map(rows.map(row=>[row.id,row]));
    for (const event of [pending,processing]) {
      const row=rowsById.get(event.id);
      assert.equal(row.status,'CANCELLED',`notification event ${event.id} must be terminally cancelled`);
      assert.equal(row.locked_at,null);
      assert.equal(row.lease_token,null);
      assert.ok(row.processed_at);
      assert.deepEqual(row.payload,before.rows.find(item=>item.id===event.id).payload,
        'account erasure must not rewrite the immutable Outbox payload');
    }
    const payment=rowsById.get(paymentEventId);
    assert.equal(payment.status,'PROCESSING','financial events must not be cancelled by account erasure');
    assert.equal(payment.lease_token,paymentLease);
    assert.deepEqual(payment.payload,paymentPayload);
    const audit=await pool.query(
      `SELECT action,entity_type,entity_id,meta FROM audit_logs
        WHERE action='NOTIFICATION_OUTBOX_CANCELLED_ACCOUNT_ERASURE' AND entity_id=$1`,
      [userId],
    );
    assert.equal(audit.rowCount,1);
    assert.equal(audit.rows[0].entity_type,'user');
    assert.equal(audit.rows[0].meta.eventCount,2);
    assert.equal(JSON.stringify(audit.rows[0].meta).includes('Private notification body'),false);
  } finally {
    await cleanup(userId,eventIds,[notificationId]);
  }
});

test('a stale PUSH recipient snapshot cannot dispatch after account erasure commits',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  const notificationId=await createNotification(userId);
  const token=await createDevice(userId);
  const event=await createEvent({userId,notificationId,channel:'PUSH'});
  const originalFetch=globalThis.fetch;
  const requests=[];
  globalThis.fetch=async(url,options)=>{requests.push({url,options});return {ok:true,status:202};};
  try {
    const snapshot=await pool.query('SELECT token FROM notification_devices WHERE user_id=$1',[userId]);
    assert.equal(snapshot.rows[0]?.token,token);
    await erase(userId);
    await handlers.processOutboxEvent(event);
    assert.equal(requests.length,0,'the stale device token must not be sent after the erasure commit');
    const {rows}=await pool.query('SELECT status FROM outbox_events WHERE id=$1',[event.id]);
    assert.equal(rows[0]?.status,'CANCELLED');
  } finally {
    globalThis.fetch=originalFetch;
    await cleanup(userId,[event.id],[notificationId]);
  }
});

test('notification producer waits for account erasure and then refuses the deleted recipient',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  const blocker=await pool.connect();
  let producerSettled=false;
  let producerPromise;
  try {
    await blocker.query('BEGIN');
    await blocker.query('SELECT id FROM users WHERE id=$1 FOR NO KEY UPDATE',[userId]);
    producerPromise=repository.queueNotification({
      userId,
      type:'TEST_AFTER_ERASURE',
      title:'Must not persist',
      body:'Must not persist',
      data:{privateMarker:'producer-race'},
      channels:['IN_APP','PUSH','EMAIL'],
    }).then(result=>{producerSettled=true;return result;});
    await new Promise(resolve=>setTimeout(resolve,100));
    assert.equal(producerSettled,false,'producer must wait behind the erasure recipient lock');
    await blocker.query(`UPDATE users SET status='DELETED',email=$2 WHERE id=$1`,[userId,`deleted+${userId}@invalid.local`]);
    await blocker.query('COMMIT');
    const result=await producerPromise;
    assert.equal(result.created,false);
    assert.equal(result.reason,'RECIPIENT_UNAVAILABLE');
    const notifications=await pool.query('SELECT id FROM notifications WHERE user_id=$1',[userId]);
    const events=await pool.query(
      `SELECT id FROM outbox_events WHERE event_type='NOTIFICATION_DISPATCH' AND payload->>'userId'=$1`,
      [userId],
    );
    assert.equal(notifications.rowCount,0);
    assert.equal(events.rowCount,0);
  } finally {
    await blocker.query('ROLLBACK').catch(()=>{});
    blocker.release();
    await producerPromise?.catch(()=>{});
    await cleanup(userId,[],[]);
  }
});

test('EMAIL dispatch refuses the non-routable invalid.local erasure address',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser(`deleted+${uuid()}@invalid.local`);
  const notificationId=await createNotification(userId);
  const event=await createEvent({userId,notificationId,channel:'EMAIL'});
  const originalFetch=globalThis.fetch;
  const requests=[];
  globalThis.fetch=async(url,options)=>{requests.push({url,options});return {ok:true,status:202};};
  try {
    await handlers.processOutboxEvent(event);
    assert.equal(requests.length,0,'invalid.local must never be submitted to an email provider');
    const {rows}=await pool.query('SELECT status FROM outbox_events WHERE id=$1',[event.id]);
    assert.equal(rows[0]?.status,'CANCELLED');
  } finally {
    globalThis.fetch=originalFetch;
    await cleanup(userId,[event.id],[notificationId]);
  }
});

test('IN_APP dispatch with a missing notification is not recorded as delivered',{skip:!enabled,timeout:30_000},async()=>{
  const userId=await createUser();
  const missingNotificationId=uuid();
  const event=await createEvent({userId,notificationId:missingNotificationId,channel:'IN_APP'});
  try {
    await handlers.processOutboxEvent(event);
    const {rows}=await pool.query('SELECT status FROM outbox_events WHERE id=$1',[event.id]);
    assert.equal(rows[0]?.status,'CANCELLED','a missing notification must not become DONE/delivered');
  } finally {
    await cleanup(userId,[event.id],[]);
  }
});

test('worker recipient barrier serializes delivery before account-erasure commit',{skip:!enabled,timeout:30_000},async()=>{
  assert.equal(typeof repository.dispatchNotificationOutbox,'function');
  const userId=await createUser();
  const notificationId=await createNotification(userId);
  const token=await createDevice(userId);
  const event=await createEvent({userId,notificationId,channel:'PUSH'});
  let releaseSend;
  let onSendStarted;
  const sendGate=new Promise(resolve=>{releaseSend=resolve;});
  const sendStarted=new Promise(resolve=>{onSendStarted=resolve;});
  let sendAt=null;
  let deleteCommittedAt=null;
  let deliveryPromise;
  let deletionPromise;
  try {
    deliveryPromise=repository.dispatchNotificationOutbox(event,async({channel,targets})=>{
      assert.equal(channel,'PUSH');
      assert.equal(targets.length,1);
      assert.equal(targets[0].token,token);
      sendAt=Date.now();
      onSendStarted();
      await sendGate;
    });
    await sendStarted;
    deletionPromise=erase(userId).then(result=>{deleteCommittedAt=Date.now();return result;});
    await new Promise(resolve=>setTimeout(resolve,100));
    assert.equal(deleteCommittedAt,null,'erasure must wait while the worker holds the recipient barrier');
    releaseSend();
    const delivery=await deliveryPromise;
    await deletionPromise;
    assert.equal(delivery.delivered,true);
    assert.ok(sendAt<deleteCommittedAt,'the bounded send must finish before erasure commits when the worker owns the barrier');
    const {rows}=await pool.query('SELECT status FROM outbox_events WHERE id=$1',[event.id]);
    assert.equal(rows[0]?.status,'DONE');
  } finally {
    releaseSend?.();
    await deliveryPromise?.catch(()=>{});
    await deletionPromise?.catch(()=>{});
    await cleanup(userId,[event.id],[notificationId]);
  }
});

after(async()=>{
  if (enabled) await dbModule.db.close();
});
