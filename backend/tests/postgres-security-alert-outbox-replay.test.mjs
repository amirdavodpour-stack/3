import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV = 'test';
process.env.DATA_FILE ||= '/tmp/hope-security-alert-replay-postgres.json';

const enabled = Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION === '1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const [dbModule, repository, migrationModule, outboxHandlers, configModule] = enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository.js'),
      import('../src/db/migrations/053_security_alert_outbox_manual_replay.js').catch(() => null),
      import('../src/outbox_handlers.js'),
      import('../src/config.js'),
    ])
  : [null, null, null, null, null];

if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const hasReplay = typeof repository?.replaySecurityAlert === 'function';

const PRIMARY_ADMIN_EMAIL = 'amir.davodpour@gmail.com';
const uuid = () => crypto.randomUUID();

async function createAdmin({
  email = PRIMARY_ADMIN_EMAIL,
  role = 'ADMIN',
  googleSubject = 'verified-primary-' + uuid(),
  verifiedAt = new Date(),
  verifiedJti = 'admin-session-' + uuid(),
  verifiedScope = 'WRITE',
} = {}) {
  const id = uuid();
  await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,created_at,
       google_subject,admin_panel_verified_at,admin_panel_verified_session_jti,
       admin_panel_verified_scope
     ) VALUES($1,$2,'integration-only-hash','Replay Test Admin',$3,'ACTIVE',0,NOW(),$4,$5,$6,$7)`,
    [id,email,role,googleSubject,verifiedAt,verifiedJti,verifiedScope],
  );
  return { id,email,role,googleSubject,sessionJti:verifiedJti };
}

async function createFailedEvent({
  eventType = 'AUTH_REFRESH_REUSE_ALERT',
  aggregateType = 'user',
  aggregateId = uuid(),
  status = 'FAILED',
  attempts = 4,
  leaseToken = null,
  lockedAt = null,
} = {}) {
  const id = uuid();
  const payload = { accountId:aggregateId, alertCode:'AUTH_REFRESH_REUSE', occurredAt:new Date().toISOString() };
  const dedupeKey = 'replay-test:' + id;
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,dedupe_key,payload,status,
       attempts,available_at,locked_at,lease_token,last_error,created_at
     ) VALUES($1,$2,$3,$4,$5,$6::jsonb,$7,$8,NOW(),$9,$10,'previous delivery failed',NOW()-INTERVAL '1 minute')`,
    [id,eventType,aggregateType,aggregateId,dedupeKey,JSON.stringify(payload),status,attempts,lockedAt,leaseToken],
  );
  return { id,eventType,aggregateType,aggregateId,dedupeKey,payload,attempts };
}

async function cleanup(eventId, actorId) {
  if (eventId) {
    await pool.query('DELETE FROM audit_logs WHERE entity_id=$1',[eventId]).catch(() => {});
    await pool.query('DELETE FROM outbox_events WHERE id=$1',[eventId]).catch(() => {});
  }
  if (actorId) {
    await pool.query('DELETE FROM audit_logs WHERE actor_id=$1',[actorId]).catch(() => {});
    await pool.query('DELETE FROM users WHERE id=$1',[actorId]).catch(() => {});
  }
}

function replayArgs(admin, event, idempotencyKey = 'admin-replay:' + event.id, overrides = {}) {
  return {
    eventId:event.id,
    actorId:admin.id,
    sessionJti:admin.sessionJti,
    verificationMinutes:5,
    reason:'Verified receiver was restored; replaying the failed security alert.',
    idempotencyKey,
    ...overrides,
  };
}

test('migration 053 exists and was applied by the PostgreSQL migration runner', {
  skip:!enabled,
  timeout:30_000,
}, async () => {
  const {rows} = await pool.query(
    'SELECT version,name,checksum FROM schema_migrations WHERE version=53',
  );
  assert.ok(migrationModule?.migration,'migration 053 module must exist');
  assert.equal(migrationModule.migration.version,53);
  assert.equal(migrationModule.migration.name,'security_alert_outbox_manual_replay');
  assert.equal(rows.length,1,'migration 053 must be applied in the isolated PostgreSQL test database');
  assert.equal(rows[0].name,'security_alert_outbox_manual_replay');
  assert.match(rows[0].checksum,/^[a-f0-9]{64}$/);
});

