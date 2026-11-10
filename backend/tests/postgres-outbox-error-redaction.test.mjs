import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const modules = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository/outbox.js'),
      import('../src/repository/payouts.js'),
    ])
  : [];
const dbModule = modules[0];
const outbox = modules[1];
const payoutsRepo = modules[2];
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const uuid = () => crypto.randomUUID();

async function createOutboxEvent({ eventType='NOTIFICATION_DISPATCH', aggregateType='notification', aggregateId=uuid(), payload={channel:'EMAIL'}, attempts=1 }) {
  const id = uuid();
  const leaseToken = uuid();
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,
       attempts,available_at,locked_at,lease_token,created_at
     ) VALUES($1,$2,$3,$4,$5,$6::jsonb,'PROCESSING',$7,NOW(),NOW(),$8,NOW())`,
    [id,eventType,aggregateType,aggregateId,`outbox-error-redaction:\${id}`,JSON.stringify(payload),attempts,leaseToken],
  );
  return { id, leaseToken, aggregateId };
}

async function createPayoutFixture() {
  const userId = uuid();
  const walletId = uuid();
  const operationId = uuid();
  const payoutId = uuid();
  const holdId = uuid();
  const eventId = uuid();
  const leaseToken = uuid();
  const idempotencyKey = 'outbox-redaction-payout:' + payoutId;
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at)
     VALUES($1,$2,'integration-only-hash','Outbox redaction test','USER','ACTIVE',0,NOW())`,
    [userId,'outbox-redaction-' + userId + '@example.test'],
  );
  await pool.query(
    `INSERT INTO wallet_accounts(id,user_id,currency,available_balance,locked_balance,status,created_at,updated_at)
     VALUES($1,$2,'TOMAN',0,500,'ACTIVE',NOW(),NOW())`,
    [walletId,userId],
  );
  await pool.query(
    `INSERT INTO financial_operations(id,operation_type,actor_type,actor_id,status,idempotency_key)
     VALUES($1,'PAYOUT','SYSTEM',NULL,'PROCESSING',$2)`,
    [operationId,idempotencyKey],
  );
  await pool.query(
    `INSERT INTO journals(operation_id,journal_type,currency,status)
     VALUES($1,'PAYOUT','TOMAN','CREATED')`,
    [operationId],
  );
  await pool.query(
    `INSERT INTO payouts(id,wallet_id,user_id,amount,currency,status,provider,idempotency_key,created_at,updated_at)
     VALUES($1,$2,$3,500,'TOMAN','RESERVED','internal',$4,NOW(),NOW())`,
    [payoutId,walletId,userId,idempotencyKey],
  );
  await pool.query(
    `INSERT INTO wallet_holds(id,wallet_id,hold_type,reference_type,reference_id,financial_operation_id,amount,status)
     VALUES($1,$2,'PAYOUT_RESERVATION','PAYOUT',$3,$4,500,'ACTIVE')`,
    [holdId,walletId,payoutId,operationId],
  );
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,
       attempts,available_at,locked_at,lease_token,created_at
     ) VALUES($1,'PAYOUT_EXECUTE','payout',$2,$3,$4::jsonb,'PROCESSING',1,NOW(),NOW(),$5,NOW())`,
    [eventId,payoutId,'PAYOUT_EXECUTE:' + payoutId,JSON.stringify({
      payoutId,userId,amount:'500',currency:'TOMAN',idempotencyKey,operationId,
    }),leaseToken],
  );
  return {userId,walletId,operationId,payoutId,holdId,eventId,leaseToken};
}

test('terminal notification Outbox failure stores allowlisted metadata and never raw error text',{skip:!enabled,timeout:30_000},async()=>{
  const event = await createOutboxEvent({payload:{schemaVersion:2,channel:'EMAIL'},attempts:1});
  const secret = 'Authorization Bearer private-token david@example.test raw-provider-response';
  const error = Object.assign(new Error(secret), {
    code:'UNTRUSTED_PROVIDER_ERROR',
    status:503,
    responseBody:secret,
  });
  try {
    const result = await outbox.failOutboxEvent({
      eventId:event.id,error,maxAttempts:1,leaseToken:event.leaseToken,
    });
    assert.equal(result.terminal,true);
    const row = (await pool.query(
      `SELECT status,last_error,last_error_code,last_error_category,last_error_retryable,
              last_error_http_status,terminal_at
         FROM outbox_events WHERE id=$1`,
      [event.id],
    )).rows[0];
    assert.equal(row.status,'FAILED');
    assert.equal(row.last_error,null);
    assert.equal(row.last_error_code,'OUTBOX_PROCESSING_FAILED');
    assert.equal(row.last_error_category,'email');
    assert.equal(row.last_error_retryable,false);
    assert.equal(row.last_error_http_status,null);
    assert.ok(row.terminal_at);
    assert.equal(JSON.stringify(row).includes(secret),false);
  } finally {
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[event.id]).catch(()=>{});
  }
});

test('retryable HTTP response persists only normalized provider code, status and retry flag',{skip:!enabled,timeout:30_000},async()=>{
  const event = await createOutboxEvent({payload:{schemaVersion:2,channel:'PUSH'},attempts:1});
  const error = Object.assign(new Error('NOTIFICATION_PROVIDER_HTTP_503'), {
    code:'NOTIFICATION_PROVIDER_HTTP_503',
    responseBody:'private push provider body',
  });
  try {
    const result = await outbox.failOutboxEvent({
      eventId:event.id,error,maxAttempts:3,leaseToken:event.leaseToken,
    });
    assert.equal(result.terminal,false);
    const row = (await pool.query(
      `SELECT status,last_error,last_error_code,last_error_category,last_error_retryable,
              last_error_http_status,terminal_at
         FROM outbox_events WHERE id=$1`,
      [event.id],
    )).rows[0];
    assert.equal(row.status,'PENDING');
    assert.equal(row.last_error,null);
    assert.equal(row.last_error_code,'NOTIFICATION_PROVIDER_HTTP_ERROR');
    assert.equal(row.last_error_category,'push');
    assert.equal(row.last_error_retryable,true);
    assert.equal(row.last_error_http_status,503);
    assert.equal(row.terminal_at,null);
  } finally {
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[event.id]).catch(()=>{});
  }
});

test('payout terminal failure redacts provider exception and preserves wallet reversal invariants',{skip:!enabled,timeout:30_000},async()=>{
  const fixture = await createPayoutFixture();
  const secret = 'Bearer provider-secret payout@example.test raw-PSP-response';
  const error = Object.assign(new Error(secret), {
    code:'PRIVATE_PROVIDER_ERROR_CODE',
    status:503,
    responseBody:secret,
  });
  const result = await outbox.failOutboxEvent({
    eventId:fixture.eventId,error,maxAttempts:1,leaseToken:fixture.leaseToken,
  });
  assert.equal(result.terminal,true);
  const payout = (await pool.query(
    `SELECT status,failure_code,failure_message,failure_category,failure_retryable,failure_http_status
       FROM payouts WHERE id=$1`,
    [fixture.payoutId],
  )).rows[0];
  assert.equal(payout.status,'FAILED');
  assert.equal(payout.failure_code,'PAYOUT_PROVIDER_FAILED');
  assert.equal(payout.failure_message,null);
  assert.equal(payout.failure_category,'payout');
  assert.equal(payout.failure_retryable,false);
  assert.equal(payout.failure_http_status,null);
  const event = (await pool.query(
    `SELECT status,last_error,last_error_code,last_error_category,last_error_retryable,last_error_http_status
       FROM outbox_events WHERE id=$1`,
    [fixture.eventId],
  )).rows[0];
  assert.equal(event.status,'FAILED');
  assert.equal(event.last_error,null);
  assert.equal(event.last_error_code,'PAYOUT_PROVIDER_FAILED');
  assert.equal(event.last_error_category,'payout');
  assert.equal(event.last_error_retryable,false);
  assert.equal(JSON.stringify({payout,event}).includes(secret),false);
  const wallet = (await pool.query(
    'SELECT available_balance,locked_balance FROM wallet_accounts WHERE id=$1',
    [fixture.walletId],
  )).rows[0];
  assert.equal(String(wallet.available_balance),'500');
  assert.equal(String(wallet.locked_balance),'0');
  const hold = (await pool.query('SELECT status FROM wallet_holds WHERE id=$1',[fixture.holdId])).rows[0];
  assert.equal(hold.status,'CANCELLED');
  const operation = (await pool.query('SELECT status FROM financial_operations WHERE id=$1',[fixture.operationId])).rows[0];
  assert.equal(operation.status,'FAILED');
  const journal = (await pool.query('SELECT status FROM journals WHERE operation_id=$1',[fixture.operationId])).rows[0];
  assert.equal(journal.status,'FAILED');
  const reversal = await pool.query(
    `SELECT direction,amount,currency FROM wallet_entries
      WHERE financial_operation_id=$1 AND reference_id=$2`,
    [fixture.operationId,fixture.payoutId],
  );
  assert.equal(reversal.rowCount,1);
  assert.equal(reversal.rows[0].direction,'CREDIT');
  assert.equal(String(reversal.rows[0].amount),'500');
  assert.equal(reversal.rows[0].currency,'TOMAN');
});

test('legacy payout failure_message is not returned by user payout reads',{skip:!enabled,timeout:30_000},async()=>{
  const fixture = await createPayoutFixture();
  const legacySecret = 'legacy raw failure with bearer token and payout@example.test';
  await pool.query('UPDATE payouts SET failure_message=$2 WHERE id=$1',[fixture.payoutId,legacySecret]);
  const rows = await payoutsRepo.listPayoutsForUser(fixture.userId);
  assert.equal(rows.length,1);
  assert.equal('failureMessage' in rows[0],false);
  const item = await payoutsRepo.getPayoutForUser(fixture.userId,fixture.payoutId);
  assert.equal('failure_message' in item,false);
  assert.equal('failureMessage' in item,false);
});

after(async()=>{
  if (enabled) await dbModule.db.close();
});
