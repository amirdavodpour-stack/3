import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const dbModule = enabled ? await import('../src/db.js') : null;
const outboxRegistry = enabled
  ? await import('../src/repository/outbox_dedupe_registry.js').catch(() => null)
  : null;
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const createOrReuse = outboxRegistry?.createOrReuseOutboxEventWithClient;
const uuid = () => crypto.randomUUID();
const hashKey = (key) => crypto.createHash('sha256').update(key, 'utf8').digest('hex');

function request({ key, eventId=uuid(), aggregateId=uuid(), payload={value:1}, identityMode='FULL', conflictPolicy='DO_NOTHING' }) {
  return {
    eventId,
    dedupeKey:key,
    eventType:'TEST_DEDUPE_EVENT',
    aggregateType:'test_aggregate',
    aggregateId,
    payload,
    identityMode,
    conflictPolicy,
  };
}

async function create(input) {
  return dbModule.withSqlTransaction((client) => createOrReuse(client,input));
}

async function cleanup(key) {
  const keyHash=hashKey(key);
  await pool.query('DELETE FROM outbox_events WHERE dedupe_key=$1',[key]).catch(()=>{});
  await pool.query('DELETE FROM outbox_dedupe_registry WHERE dedupe_key_hash=$1',[keyHash]).catch(()=>{});
}

test('migration creates a digest-only registry with no raw key or payload columns',{skip:!enabled,timeout:30_000},async()=>{
  const table=await pool.query("SELECT to_regclass('public.outbox_dedupe_registry') AS name");
  assert.ok(table.rows[0]?.name,'outbox_dedupe_registry must exist after migration 057');
  const result=await pool.query("SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='outbox_dedupe_registry'");
  const columns=new Set(result.rows.map(row=>row.column_name));
  for (const name of ['dedupe_key_hash','event_id','event_type','identity_mode','state','terminal_status','terminal_at','archived_at','tombstoned_at','hash_version']) {
    assert.ok(columns.has(name),'missing registry column ' + name);
  }
  for (const forbidden of ['dedupe_key','payload','aggregate_id','user_id']) {
    assert.equal(columns.has(forbidden),false,'registry must not duplicate ' + forbidden);
  }
});

test('central Outbox registry writer is available',{skip:!enabled,timeout:30_000},()=>{
  assert.equal(typeof createOrReuse,'function','createOrReuseOutboxEventWithClient must be exported');
});

test('concurrent identical reservations resolve to one stable Outbox event ID',{skip:!enabled || typeof createOrReuse!=='function',timeout:30_000},async()=>{
  const key='dedupe-concurrent:' + uuid();
  const inputA=request({key});
  const inputB={...inputA,eventId:uuid()};
  try {
    const results=await Promise.all([create(inputA),create(inputB)]);
    assert.equal(results[0].id,results[1].id);
    assert.equal(results[0].created,true);
    assert.equal(results[1].created,false);
    const stored=await pool.query('SELECT id FROM outbox_events WHERE dedupe_key=$1',[key]);
    assert.equal(stored.rowCount,1);
  } finally {
    await cleanup(key);
  }
});

test('FULL identity rejects same key with a changed immutable payload',{skip:!enabled || typeof createOrReuse!=='function',timeout:30_000},async()=>{
  const key='dedupe-full-conflict:' + uuid();
  const first=request({key,payload:{amount:100,currency:'TOMAN'}});
  try {
    const created=await create(first);
    await assert.rejects(
      create({...first,eventId:uuid(),payload:{amount:101,currency:'TOMAN'}}),
      (error)=>error?.code==='OUTBOX_DEDUPE_IDENTITY_CONFLICT',
    );
    const row=(await pool.query('SELECT id,payload FROM outbox_events WHERE id=$1',[created.id])).rows[0];
    assert.deepEqual(row.payload,{amount:100,currency:'TOMAN'});
  } finally {
    await cleanup(key);
  }
});

