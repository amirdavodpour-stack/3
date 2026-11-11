import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-outbox-dedupe-registry-postgres.json';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const [dbModule, repository, migrationModule] = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository.js'),
      import('../src/db/migrations/057_outbox_dedupe_registry.js').catch(() => null),
    ])
  : [null, null, null];

if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const uuid = () => crypto.randomUUID();
const digestKey = (value) => crypto.createHash('sha256')
  .update('hopev2:outbox-dedupe:v1\0', 'utf8')
  .update(String(value), 'utf8')
  .digest();

const hasReservation = typeof repository?.reserveOutboxDedupeKeyWithClient === 'function';

async function reserveOnly({
  dedupeKey,
  eventType='TEST_DEDUPE_EVENT',
  aggregateType='test',
  aggregateId=uuid(),
  conflictPolicy='CREATE_ONLY',
}={}) {
  const candidateEventId = uuid();
  return dbModule.withSqlTransaction((client) => repository.reserveOutboxDedupeKeyWithClient(client,{
    eventId:candidateEventId,
    eventType,
    aggregateType,
    aggregateId,
    dedupeKey,
    conflictPolicy,
  }));
}

async function reserveAndInsert({
  dedupeKey,
  eventType='TEST_DEDUPE_EVENT',
  aggregateType='test',
  aggregateId=uuid(),
  conflictPolicy='CREATE_ONLY',
}={}) {
  const candidateEventId = uuid();
  return dbModule.withSqlTransaction(async(client)=>{
    const reservation=await repository.reserveOutboxDedupeKeyWithClient(client,{
      eventId:candidateEventId,
      eventType,
      aggregateType,
      aggregateId,
      dedupeKey,
      conflictPolicy,
    });
    if(reservation.created){
      await client.query(
        "INSERT INTO outbox_events(id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,attempts,available_at,created_at) VALUES($1,$2,$3,$4,$5,'{}'::jsonb,'PENDING',0,NOW(),NOW())",
        [reservation.eventId,eventType,aggregateType,aggregateId,dedupeKey],
      );
    }
    return reservation;
  });
}

async function cleanup(eventId) {
  if (!enabled || !eventId) return;
  await pool.query('DELETE FROM outbox_events WHERE id=$1',[eventId]).catch(()=>{});
  await pool.query('DELETE FROM outbox_dedupe_registry WHERE original_event_id=$1',[eventId]).catch(()=>{});
}

test('migration 057 exists and is applied by the isolated PostgreSQL migration runner',{
  skip:!enabled,
  timeout:30_000,
},async()=>{
  assert.ok(migrationModule?.migration,'migration 057 module must exist');
  assert.equal(migrationModule.migration.version,57);
  assert.equal(migrationModule.migration.name,'outbox_dedupe_registry');
  const {rows}=await pool.query('SELECT version,name,checksum FROM schema_migrations WHERE version=57');
  assert.equal(rows.length,1);
  assert.equal(rows[0].name,'outbox_dedupe_registry');
  assert.match(rows[0].checksum,/^[a-f0-9]{64}$/);
});

test('registry schema has the required identity fields and contains no raw key or payload',{
  skip:!enabled,
  timeout:30_000,
},async()=>{
  const {rows}=await pool.query(
    "SELECT column_name FROM information_schema.columns WHERE table_schema=current_schema() AND table_name='outbox_dedupe_registry'",
  );
  const columns=new Set(rows.map(row=>row.column_name));
  for(const name of ['key_digest','digest_version','original_event_id','event_type','aggregate_type','aggregate_id','conflict_policy','state','created_at']){
    assert.ok(columns.has(name),'registry missing column '+name);
  }
  assert.equal(columns.has('dedupe_key'),false,'registry must not retain raw dedupe keys');
  assert.equal(columns.has('payload'),false,'registry must not duplicate event payload');
});

test('migration backfill preserves every current non-null key to its original event UUID and identity',{
  skip:!enabled,
  timeout:30_000,
},async()=>{
  const {rows}=await pool.query("SELECT id,dedupe_key,event_type,aggregate_type,aggregate_id FROM outbox_events WHERE dedupe_key IS NOT NULL");
  for(const event of rows){
    const {rows:registryRows}=await pool.query(
      "SELECT original_event_id,event_type,aggregate_type,aggregate_id,state FROM outbox_dedupe_registry WHERE key_digest=$1",
      [digestKey(event.dedupe_key)],
    );
    assert.equal(registryRows.length,1,'every existing non-null Outbox key must be backfilled');
    assert.equal(registryRows[0].original_event_id,event.id);
    assert.equal(registryRows[0].event_type,event.event_type);
    assert.equal(registryRows[0].aggregate_type,event.aggregate_type);
    assert.equal(registryRows[0].aggregate_id,event.aggregate_id);
    assert.equal(registryRows[0].state,'ACTIVE');
  }
});

