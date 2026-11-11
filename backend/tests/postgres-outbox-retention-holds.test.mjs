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
      import('../src/repository.js'),
    ])
  : [];
const dbModule = modules[0];
const repository = modules[1];
// The new repository methods are intentionally unresolved on the RED baseline.
// Reuse the facade for helper-boundary checks so the test reaches assertion failures.
const retention = repository;
if (enabled) await dbModule.initDatabase();
const pool = enabled ? dbModule.getPool() : null;
const uuid = () => crypto.randomUUID();
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let primaryAdminId = null;

async function createAdmin() {
  const email = 'amir.davodpour@gmail.com';
  const sessionJti = uuid();
  if (!primaryAdminId) {
    const existing = await pool.query(
      'SELECT id FROM users WHERE LOWER(email)=LOWER($1) LIMIT 1',
      [email],
    );
    primaryAdminId = existing.rows[0]?.id || uuid();
  }
  await pool.query(
    `INSERT INTO users(
       id,email,google_subject,password_hash,display_name,role,status,session_version,
       admin_panel_verified_at,admin_panel_verified_session_jti,admin_panel_verified_scope,created_at
     ) VALUES($1,$2,$3,'integration-only-hash','Outbox retention primary admin','ADMIN','ACTIVE',0,NOW(),$4,'WRITE',NOW())
     ON CONFLICT(id) DO UPDATE SET
       google_subject=EXCLUDED.google_subject,
       role='ADMIN',
       status='ACTIVE',
       admin_panel_verified_at=NOW(),
       admin_panel_verified_session_jti=EXCLUDED.admin_panel_verified_session_jti,
       admin_panel_verified_scope='WRITE'`,
    [primaryAdminId,email,`outbox-retention-primary-${uuid()}`,sessionJti],
  );
  return { actorId:primaryAdminId, sessionJti };
}

async function createOperationalAdmin() {
  const id = uuid();
  const sessionJti = uuid();
  await pool.query(
    `INSERT INTO users(
       id,email,password_hash,display_name,role,status,session_version,
       admin_panel_verified_at,admin_panel_verified_session_jti,admin_panel_verified_scope,created_at
     ) VALUES($1,$2,'integration-only-hash','Outbox retention operator','ADMIN','ACTIVE',0,NOW(),$3,'WRITE',NOW())`,
    [id, `outbox-retention-ops-${id}@example.test`, sessionJti],
  );
  return { actorId:id, sessionJti };
}