test('migration 053 refuses rollback after any manual replay has been used', {
  skip:!migrationModule?.migration,
}, async () => {
  const statements = [];
  const client = {
    query:async (sql) => {
      statements.push(String(sql));
      return {rows:[{used_count:'1'}],rowCount:1};
    },
  };
  await assert.rejects(
    migrationModule.migration.down(client),
    /cannot be rolled back after a security alert replay has been used/i,
  );
  assert.equal(statements.length,2,'the migration must lock the Outbox table before checking replay evidence');
  assert.match(statements[0],/LOCK TABLE outbox_events IN ACCESS EXCLUSIVE MODE/);
  assert.match(statements[1],/SELECT COUNT\(\*\)::int AS used_count/);
});

test('repository exposes a dedicated security-alert replay operation', {
  skip:!enabled,
}, () => {
  assert.equal(typeof repository.replaySecurityAlert,'function');
});

test('a FAILED security alert is replayed once and its original immutable identity is preserved', {
  skip:!enabled || !hasReplay,
  timeout:30_000,
}, async () => {
  const admin = await createAdmin();
  const event = await createFailedEvent();
  try {
    const before = await pool.query('SELECT * FROM outbox_events WHERE id=$1',[event.id]);
    const result = await repository.replaySecurityAlert(replayArgs(admin,event));
    const afterRow = await pool.query('SELECT * FROM outbox_events WHERE id=$1',[event.id]);
    const row = afterRow.rows[0];
    assert.equal(result.replayed,true);
    assert.equal(result.alreadyReplayed,false);
    assert.equal(result.status,'PENDING');
    assert.equal(result.replayCount,1);
    for (const field of ['id','event_type','aggregate_type','aggregate_id','dedupe_key','payload','created_at']) {
      assert.deepEqual(row[field],before.rows[0][field],`immutable Outbox field ${field} must not change`);
    }
    assert.equal(row.status,'PENDING');
    assert.equal(Number(row.attempts),0);
    assert.equal(row.locked_at,null);
    assert.equal(row.lease_token,null);
    assert.equal(row.last_error,null);
    assert.equal(row.processed_at,null);
    assert.equal(Number(row.manual_replay_count),1);
    assert.equal(row.manual_replay_idempotency_key,'admin-replay:' + event.id);
    const audit = await pool.query(
      `SELECT action,actor_id,entity_type,entity_id,meta
         FROM audit_logs WHERE actor_id=$1 AND entity_id=$2
           AND action='ADMIN_SECURITY_ALERT_OUTBOX_REPLAY'`,
      [admin.id,event.id],
    );
    assert.equal(audit.rows.length,1);
    assert.equal(audit.rows[0].entity_type,'outbox_event');
    assert.equal(audit.rows[0].meta.reason,replayArgs(admin,event).reason);
    assert.equal(audit.rows[0].meta.priorAttempts,4);
    assert.equal(audit.rows[0].meta.replayCount,1);
  } finally {
    await cleanup(event.id,admin.id);
  }
});

test('same idempotency key returns the original replay while a different key conflicts', {
  skip:!enabled || !hasReplay,
  timeout:30_000,
}, async () => {
  const admin = await createAdmin();
  const event = await createFailedEvent();
  const key = 'retry-safe:' + event.id;
  try {
    const first = await repository.replaySecurityAlert(replayArgs(admin,event,key));
    const repeated = await repository.replaySecurityAlert(replayArgs(admin,event,key));
    assert.equal(first.alreadyReplayed,false);
    assert.equal(repeated.alreadyReplayed,true);
    assert.equal(repeated.replayed,true);
    assert.equal(repeated.status,'PENDING');
    await pool.query(
      "UPDATE outbox_events SET status='DONE',processed_at=NOW() WHERE id=$1",
      [event.id],
    );
    const afterDelivery = await repository.replaySecurityAlert(replayArgs(admin,event,key));
    assert.equal(afterDelivery.alreadyReplayed,true);
    assert.equal(afterDelivery.status,'DONE','same-key retries remain idempotent after the worker finishes delivery');
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event,key + ':different')),
      (error) => error?.code === 'OUTBOX_EVENT_ALREADY_REPLAYED',
    );
    const {rows} = await pool.query(
      `SELECT manual_replay_count,manual_replay_idempotency_key
         FROM outbox_events WHERE id=$1`,
      [event.id],
    );
    assert.equal(Number(rows[0].manual_replay_count),1);
    assert.equal(rows[0].manual_replay_idempotency_key,key);
    const audit = await pool.query(
      `SELECT id FROM audit_logs WHERE action='ADMIN_SECURITY_ALERT_OUTBOX_REPLAY'
        AND entity_id=$1`,
      [event.id],
    );
    assert.equal(audit.rows.length,1,'idempotent repeats must not insert a second audit event');
  } finally {
    await cleanup(event.id,admin.id);
  }
});

