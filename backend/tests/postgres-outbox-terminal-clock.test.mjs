import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-outbox-terminal-clock-postgres.json';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const [dbModule, repository, migrationModule] = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository.js'),
      import('../src/db/migrations/055_outbox_terminal_clock.js').catch(() => null),
    ])
  : [];
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const uuid = () => crypto.randomUUID();
const createdEventIds = [];

async function createEvent({status='PENDING',attempts=0,leaseToken=null,eventType='OUTBOX_TERMINAL_CLOCK_TEST'}={}) {
  const id=uuid();
  const key='terminal-clock-test:'+id;
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,
       attempts,available_at,locked_at,lease_token,created_at
     ) VALUES($1,$2,'test_resource',NULL,$3,'{}'::jsonb,$4,$5,NOW(),$6,$7,NOW())`,
    [id,eventType,key,status,attempts,status==='PROCESSING'?new Date():null,leaseToken],
  );
  createdEventIds.push(id);
  return {id,leaseToken};
}

test('migration 055 is registered and applied by the PostgreSQL migration runner',{skip:!enabled,timeout:30_000},async()=>{
  assert.ok(migrationModule?.migration,'migration 055 module must exist');
  assert.equal(migrationModule.migration.version,55);
  assert.equal(migrationModule.migration.name,'outbox_terminal_clock');
  const {rows}=await pool.query(
    "SELECT version,name,checksum FROM schema_migrations WHERE version=55",
  );
  assert.equal(rows.length,1);
  assert.equal(rows[0].name,'outbox_terminal_clock');
  assert.match(rows[0].checksum,/^[a-f0-9]{64}$/);
  const column=await pool.query(
    "SELECT data_type,is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name='outbox_events' AND column_name='terminal_at'",
  );
  assert.equal(column.rowCount,1);
  assert.equal(column.rows[0].data_type,'timestamp with time zone');
  assert.equal(column.rows[0].is_nullable,'YES');
});

test('generic terminal failure stamps once and duplicate failure callbacks preserve the original time',{skip:!enabled,timeout:30_000},async()=>{
  const leaseToken=uuid();
  const event=await createEvent({status:'PROCESSING',attempts:1,leaseToken});
  const first=await repository.failOutboxEvent({
    eventId:event.id,
    error:new Error('integration-only failure'),
    maxAttempts:1,
    leaseToken,
  });
  assert.equal(first.terminal,true);
  const before=await pool.query(
    'SELECT status,terminal_at FROM outbox_events WHERE id=$1',
    [event.id],
  );
  assert.equal(before.rows[0].status,'FAILED');
  assert.ok(before.rows[0].terminal_at);
  const repeated=await repository.failOutboxEvent({
    eventId:event.id,
    error:new Error('late duplicate callback'),
    maxAttempts:1,
    leaseToken,
  });
  assert.equal(repeated.alreadyFailed,true);
  const afterRow=await pool.query(
    'SELECT status,terminal_at FROM outbox_events WHERE id=$1',
    [event.id],
  );
  assert.equal(afterRow.rows[0].status,'FAILED');
  assert.equal(afterRow.rows[0].terminal_at.toISOString(),before.rows[0].terminal_at.toISOString());
});

test('retryable failure and terminal-to-pending requeue clear terminal_at',{skip:!enabled,timeout:30_000},async()=>{
  const leaseToken=uuid();
  const event=await createEvent({status:'PROCESSING',attempts:1,leaseToken});
  const result=await repository.failOutboxEvent({
    eventId:event.id,
    error:new Error('retryable integration failure'),
    maxAttempts:3,
    leaseToken,
  });
  assert.equal(result.terminal,false);
  let row=(await pool.query('SELECT status,terminal_at FROM outbox_events WHERE id=$1',[event.id])).rows[0];
  assert.equal(row.status,'PENDING');
  assert.equal(row.terminal_at,null);

  await pool.query(
    "UPDATE outbox_events SET status='FAILED' WHERE id=$1",
    [event.id],
  );
  row=(await pool.query('SELECT status,terminal_at FROM outbox_events WHERE id=$1',[event.id])).rows[0];
  assert.equal(row.status,'FAILED');
  assert.ok(row.terminal_at);

  await pool.query(
    "UPDATE outbox_events SET status='PENDING' WHERE id=$1",
    [event.id],
  );
  row=(await pool.query('SELECT status,terminal_at FROM outbox_events WHERE id=$1',[event.id])).rows[0];
  assert.equal(row.status,'PENDING');
  assert.equal(row.terminal_at,null);
});

test('generic completion sets terminal_at and repeated DONE callbacks preserve it',{skip:!enabled,timeout:30_000},async()=>{
  const leaseToken=uuid();
  const event=await createEvent({status:'PROCESSING',attempts:1,leaseToken});
  const completed=await repository.completeOutboxEvent({eventId:event.id,leaseToken});
  assert.deepEqual(completed,{completed:true,alreadyDone:false});
  const before=(await pool.query(
    'SELECT status,terminal_at FROM outbox_events WHERE id=$1',[event.id],
  )).rows[0];
  assert.equal(before.status,'DONE');
  assert.ok(before.terminal_at);
  const duplicate=await repository.completeOutboxEvent({eventId:event.id,leaseToken});
  assert.deepEqual(duplicate,{completed:true,alreadyDone:true});
  const afterRow=(await pool.query(
    'SELECT status,terminal_at FROM outbox_events WHERE id=$1',[event.id],
  )).rows[0];
  assert.equal(afterRow.terminal_at.toISOString(),before.terminal_at.toISOString());
});

test('CANCELLED is terminal and a terminal timestamp is rejected on active events',{skip:!enabled,timeout:30_000},async()=>{
  const event=await createEvent({status:'PENDING',eventType:'NOTIFICATION_DISPATCH'});
  await pool.query("UPDATE outbox_events SET aggregate_type='notification',status='CANCELLED' WHERE id=$1",[event.id]);
  let row=(await pool.query('SELECT status,terminal_at FROM outbox_events WHERE id=$1',[event.id])).rows[0];
  assert.equal(row.status,'CANCELLED');
  assert.ok(row.terminal_at);
  const activeEvent=await createEvent({status:'PENDING'});
  await pool.query(
    'UPDATE outbox_events SET terminal_at=NOW() WHERE id=$1',
    [activeEvent.id],
  );
  const activeRow=(await pool.query(
    'SELECT status,terminal_at FROM outbox_events WHERE id=$1',[activeEvent.id],
  )).rows[0];
  assert.equal(activeRow.status,'PENDING');
  assert.equal(activeRow.terminal_at,null,'the trigger must reject caller-supplied terminal time on an active event');
});

after(async()=>{
  if(enabled) {
    if(createdEventIds.length) {
      await pool.query('DELETE FROM outbox_events WHERE id=ANY($1::uuid[])',[createdEventIds]).catch(()=>{});
    }
    await dbModule.db.close();
  }
});