test('AGGREGATE first-wins mode preserves the first payload for refresh-reuse bucket collisions',{skip:!enabled || typeof createOrReuse!=='function',timeout:30_000},async()=>{
  const key='auth-refresh-reuse:' + uuid() + ':bucket';
  const aggregateId=uuid();
  const first=request({key,aggregateId,payload:{tokenFamilyId:uuid()},identityMode:'AGGREGATE'});
  const second={...first,eventId:uuid(),payload:{tokenFamilyId:uuid()}};
  try {
    const a=await create(first);
    const b=await create(second);
    assert.equal(a.id,b.id);
    assert.equal(b.created,false);
    const row=(await pool.query('SELECT payload FROM outbox_events WHERE id=$1',[a.id])).rows[0];
    assert.deepEqual(row.payload,first.payload);
  } finally {
    await cleanup(key);
  }
});

test('same dedupe key cannot be reused for a different aggregate identity',{skip:!enabled || typeof createOrReuse!=='function',timeout:30_000},async()=>{
  const key='dedupe-aggregate-conflict:' + uuid();
  const first=request({key,identityMode:'AGGREGATE'});
  try {
    await create(first);
    await assert.rejects(
      create({...first,eventId:uuid(),aggregateId:uuid()}),
      (error)=>error?.code==='OUTBOX_DEDUPE_IDENTITY_CONFLICT',
    );
  } finally {
    await cleanup(key);
  }
});

test('REQUEUE_IF_FAILED reuses the original event ID and clears terminal/error state',{skip:!enabled || typeof createOrReuse!=='function',timeout:30_000},async()=>{
  const key='dedupe-requeue:' + uuid();
  const input=request({key,conflictPolicy:'REQUEUE_IF_FAILED'});
  try {
    const first=await create(input);
    await pool.query("UPDATE outbox_events SET status='FAILED',attempts=4,last_error_code='OUTBOX_PROCESSING_FAILED',last_error_category='system',last_error_retryable=FALSE WHERE id=$1",[first.id]);
    const second=await create({...input,eventId:uuid()});
    assert.equal(second.id,first.id);
    assert.equal(second.status,'PENDING');
    const row=(await pool.query('SELECT id,status,attempts,last_error_code,last_error_category,terminal_at FROM outbox_events WHERE id=$1',[first.id])).rows[0];
    assert.equal(row.id,first.id);
    assert.equal(row.status,'PENDING');
    assert.equal(row.attempts,0);
    assert.equal(row.last_error_code,null);
    assert.equal(row.last_error_category,null);
    assert.equal(row.terminal_at,null);
  } finally {
    await cleanup(key);
  }
});

test('tombstoned key never creates a second Outbox event after the original row is removed',{skip:!enabled || typeof createOrReuse!=='function',timeout:30_000},async()=>{
  const key='dedupe-tombstone:' + uuid();
  const input=request({key});
  try {
    const first=await create(input);
    await pool.query("UPDATE outbox_dedupe_registry SET state='TOMBSTONED',terminal_status='DONE',terminal_at=NOW(),tombstoned_at=NOW() WHERE dedupe_key_hash=$1",[hashKey(key)]);
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[first.id]);
    const result=await create({...input,eventId:uuid()});
    assert.equal(result.tombstoned,true);
    assert.equal(result.id,first.id);
    const count=await pool.query('SELECT COUNT(*)::int AS count FROM outbox_events WHERE dedupe_key=$1',[key]);
    assert.equal(count.rows[0].count,0);
  } finally {
    await cleanup(key);
  }
});

test('ACTIVE registry row with a missing Outbox event fails closed rather than creating a replacement',{skip:!enabled || typeof createOrReuse!=='function',timeout:30_000},async()=>{
  const key='dedupe-orphan:' + uuid();
  const input=request({key});
  try {
    const first=await create(input);
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[first.id]);
    await assert.rejects(
      create({...input,eventId:uuid()}),
      (error)=>error?.code==='OUTBOX_DEDUPE_REGISTRY_ORPHANED',
    );
  } finally {
    await cleanup(key);
  }
});

after(async()=>{
  if (enabled) await dbModule.db.close();
});