test('non-security and financial Outbox event types are never eligible for replay', {
  skip:!enabled || !hasReplay,
}, async () => {
  const admin = await createAdmin();
  const financial = await createFailedEvent({eventType:'PAYMENT_RELEASE',aggregateType:'payment'});
  try {
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,financial)),
      (error) => error?.code === 'OUTBOX_EVENT_NOT_REPLAYABLE',
    );
    const {rows} = await pool.query(
      'SELECT status,manual_replay_count FROM outbox_events WHERE id=$1',
      [financial.id],
    );
    assert.equal(rows[0].status,'FAILED');
    assert.equal(Number(rows[0].manual_replay_count),0);
  } finally {
    await cleanup(financial.id,admin.id);
  }
});

test('security alert replay requires the user aggregate and a non-null aggregate identity', {
  skip:!enabled || !hasReplay,
}, async () => {
  const admin = await createAdmin();
  const wrongAggregate = await createFailedEvent({aggregateType:'payment'});
  const nullAggregate = await createFailedEvent({aggregateId:null});
  try {
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,wrongAggregate)),
      (error) => error?.code === 'OUTBOX_EVENT_NOT_REPLAYABLE',
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,nullAggregate)),
      (error) => error?.code === 'OUTBOX_EVENT_NOT_REPLAYABLE',
    );
  } finally {
    await cleanup(wrongAggregate.id,admin.id);
    await cleanup(nullAggregate.id,null);
  }
});

test('only terminal FAILED events without an active lease can be initially replayed', {
  skip:!enabled || !hasReplay,
}, async () => {
  const admin = await createAdmin();
  const pending = await createFailedEvent({status:'PENDING'});
  const processing = await createFailedEvent({status:'PROCESSING',leaseToken:uuid(),lockedAt:new Date()});
  const done = await createFailedEvent({status:'DONE'});
  const leasedFailed = await createFailedEvent({status:'FAILED',leaseToken:uuid(),lockedAt:new Date()});
  try {
    for (const event of [pending,processing,done,leasedFailed]) {
      await assert.rejects(
        repository.replaySecurityAlert(replayArgs(admin,event)),
        (error) => error?.code === 'OUTBOX_EVENT_NOT_REPLAYABLE',
      );
    }
  } finally {
    for (const event of [pending,processing,done,leasedFailed]) await cleanup(event.id,null);
    await cleanup(null,admin.id);
  }
});

test('replay rejects missing, invalid, stale-session and non-primary actors under transaction lock', {
  skip:!enabled || !hasReplay,
}, async () => {
  const admin = await createAdmin();
  const opsAdmin = await createAdmin({email:'ops-' + uuid() + '@example.test'});
  const event = await createFailedEvent();
  try {
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(opsAdmin,event)),
      (error) => error?.code === 'PRIMARY_ADMIN_ONLY',
    );
    await pool.query('UPDATE users SET google_subject=NULL WHERE id=$1',[admin.id]);
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event)),
      (error) => error?.code === 'PRIMARY_ADMIN_IDENTITY_REQUIRED',
    );
    await pool.query(
      'UPDATE users SET google_subject=$2,admin_panel_verified_at=NOW()-INTERVAL \'10 minutes\',admin_panel_verified_scope=\'WRITE\' WHERE id=$1',
      [admin.id,admin.googleSubject],
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event)),
      (error) => error?.code === 'ADMIN_PANEL_LOCKED',
    );
    await pool.query(
      'UPDATE users SET admin_panel_verified_at=NOW(),admin_panel_verified_scope=\'READ\' WHERE id=$1',
      [admin.id],
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event)),
      (error) => error?.code === 'ADMIN_PANEL_LOCKED',
    );
    await pool.query(
      'UPDATE users SET admin_panel_verified_scope=\'WRITE\' WHERE id=$1',
      [admin.id],
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event,undefined,{sessionJti:'wrong-session'})),
      (error) => error?.code === 'ADMIN_PANEL_LOCKED',
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event,undefined,{reason:'  '})),
      (error) => error?.code === 'INVALID_REPLAY_REASON',
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event,'bad key')),
      (error) => error?.code === 'INVALID_IDEMPOTENCY_KEY',
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event,'k'.repeat(201))),
      (error) => error?.code === 'INVALID_IDEMPOTENCY_KEY',
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event,undefined,{reason:'r'.repeat(1001)})),
      (error) => error?.code === 'INVALID_REPLAY_REASON',
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event,undefined,{eventId:'not-a-uuid'})),
      (error) => error?.code === 'INVALID_EVENT_ID',
    );
    await pool.query("UPDATE users SET status='SUSPENDED' WHERE id=$1",[admin.id]);
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event)),
      (error) => error?.code === 'ADMIN_REQUIRED',
    );
    const {rows} = await pool.query('SELECT status,manual_replay_count FROM outbox_events WHERE id=$1',[event.id]);
    assert.equal(rows[0].status,'FAILED');
    assert.equal(Number(rows[0].manual_replay_count),0);
  } finally {
    await cleanup(event.id,admin.id);
    await cleanup(null,opsAdmin.id);
   }
});