async function createOutboxEvent({
  eventType = 'NOTIFICATION_DISPATCH',
  aggregateType = 'notification',
  aggregateId = uuid(),
  status = 'DONE',
  createdAt = new Date(),
  payload = { privateMarker:'DO_NOT_RETURN_PRIVATE_OUTBOX_PAYLOAD', email:'private-outbox@example.test' },
} = {}) {
  const id = uuid();
  const { rows } = await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,payload,status,attempts,available_at,created_at
     ) VALUES($1,$2,$3,$4,$5::jsonb,$6,0,NOW(),$7)
     RETURNING id,created_at,terminal_at,status`,
    [id,eventType,aggregateType,aggregateId,JSON.stringify(payload),status,createdAt],
  );
  return { id, aggregateId, createdAt:rows[0].created_at, terminalAt:rows[0].terminal_at, status:rows[0].status };
}

const implemented = enabled && typeof repository.createOutboxRetentionHold === 'function'
  && typeof repository.releaseOutboxRetentionHold === 'function'
  && typeof repository.buildOutboxRetentionDryRun === 'function'
  && typeof retention.createOutboxRetentionHoldWithClient === 'function'
  && typeof retention.checkOutboxRetentionTargetHoldsWithClient === 'function';

test('migration 058 creates separate append-only Outbox hold and release ledgers', { skip:!enabled }, async () => {
  const { rows } = await pool.query(
    `SELECT to_regclass('public.outbox_retention_holds') AS holds,
            to_regclass('public.outbox_retention_hold_releases') AS releases`,
  );
  assert.ok(rows[0]?.holds, 'outbox_retention_holds table must exist');
  assert.ok(rows[0]?.releases, 'outbox_retention_hold_releases table must exist');
});

test('repository exposes Outbox hold and dry-run operations', { skip:!enabled }, async () => {
  assert.equal(typeof repository.createOutboxRetentionHold, 'function');
  assert.equal(typeof repository.releaseOutboxRetentionHold, 'function');
  assert.equal(typeof repository.buildOutboxRetentionDryRun, 'function');
  assert.equal(typeof retention.createOutboxRetentionHoldWithClient, 'function');
  assert.equal(typeof retention.checkOutboxRetentionTargetHoldsWithClient, 'function');
});

test('only the verified primary administrator can create or release Outbox retention holds',{skip:!implemented},async()=>{
  const primary=await createAdmin();
  const operational=await createOperationalAdmin();
  const event=await createOutboxEvent();
  const hold=await repository.createOutboxRetentionHold({
    ...primary,
    target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',
    reasonCode:'LEGAL_REQUEST',
  });
  assert.ok(hold.id);

  await assert.rejects(
    repository.createOutboxRetentionHold({
      ...operational,
      target:{kind:'EVENT',eventId:event.id},
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    }),
    (error)=>error?.code==='PRIMARY_ADMIN_ONLY',
  );
  await assert.rejects(
    repository.releaseOutboxRetentionHold({
      ...operational,
      holdId:hold.id,
      reasonCode:'CASE_CLOSED',
    }),
    (error)=>error?.code==='PRIMARY_ADMIN_ONLY',
  );

  const rows=await pool.query(
    'SELECT COUNT(*)::int AS count FROM outbox_retention_holds WHERE event_id=$1',
    [event.id],
  );
  assert.equal(rows.rows[0].count,1);
});

test('event and aggregate holds are audited, releasable and immutable', { skip:!implemented }, async () => {
  const admin = await createAdmin();
  const event = await createOutboxEvent();
  const eventHold = await repository.createOutboxRetentionHold({
    ...admin,
    target:{ kind:'EVENT', eventId:event.id },
    holdKind:'LEGAL',
    reasonCode:'LEGAL_REQUEST',
  });
  assert.ok(eventHold.id);

  const aggregateHold = await repository.createOutboxRetentionHold({
    ...admin,
    target:{ kind:'AGGREGATE', aggregateType:'notification', aggregateId:event.aggregateId },
    holdKind:'ADMIN',
    reasonCode:'ADMIN_REVIEW',
  });
  assert.ok(aggregateHold.id);

  const released = await repository.releaseOutboxRetentionHold({
    ...admin,
    holdId:eventHold.id,
    reasonCode:'CASE_CLOSED',
  });
  assert.equal(released.released,true);

  const created = await pool.query(
    'SELECT target_kind,event_id,aggregate_type,aggregate_id,hold_kind,created_by,reason_code FROM outbox_retention_holds WHERE id=$1',
    [aggregateHold.id],
  );
  assert.equal(created.rowCount,1);
  assert.equal(created.rows[0].target_kind,'AGGREGATE');
  assert.equal(created.rows[0].hold_kind,'ADMIN');
  assert.equal(created.rows[0].created_by,admin.actorId);
  assert.equal(created.rows[0].reason_code,'ADMIN_REVIEW');

  const releasedAudit = await pool.query(
    'SELECT hold_id,released_by,reason_code FROM outbox_retention_hold_releases WHERE hold_id=$1',
    [eventHold.id],
  );
  assert.equal(releasedAudit.rowCount,1);
  assert.equal(releasedAudit.rows[0].released_by,admin.actorId);
  assert.equal(releasedAudit.rows[0].reason_code,'CASE_CLOSED');

  await assert.rejects(
    pool.query('UPDATE outbox_retention_holds SET reason_code=$2 WHERE id=$1',[aggregateHold.id,'OTHER']),
  );
  await assert.rejects(
    pool.query('DELETE FROM outbox_retention_holds WHERE id=$1',[aggregateHold.id]),
  );
  await assert.rejects(
    pool.query('UPDATE outbox_retention_hold_releases SET reason_code=$2 WHERE hold_id=$1',[eventHold.id,'OTHER']),
  );
  await assert.rejects(
    pool.query('DELETE FROM outbox_retention_hold_releases WHERE hold_id=$1',[eventHold.id]),
  );
});

test('hold creation serializes with the future purge candidate gate and an active hold blocks it', { skip:!implemented }, async () => {
  const admin = await createAdmin();
  const event = await createOutboxEvent();
  const holdClient = await pool.connect();
  const candidateClient = await pool.connect();
  let candidateSettled = false;
  let candidatePromise;
  try {
    await holdClient.query('BEGIN');
    const hold = await retention.createOutboxRetentionHoldWithClient(holdClient,{
      ...admin,
      target:{ kind:'EVENT', eventId:event.id },
      holdKind:'LEGAL',
      reasonCode:'COURT_ORDER',
    });
    assert.ok(hold.id);

    await candidateClient.query('BEGIN');
    candidatePromise = retention.checkOutboxRetentionTargetHoldsWithClient(candidateClient,{
      kind:'EVENT',
      eventId:event.id,
    }).then((result)=>{ candidateSettled=true; return result; });
    await sleep(100);
    assert.equal(candidateSettled,false,'candidate gate must wait for the concurrent hold transaction');
    await holdClient.query('COMMIT');
    const result = await candidatePromise;
    assert.equal(result.blocked,true);
    assert.ok(result.activeHoldCount >= 1);
    await candidateClient.query('COMMIT');
  } finally {
    await holdClient.query('ROLLBACK').catch(()=>{});
    await candidateClient.query('ROLLBACK').catch(()=>{});
    holdClient.release();
    candidateClient.release();
  }
});

test('candidate gate rejects repeatable-read snapshots that could hide a newly committed hold',{skip:!implemented},async()=>{
  const event=await createOutboxEvent();
  const candidateClient=await pool.connect();
  try {
    await candidateClient.query('BEGIN ISOLATION LEVEL REPEATABLE READ');
    await assert.rejects(
      retention.checkOutboxRetentionTargetHoldsWithClient(candidateClient,{
        kind:'EVENT',
        eventId:event.id,
      }),
      (error)=>error?.code==='OUTBOX_RETENTION_GATE_REQUIRES_READ_COMMITTED',
    );
  } finally {
    await candidateClient.query('ROLLBACK').catch(()=>{});
    candidateClient.release();
  }
});

test('a hold never requeues a CANCELLED notification event', { skip:!implemented }, async () => {
  const admin = await createAdmin();
  const event = await createOutboxEvent({ status:'CANCELLED' });
  const before = await pool.query(
    'SELECT status,terminal_at,lease_token,processed_at FROM outbox_events WHERE id=$1',
    [event.id],
  );
  const hold = await repository.createOutboxRetentionHold({
    ...admin,
    target:{ kind:'EVENT', eventId:event.id },
    holdKind:'ADMIN',
    reasonCode:'ADMIN_REVIEW',
  });
  assert.ok(hold.id);
  const afterRow = await pool.query(
    'SELECT status,terminal_at,lease_token,processed_at FROM outbox_events WHERE id=$1',
    [event.id],
  );
  assert.deepEqual(afterRow.rows[0],before.rows[0]);
  assert.equal(afterRow.rows[0].status,'CANCELLED');
});

test('dry-run is keyset-paged, repeatable-read, read-only, sanitized and never marks records purgeable', { skip:!implemented }, async () => {
  const admin = await createAdmin();
  const aggregateId = uuid();
  const eventHold = await createOutboxEvent({
    eventType:'NOTIFICATION_DISPATCH',
    aggregateType:'notification',
    aggregateId,
    status:'FAILED',
    payload:{ body:'SECRET_NOTIFICATION_BODY_MARKER', email:'secret-owner@example.test', token:'device-secret-marker' },
  });
  await repository.createOutboxRetentionHold({
    ...admin,
    target:{ kind:'AGGREGATE', aggregateType:'notification', aggregateId },
    holdKind:'LEGAL',
    reasonCode:'DISPUTE',
  });
  await createOutboxEvent({
    eventType:'PAYMENT_RELEASE',
    aggregateType:'payment',
    status:'DONE',
  });
  await createOutboxEvent({
    eventType:'AUTH_REFRESH_REUSE_ALERT',
    aggregateType:'user',
    status:'FAILED',
  });

  const before = await pool.query(
    'SELECT id,status,terminal_at,processed_at FROM outbox_events ORDER BY id',
  );
  const result = await repository.buildOutboxRetentionDryRun({
    ...admin,
    pageSize:1,
    maxRows:2,
  });
  const afterRows = await pool.query(
    'SELECT id,status,terminal_at,processed_at FROM outbox_events ORDER BY id',
  );

  assert.equal(result.wouldMutate,false);
  assert.equal(result.mutationCount,0);
  assert.equal(result.providerCalls,0);
  assert.equal(result.retentionPolicyConfigured,false);
  assert.ok(result.pagesRead >= 2);
  assert.equal(result.items.length,2);
  assert.equal(result.truncated,true);
  assert.deepEqual(afterRows.rows,before.rows);

  const encoded = JSON.stringify(result);
  assert.equal(encoded.includes('SECRET_NOTIFICATION_BODY_MARKER'),false);
  assert.equal(encoded.includes('secret-owner@example.test'),false);
  assert.equal(encoded.includes('device-secret-marker'),false);
  assert.equal(encoded.includes(eventHold.id),false);
  assert.ok(result.items.every((item)=>item.eligible === false));
  assert.ok(result.items.every((item)=>item.blockers.includes('RETENTION_PERIOD_NOT_APPROVED')));
});

test('dry-run classifies financial events as protected and reports active holds without exposing identities', { skip:!implemented }, async () => {
  const admin = await createAdmin();
  const aggregateId = uuid();
  await createOutboxEvent({eventType:'PAYMENT_REFUND',aggregateType:'payment',aggregateId,status:'DONE'});
  const event = await createOutboxEvent({eventType:'NOTIFICATION_DISPATCH',aggregateType:'notification',status:'CANCELLED'});
  await repository.createOutboxRetentionHold({
    ...admin,
    target:{kind:'EVENT',eventId:event.id},
    holdKind:'ADMIN',
    reasonCode:'ADMIN_REVIEW',
  });
  const result = await repository.buildOutboxRetentionDryRun({...admin,pageSize:100,maxRows:100});
  const financial = result.items.find((item)=>item.eventType==='PAYMENT_REFUND' && item.aggregateType==='payment');
  assert.ok(financial);
  assert.ok(financial.blockers.includes('FINANCIAL_RECORDS_EXCLUDED'));
  const held = result.items.find((item)=>item.status==='CANCELLED' && item.aggregateType==='notification');
  assert.ok(held);
  assert.ok(held.blockers.includes('ACTIVE_HOLD'));
  assert.equal(JSON.stringify(result).includes(event.id),false);
  assert.equal(JSON.stringify(result).includes(aggregateId),false);
});

test('dry-run rejects stale or non-admin actor contexts', { skip:!implemented }, async () => {
  const admin = await createAdmin();
  await assert.rejects(
    repository.buildOutboxRetentionDryRun({actorId:uuid(),sessionJti:uuid()}),
    (error)=>error?.code==='ADMIN_REQUIRED' || error?.code==='ADMIN_ACTOR_REQUIRED',
  );
  await assert.rejects(
    repository.buildOutboxRetentionDryRun({actorId:admin.actorId,sessionJti:uuid()}),
    (error)=>error?.code==='ADMIN_PANEL_LOCKED',
  );
});

after(async()=>{
  if (enabled) await dbModule.db.close();
});