test('concurrent identical reservations create one event and return the original event UUID',{
  skip:!enabled || !hasReservation,
  timeout:30_000,
},async()=>{
  const dedupeKey='dedupe-concurrency:'+uuid();
  const aggregateId=uuid();
  const args={dedupeKey,eventType:'AUTH_REFRESH_REUSE_ALERT',aggregateType:'user',aggregateId,conflictPolicy:'FIRST_WINS'};
  let firstEventId=null;
  let secondEventId=null;
  try{
    const results=await Promise.all([reserveAndInsert(args),reserveAndInsert(args)]);
    firstEventId=results[0].eventId;
    secondEventId=results[1].eventId;
    assert.equal(results[0].created,true);
    assert.equal(results[1].created,false);
    assert.equal(firstEventId,secondEventId);
    const {rows}=await pool.query('SELECT id FROM outbox_events WHERE dedupe_key=$1',[dedupeKey]);
    assert.equal(rows.length,1);
    assert.equal(rows[0].id,firstEventId);
  }finally{
    if(firstEventId) await cleanup(firstEventId);
    if(secondEventId && secondEventId!==firstEventId) await cleanup(secondEventId);
  }
});

test('same dedupe key with a different event class or aggregate fails closed',{
  skip:!enabled || !hasReservation,
  timeout:30_000,
},async()=>{
  const dedupeKey='dedupe-identity-conflict:'+uuid();
  const aggregateId=uuid();
  const first=await reserveAndInsert({dedupeKey,eventType:'PAYMENT_RELEASE',aggregateType:'payment',aggregateId,conflictPolicy:'STATUS_GATED_REQUEUE'});
  try{
    await assert.rejects(
      reserveAndInsert({dedupeKey,eventType:'PAYMENT_REFUND',aggregateType:'payment',aggregateId,conflictPolicy:'STATUS_GATED_REQUEUE'}),
      error=>error?.code==='OUTBOX_DEDUPE_IDENTITY_CONFLICT',
    );
    await assert.rejects(
      reserveAndInsert({dedupeKey,eventType:'PAYMENT_RELEASE',aggregateType:'payment',aggregateId:uuid(),conflictPolicy:'STATUS_GATED_REQUEUE'}),
      error=>error?.code==='OUTBOX_DEDUPE_IDENTITY_CONFLICT',
    );
    const {rows}=await pool.query('SELECT id,event_type,aggregate_id FROM outbox_events WHERE dedupe_key=$1',[dedupeKey]);
    assert.equal(rows.length,1);
    assert.equal(rows[0].id,first.eventId);
    assert.equal(rows[0].event_type,'PAYMENT_RELEASE');
    assert.equal(rows[0].aggregate_id,aggregateId);
  }finally{
    await cleanup(first.eventId);
  }
});

test('FIRST_WINS returns the original refresh alert across same-key retries without changing its identity',{
  skip:!enabled || !hasReservation,
  timeout:30_000,
},async()=>{
  const dedupeKey='dedupe-first-wins:'+uuid();
  const aggregateId=uuid();
  const args={dedupeKey,eventType:'AUTH_REFRESH_REUSE_ALERT',aggregateType:'user',aggregateId,conflictPolicy:'FIRST_WINS'};
  let original=null;
  try{
    original=await reserveAndInsert(args);
    const retry=await reserveAndInsert(args);
    assert.equal(original.created,true);
    assert.equal(retry.created,false);
    assert.equal(retry.eventId,original.eventId);
    const {rows}=await pool.query('SELECT id,payload FROM outbox_events WHERE dedupe_key=$1',[dedupeKey]);
    assert.equal(rows.length,1);
    assert.equal(rows[0].id,original.eventId);
    assert.deepEqual(rows[0].payload,{});
  }finally{
    if(original) await cleanup(original.eventId);
  }
});

test('an ACTIVE registry key without its original Outbox event is an orphan and cannot create a replacement',{
  skip:!enabled || !hasReservation,
  timeout:30_000,
},async()=>{
  const dedupeKey='dedupe-orphan:'+uuid();
  const args={dedupeKey,eventType:'NOTIFICATION_DISPATCH',aggregateType:'notification',aggregateId:uuid(),conflictPolicy:'FIRST_WINS'};
  let original=null;
  try{
    original=await reserveOnly(args);
    assert.equal(original.created,true);
    await assert.rejects(
      reserveAndInsert(args),
      error=>error?.code==='OUTBOX_DEDUPE_ORPHANED',
    );
  }finally{
    if(original) await cleanup(original.eventId);
  }
});

test('a TOMBSTONED dedupe key cannot create a new Outbox event UUID',{
  skip:!enabled || !hasReservation,
  timeout:30_000,
},async()=>{
  const dedupeKey='dedupe-tombstone:'+uuid();
  const args={dedupeKey,eventType:'NOTIFICATION_DISPATCH',aggregateType:'notification',aggregateId:uuid(),conflictPolicy:'FIRST_WINS'};
  let original=null;
  try{
    original=await reserveAndInsert(args);
    await pool.query("UPDATE outbox_dedupe_registry SET state='TOMBSTONED',tombstoned_at=NOW() WHERE original_event_id=$1",[original.eventId]);
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[original.eventId]);
    await assert.rejects(
      reserveAndInsert(args),
      error=>error?.code==='OUTBOX_DEDUPE_TOMBSTONED',
    );
  }finally{
    if(original) await cleanup(original.eventId);
  }
});

after(async()=>{
  if(enabled) await dbModule.db.close();
});