test('concurrent distinct replay keys serialize to exactly one successful replay', {
  skip:!enabled || !hasReplay,
  timeout:30_000,
}, async () => {
  const admin = await createAdmin();
  const event = await createFailedEvent();
  try {
    const outcomes = await Promise.allSettled([
      repository.replaySecurityAlert(replayArgs(admin,event,'concurrent-key-a:' + event.id)),
      repository.replaySecurityAlert(replayArgs(admin,event,'concurrent-key-b:' + event.id)),
    ]);
    assert.equal(outcomes.filter((item) => item.status === 'fulfilled').length,1);
    assert.equal(outcomes.filter((item) => item.status === 'rejected').length,1);
    const rejected = outcomes.find((item) => item.status === 'rejected');
    assert.equal(rejected.reason?.code,'OUTBOX_EVENT_ALREADY_REPLAYED');
    const {rows} = await pool.query(
      `SELECT status,manual_replay_count FROM outbox_events WHERE id=$1`,
      [event.id],
    );
    assert.equal(rows[0].status,'PENDING');
    assert.equal(Number(rows[0].manual_replay_count),1);
  } finally {
    await cleanup(event.id,admin.id);
  }
});

test('audit failure rolls back the outbox requeue and the one-replay counter', {
  skip:!enabled || !hasReplay,
  timeout:30_000,
}, async () => {
  const admin = await createAdmin();
  const event = await createFailedEvent();
  const suffix = uuid().replaceAll('-','');
  const functionName = 'hope_replay_audit_reject_' + suffix;
  const triggerName = 'hope_replay_audit_reject_' + suffix;
  try {
    await pool.query(
      `CREATE FUNCTION ${functionName}() RETURNS trigger LANGUAGE plpgsql AS $body$
       BEGIN
         IF NEW.action='ADMIN_SECURITY_ALERT_OUTBOX_REPLAY' THEN
           RAISE EXCEPTION 'injected replay audit failure';
         END IF;
         RETURN NEW;
       END
       $body$`,
    );
    await pool.query(
      `CREATE TRIGGER ${triggerName} BEFORE INSERT ON audit_logs
       FOR EACH ROW EXECUTE FUNCTION ${functionName}()`,
    );
    await assert.rejects(
      repository.replaySecurityAlert(replayArgs(admin,event)),
      /injected replay audit failure/,
    );
    const {rows} = await pool.query(
      'SELECT status,manual_replay_count,manual_replay_idempotency_key FROM outbox_events WHERE id=$1',
      [event.id],
    );
    assert.equal(rows[0].status,'FAILED');
    assert.equal(Number(rows[0].manual_replay_count),0);
    assert.equal(rows[0].manual_replay_idempotency_key,null);
  } finally {
    await pool.query(`DROP TRIGGER IF EXISTS ${triggerName} ON audit_logs`).catch(() => {});
    await pool.query(`DROP FUNCTION IF EXISTS ${functionName}()`).catch(() => {});
    await cleanup(event.id,admin.id);
  }
});

test('a stale worker failure callback cannot overwrite a replay after a new lease is assigned', {
  skip:!enabled || !hasReplay,
  timeout:30_000,
}, async () => {
  const admin = await createAdmin();
  const event = await createFailedEvent();
  const staleLease = uuid();
  const newLease = uuid();
  try {
    await repository.replaySecurityAlert(replayArgs(admin,event));
    await pool.query(
      `UPDATE outbox_events SET status='PROCESSING',attempts=1,locked_at=NOW(),lease_token=$2
        WHERE id=$1 AND status='PENDING'`,
      [event.id,newLease],
    );
    const completed = await repository.completeOutboxEvent({
      eventId:event.id,
      leaseToken:staleLease,
    });
    assert.equal(completed.completed,false);
    assert.equal(completed.reason,'STALE_LEASE');
    const result = await repository.failOutboxEvent({
      eventId:event.id,
      error:'late callback from original delivery attempt',
      maxAttempts:1,
      leaseToken:staleLease,
    });
    assert.equal(result.stale,true);
    const {rows} = await pool.query(
      'SELECT status,lease_token,manual_replay_count FROM outbox_events WHERE id=$1',
      [event.id],
    );
    assert.equal(rows[0].status,'PROCESSING');
    assert.equal(rows[0].lease_token,newLease);
    assert.equal(Number(rows[0].manual_replay_count),1);
  } finally {
    await cleanup(event.id,admin.id);
  }
});

test('migration 053 enforces the one-replay counter and rejects malformed persisted request keys', {
  skip:!enabled,
  timeout:30_000,
}, async () => {
  const admin = await createAdmin();
  const event = await createFailedEvent();
  try {
    await assert.rejects(
      pool.query(
        'UPDATE outbox_events SET manual_replay_count=2,manual_replay_idempotency_key=$2 WHERE id=$1',
        [event.id,'too-many-replays'],
      ),
      /outbox_manual_replay_consistency_check/,
    );
    await assert.rejects(
      pool.query(
        'UPDATE outbox_events SET manual_replay_count=1,manual_replay_idempotency_key=$2 WHERE id=$1',
        [event.id,'key with whitespace'],
      ),
      /outbox_manual_replay_consistency_check/,
    );
    const {rows} = await pool.query(
      'SELECT status,manual_replay_count,manual_replay_idempotency_key FROM outbox_events WHERE id=$1',
      [event.id],
    );
    assert.equal(rows[0].status,'FAILED');
    assert.equal(Number(rows[0].manual_replay_count),0);
    assert.equal(rows[0].manual_replay_idempotency_key,null);
  } finally {
    await cleanup(event.id,admin.id);
  }
});

test('terminal refresh-reuse delivery failure persists FAILED and emits its structured JSON error event', {
  skip:!enabled || !hasReplay || typeof outboxHandlers?.processOutboxEvent !== 'function',
  timeout:30_000,
}, async () => {
  const leaseToken=uuid();
  const event=await createFailedEvent({
    status:'PROCESSING',
    attempts:8,
    leaseToken,
    lockedAt:new Date(),
  });
  const config=configModule.config;
  const originalConfig={
    alertWebhookUrl:config.alertWebhookUrl,
    alertWebhookToken:config.alertWebhookToken,
    outboxMaxAttempts:config.outboxMaxAttempts,
  };
  const originalWrite=process.stdout.write;
  const captured=[];
  try {
    await pool.query(
      'UPDATE outbox_events SET payload=$2::jsonb WHERE id=$1',
      [event.id,JSON.stringify({
        ...event.payload,
        alertCode:'AUTH_REFRESH_REUSE_DETECTED',
        tokenFamilyId:uuid(),
      })],
    );
    config.alertWebhookUrl='';
    config.alertWebhookToken='';
    config.outboxMaxAttempts=8;

    process.stdout.write=(chunk,encoding,callback)=>{
      captured.push(Buffer.isBuffer(chunk)?chunk.toString():String(chunk));
      const done=typeof encoding==='function'?encoding:callback;
      if(typeof done==='function') done();
      return true;
    };

    const {rows:beforeRows}=await pool.query(
      'SELECT * FROM outbox_events WHERE id=$1',
      [event.id],
    );
    const result=await outboxHandlers.processOutboxEvent(beforeRows[0]);
    assert.equal(result.terminal,true);
    assert.equal(result.attempts,8);

    const {rows:afterRows}=await pool.query(
      'SELECT status,attempts,locked_at,lease_token FROM outbox_events WHERE id=$1',
      [event.id],
    );
    assert.equal(afterRows[0].status,'FAILED');
    assert.equal(Number(afterRows[0].attempts),8);
    assert.equal(afterRows[0].locked_at,null);
    assert.equal(afterRows[0].lease_token,null);

    const records=captured.join('').split('\n').filter(Boolean).map((line)=>JSON.parse(line));
    const terminal=records.find((record)=>record.action==='OUTBOX_SECURITY_ALERT_TERMINAL_FAILURE');
    assert.ok(terminal,'terminal Outbox delivery must produce the structured error event');
    assert.equal(terminal.level,'error');
    assert.equal(terminal.eventId,event.id);
    assert.equal(terminal.eventType,'AUTH_REFRESH_REUSE_ALERT');
    assert.equal(terminal.attempts,8);
    assert.equal(terminal.runbook,'docs/runbooks/auth-refresh-token-reuse.md');
    assert.equal(Object.hasOwn(terminal,'tokenFamilyId'),false);
    assert.equal(Object.hasOwn(terminal,'email'),false);
  } finally {
    process.stdout.write=originalWrite;
    Object.assign(config,originalConfig);
    await cleanup(event.id,null);
  }
});

after(async () => {
  if (enabled) await dbModule.db.close();
});
