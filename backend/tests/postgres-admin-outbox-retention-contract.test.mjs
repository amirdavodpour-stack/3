import test, { after } from 'node:test';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

process.env.NODE_ENV='test';

const enabled=Boolean(process.env.DATABASE_URL);
if (process.env.REQUIRE_INTEGRATION==='1' && !enabled) {
  throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
}

const modules=enabled
  ? await Promise.all([
      import('../src/db.js'),
      import('../src/repository.js'),
    ])
  : [];
const dbModule=modules[0];
const repository=modules[1];
if (enabled) await dbModule.initDatabase();
const pool=enabled ? dbModule.getPool() : null;

const uuid=()=>crypto.randomUUID();
let primaryAdminId=null;

async function createPrimaryAdmin() {
  const email='amir.davodpour@gmail.com';
  const sessionJti=uuid();
  if (!primaryAdminId) {
    const existing=await pool.query(
      'SELECT id FROM users WHERE LOWER(email)=LOWER($1) LIMIT 1',
      [email],
    );
    primaryAdminId=existing.rows[0]?.id || uuid();
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
    [primaryAdminId,email,'outbox-retention-contract-'+uuid(),sessionJti],
  );

  return {actorId:primaryAdminId,sessionJti};
}

async function createOutboxEvent({
  eventType='NOTIFICATION_DISPATCH',
  aggregateType='notification',
  aggregateId=uuid(),
  status='DONE',
  createdAt=null,
}={}) {
  const id=uuid();
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,payload,status,attempts,available_at,created_at
     ) VALUES($1,$2,$3,$4,'{}'::jsonb,$5,0,NOW(),COALESCE($6::timestamptz,NOW()))`,
    [id,eventType,aggregateType,aggregateId,status,createdAt],
  );
  return {id,aggregateId};
}

async function holdCountForEvent(eventId) {
  const {rows}=await pool.query(
    'SELECT COUNT(*)::int AS count FROM outbox_retention_holds WHERE event_id=$1',
    [eventId],
  );
  return rows[0].count;
}

async function createHold(input) {
  return repository.createOutboxRetentionHold({
    ...input,
    idempotencyKey:input.idempotencyKey || `test-${uuid()}`,
  });
}

function idempotencyKeyDigest(key) {
  return crypto.createHash('sha256')
    .update('hopev2:admin-outbox-retention-hold:create:v1\0','utf8')
    .update(key,'utf8')
    .digest();
}

async function countIdempotencyRows(actorId,key) {
  const {rows}=await pool.query(
    'SELECT COUNT(*)::int AS count FROM admin_outbox_retention_hold_idempotency WHERE actor_id=$1 AND key_digest=$2',
    [actorId,idempotencyKeyDigest(key)],
  );
  return rows[0].count;
}

async function countHoldAuditRows(holdId) {
  const {rows}=await pool.query(
    `SELECT COUNT(*)::int AS count FROM audit_logs WHERE action='ADMIN_OUTBOX_RETENTION_HOLD_CREATED' AND entity_id=$1`,
    [holdId],
  );
  return rows[0].count;
}

async function installAuditFailureTrigger(action) {
  await pool.query('DROP TRIGGER IF EXISTS hope_test_outbox_retention_audit_failure ON audit_logs');
  await pool.query('DROP FUNCTION IF EXISTS hope_test_outbox_retention_audit_failure()');
  await pool.query(`
    CREATE FUNCTION hope_test_outbox_retention_audit_failure()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $body$
    BEGIN
      IF NEW.action = TG_ARGV[0] THEN
        RAISE EXCEPTION 'OUTBOX_RETENTION_AUDIT_INJECTED_FAILURE';
      END IF;
      RETURN NEW;
    END;
    $body$;
  `);
  const allowedActions = new Set([
    'ADMIN_OUTBOX_RETENTION_HOLD_CREATED',
    'ADMIN_OUTBOX_RETENTION_HOLD_RELEASED',
  ]);
  assert.ok(allowedActions.has(action), 'audit failure trigger action must be an allowlisted test literal');
  await pool.query(
    `CREATE TRIGGER hope_test_outbox_retention_audit_failure
       BEFORE INSERT ON audit_logs
       FOR EACH ROW
       EXECUTE FUNCTION hope_test_outbox_retention_audit_failure('${action}')`,
  );
}

async function removeAuditFailureTrigger() {
  await pool.query('DROP TRIGGER IF EXISTS hope_test_outbox_retention_audit_failure ON audit_logs');
  await pool.query('DROP FUNCTION IF EXISTS hope_test_outbox_retention_audit_failure()');
}

test('financial EVENT holds are rejected before an immutable hold row is inserted',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent({
    eventType:'PAYMENT_REFUND',
    aggregateType:'payment',
  });

  await assert.rejects(
    createHold({
      ...admin,
      target:{kind:'EVENT',eventId:event.id},
      holdKind:'LEGAL',
      reasonCode:'LEGAL_REQUEST',
    }),
    (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
  );
  assert.equal(await holdCountForEvent(event.id),0);
});

test('financial AGGREGATE holds are rejected for payment and payout targets',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const payment=await createOutboxEvent({eventType:'PAYMENT_REFUND',aggregateType:'payment'});
  const payout=await createOutboxEvent({eventType:'PAYOUT_EXECUTE',aggregateType:'payout'});

  await assert.rejects(
    createHold({
      ...admin,
      target:{kind:'AGGREGATE',aggregateType:'payment',aggregateId:payment.aggregateId},
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    }),
    (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
  );
  await assert.rejects(
    createHold({
      ...admin,
      target:{kind:'AGGREGATE',aggregateType:'payout',aggregateId:payout.aggregateId},
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    }),
    (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
  );
});

test('generic dry-run omits financial payment and payout rows rather than returning them as candidates',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  await createOutboxEvent({eventType:'PAYMENT_REFUND',aggregateType:'payment'});
  await createOutboxEvent({eventType:'PAYOUT_EXECUTE',aggregateType:'payout'});

  const result=await repository.buildOutboxRetentionDryRun({
    ...admin,
    pageSize:100,
    maxRows:1000,
  });

  assert.equal(
    result.items.some((item)=>item.eventType==='PAYMENT_REFUND' && item.aggregateType==='payment'),
    false,
    'payment/refund records must not enter generic Outbox retention inventory',
  );
  assert.equal(
    result.items.some((item)=>item.eventType==='PAYOUT_EXECUTE' && item.aggregateType==='payout'),
    false,
    'payout records must not enter generic Outbox retention inventory',
  );
});

test('hold creation is represented in the common Admin audit feed',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const hold=await createHold({
    ...admin,
    target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',
    reasonCode:'LEGAL_REQUEST',
  });

  const {rows}=await pool.query(
    `SELECT action,actor_id,entity_type,entity_id,meta
       FROM audit_logs
      WHERE action='ADMIN_OUTBOX_RETENTION_HOLD_CREATED' AND entity_id=$1`,
    [hold.id],
  );
  assert.equal(rows.length,1);
  assert.equal(rows[0].actor_id,admin.actorId);
  assert.equal(rows[0].entity_type,'outbox_retention_hold');
  assert.equal(rows[0].meta.reasonCode,'LEGAL_REQUEST');
});

test('hold release is represented in the common Admin audit feed',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const hold=await createHold({
    ...admin,
    target:{kind:'EVENT',eventId:event.id},
    holdKind:'ADMIN',
    reasonCode:'ADMIN_REVIEW',
  });

  await repository.releaseOutboxRetentionHold({
    ...admin,
    holdId:hold.id,
    reasonCode:'CASE_CLOSED',
  });

  const {rows}=await pool.query(
    `SELECT action,actor_id,entity_type,entity_id,meta
       FROM audit_logs
      WHERE action='ADMIN_OUTBOX_RETENTION_HOLD_RELEASED' AND entity_id=$1`,
    [hold.id],
  );
  assert.equal(rows.length,1);
  assert.equal(rows[0].actor_id,admin.actorId);
  assert.equal(rows[0].entity_type,'outbox_retention_hold');
  assert.equal(rows[0].meta.reasonCode,'CASE_CLOSED');
});

test('audit failure rolls back hold creation in the same transaction',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();

  const idempotencyKey=`audit-retry-${uuid()}`;
  try {
    await installAuditFailureTrigger('ADMIN_OUTBOX_RETENTION_HOLD_CREATED');
    await assert.rejects(
      createHold({
        ...admin,
        target:{kind:'EVENT',eventId:event.id},
        holdKind:'LEGAL',
        reasonCode:'LEGAL_REQUEST',
        idempotencyKey,
      }),
      (error)=>String(error.message).includes('OUTBOX_RETENTION_AUDIT_INJECTED_FAILURE'),
    );
    assert.equal(await holdCountForEvent(event.id),0);
    assert.equal(await countIdempotencyRows(admin.actorId,idempotencyKey),0);
  } finally {
    await removeAuditFailureTrigger();
  }
  const retry=await createHold({
    ...admin,
    target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',
    reasonCode:'LEGAL_REQUEST',
    idempotencyKey,
  });
  assert.equal(retry.replayed,false);
  assert.equal(await holdCountForEvent(event.id),1);
  assert.equal(await countIdempotencyRows(admin.actorId,idempotencyKey),1);

});

test('audit failure rolls back hold release in the same transaction',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const hold=await createHold({
    ...admin,
    target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',
    reasonCode:'LEGAL_REQUEST',
  });

  try {
    await installAuditFailureTrigger('ADMIN_OUTBOX_RETENTION_HOLD_RELEASED');
    await assert.rejects(
      repository.releaseOutboxRetentionHold({
        ...admin,
        holdId:hold.id,
        reasonCode:'CASE_CLOSED',
      }),
      (error)=>String(error.message).includes('OUTBOX_RETENTION_AUDIT_INJECTED_FAILURE'),
    );
    const {rows}=await pool.query(
      'SELECT COUNT(*)::int AS count FROM outbox_retention_hold_releases WHERE hold_id=$1',
      [hold.id],
    );
    assert.equal(rows[0].count,0);
  } finally {
    await removeAuditFailureTrigger();
  }
});


test('ledger, journal, refund, reconciliation, wallet, and transfer event classes are excluded from generic retention',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const eventTypes=[
    'LEDGER_POST',
    'JOURNAL_APPEND',
    'REFUND_EXECUTE',
    'RECONCILIATION_APPLY',
    'WALLET_TRANSFER',
    'TRANSFER_EXECUTE',
    'TOPUP_CAPTURE',
    'WITHDRAWAL_REQUEST',
  ];
  const created=[];
  for (const eventType of eventTypes) {
    const event=await createOutboxEvent({eventType,aggregateType:'notification'});
    created.push({eventType,aggregateType:'notification'});
    await assert.rejects(
      createHold({
        ...admin,
        target:{kind:'EVENT',eventId:event.id},
        holdKind:'ADMIN',
        reasonCode:'ADMIN_REVIEW',
      }),
      (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
    );
  }

  const result=await repository.buildOutboxRetentionDryRun({
    ...admin,
    pageSize:100,
    maxRows:1000,
  });
  for (const event of created) {
    assert.equal(
      result.items.some((item)=>item.eventType===event.eventType && item.aggregateType===event.aggregateType),
      false,
      `${event.eventType} must not enter generic Outbox retention inventory`,
    );
  }
});

test('ledger, journal, refund, reconciliation, wallet, and transfer aggregates are rejected explicitly',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const aggregateTypes=['ledger','journal','refund','reconciliation','wallet','transfer','topup','withdrawal'];
  for (const aggregateType of aggregateTypes) {
    const event=await createOutboxEvent({
      eventType:'OPERATIONAL_EVENT',
      aggregateType,
    });
    await assert.rejects(
      createHold({
        ...admin,
        target:{kind:'AGGREGATE',aggregateType,aggregateId:event.aggregateId},
        holdKind:'ADMIN',
        reasonCode:'ADMIN_REVIEW',
      }),
      (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
    );
  }
});


test('financial class matching trims stored event and aggregate values before any generic inventory exposure',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const paddedFinancialEvent=await createOutboxEvent({
    eventType:' PAYMENT_REFUND ',
    aggregateType:'notification',
  });
  const paddedFinancialAggregate=await createOutboxEvent({
    eventType:'OPERATIONAL_EVENT',
    aggregateType:' ledger ',
  });

  await assert.rejects(
    createHold({
      ...admin,
      target:{kind:'EVENT',eventId:paddedFinancialEvent.id},
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    }),
    (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
  );
  await assert.rejects(
    createHold({
      ...admin,
      target:{kind:'EVENT',eventId:paddedFinancialAggregate.id},
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    }),
    (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
  );
  await assert.rejects(
    createHold({
      ...admin,
      target:{
        kind:'AGGREGATE',
        aggregateType:' ledger ',
        aggregateId:paddedFinancialAggregate.aggregateId,
      },
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    }),
    (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
  );

  const result=await repository.buildOutboxRetentionDryRun({
    ...admin,
    pageSize:100,
    maxRows:1000,
  });
  assert.equal(
    result.items.some((item)=>item.eventType===' PAYMENT_REFUND '),
    false,
    'whitespace-wrapped financial event names must not enter generic retention inventory',
  );
  assert.equal(
    result.items.some((item)=>item.aggregateType===' ledger '),
    false,
    'whitespace-wrapped financial aggregate names must not enter generic retention inventory',
  );
});

after(async()=>{
  if (enabled) await dbModule.db.close();
});


test('same actor/key and canonical payload replay the same immutable hold without duplicate audit', {skip:!enabled}, async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const idempotencyKey=`same-intent-${uuid()}`;
  const input={
    ...admin,
    target:{kind:'EVENT',eventId:event.id.toUpperCase()},
    holdKind:'LEGAL',
    reasonCode:'LEGAL_REQUEST',
    idempotencyKey,
  };
  const first=await createHold(input);
  const replay=await createHold({
    ...input,
    target:{kind:'EVENT',eventId:event.id.toLowerCase()},
  });
  assert.equal(first.id,replay.id);
  assert.equal(first.replayed,false);
  assert.equal(replay.replayed,true);
  assert.equal(replay.createdAt,first.createdAt);
  assert.equal(await holdCountForEvent(event.id),1);
  assert.equal(await countIdempotencyRows(admin.actorId,idempotencyKey),1);
  assert.equal(await countHoldAuditRows(first.id),1);
});

test('same actor/key with a different payload returns 409 and creates no second hold', {skip:!enabled}, async()=>{
  const admin=await createPrimaryAdmin();
  const firstEvent=await createOutboxEvent();
  const secondEvent=await createOutboxEvent();
  const idempotencyKey=`payload-conflict-${uuid()}`;
  const first=await createHold({
    ...admin,target:{kind:'EVENT',eventId:firstEvent.id},
    holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',idempotencyKey,
  });
  await assert.rejects(
    createHold({
      ...admin,target:{kind:'EVENT',eventId:secondEvent.id},
      holdKind:'ADMIN',reasonCode:'ADMIN_REVIEW',idempotencyKey,
    }),
    error=>error?.status===409 && error?.code==='IDEMPOTENCY_KEY_REUSED',
  );
  assert.equal(await holdCountForEvent(firstEvent.id),1);
  assert.equal(await holdCountForEvent(secondEvent.id),0);
  assert.equal(await countHoldAuditRows(first.id),1);
});

test('concurrent same-key requests converge to one hold and one creation audit', {skip:!enabled}, async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const input={
    ...admin,target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',
    idempotencyKey:`concurrent-${uuid()}`,
  };
  const results=await Promise.all([createHold(input),createHold(input)]);
  assert.equal(results[0].id,results[1].id);
  assert.deepEqual(results.map(result=>result.replayed).sort(),[false,true]);
  assert.equal(await holdCountForEvent(event.id),1);
  assert.equal(await countIdempotencyRows(admin.actorId,input.idempotencyKey),1);
  assert.equal(await countHoldAuditRows(results[0].id),1);
});

test('retry after release replays original creation and never revives the hold', {skip:!enabled}, async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const idempotencyKey=`released-replay-${uuid()}`;
  const input={
    ...admin,target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',idempotencyKey,
  };
  const first=await createHold(input);
  await repository.releaseOutboxRetentionHold({
    ...admin,holdId:first.id,reasonCode:'CASE_CLOSED',
  });
  const replay=await createHold(input);
  assert.equal(replay.id,first.id);
  assert.equal(replay.replayed,true);
  const {rows}=await pool.query(
    'SELECT COUNT(*)::int AS count FROM outbox_retention_hold_releases WHERE hold_id=$1',
    [first.id],
  );
  assert.equal(rows[0].count,1);
  assert.equal(await holdCountForEvent(event.id),1);
  assert.equal(await countHoldAuditRows(first.id),1);
});

test('idempotency key namespace is actor-scoped at the persistence boundary', {skip:!enabled}, async()=>{
  const admin=await createPrimaryAdmin();
  const eventOne=await createOutboxEvent();
  const eventTwo=await createOutboxEvent();
  const idempotencyKey=`actor-scope-${uuid()}`;
  const first=await createHold({
    ...admin,target:{kind:'EVENT',eventId:eventOne.id},
    holdKind:'ADMIN',reasonCode:'ADMIN_REVIEW',idempotencyKey,
  });
  const actorTwo=uuid();
  const holdTwo=uuid();
  await pool.query(
    `INSERT INTO outbox_retention_holds(
       id,target_kind,event_id,aggregate_type,aggregate_id,hold_kind,reason_code,created_by,created_at
     ) VALUES($1,'EVENT',$2,'notification',$3,'ADMIN','ADMIN_REVIEW',$4,NOW())`,
    [holdTwo,eventTwo.id,eventTwo.aggregateId,actorTwo],
  );
  await pool.query(
    `INSERT INTO admin_outbox_retention_hold_idempotency(
       actor_id,key_digest,request_digest,hold_id,created_at
     ) VALUES($1,$2,$3,$4,NOW())`,
    [actorTwo,idempotencyKeyDigest(idempotencyKey),crypto.randomBytes(32),holdTwo],
  );
  assert.equal(await countIdempotencyRows(admin.actorId,idempotencyKey),1);
  assert.equal(await countIdempotencyRows(actorTwo,idempotencyKey),1);
  assert.notEqual(first.id,holdTwo);
});

test('dry-run keyset pagination preserves PostgreSQL microsecond cursor precision', {skip:!enabled}, async()=>{
  const admin=await createPrimaryAdmin();
  const eventTypes=[
    'RETENTION_CURSOR_MICROSECOND_A',
    'RETENTION_CURSOR_MICROSECOND_B',
    'RETENTION_CURSOR_MICROSECOND_C',
  ];
  const createdAt=[
    '2999-01-01T00:00:00.123001Z',
    '2999-01-01T00:00:00.123002Z',
    '2999-01-01T00:00:00.123003Z',
  ];
  for(let i=0;i<eventTypes.length;i+=1){
    await createOutboxEvent({
      eventType:eventTypes[i],
      aggregateType:'notification',
      createdAt:createdAt[i],
    });
  }
  const result=await repository.buildOutboxRetentionDryRun({
    ...admin,pageSize:1,maxRows:1000,
  });
  const cursorItems=result.items.filter(item=>eventTypes.includes(item.eventType));
  assert.deepEqual(cursorItems.map(item=>item.eventType),eventTypes);
  assert.equal(new Set(cursorItems.map(item=>item.eventType)).size,3);
  assert.equal(result.scanned,result.totalCount);
  assert.equal(result.pagesRead,result.totalCount);
});

test('financial exclusion uses the same ASCII edge-whitespace rules for count, page, and has_more', {skip:!enabled}, async()=>{
  const admin=await createPrimaryAdmin();
  const before=await repository.buildOutboxRetentionDryRun({
    ...admin,pageSize:100,maxRows:1000,
  });
  const createdAt='2999-01-02T00:00:00.000000Z';
  const padded=[
    await createOutboxEvent({eventType:'\tPAYMENT_REFUND\r\n',aggregateType:'notification',createdAt}),
    await createOutboxEvent({eventType:'RETENTION_EDGE_LEDGER',aggregateType:'\tledger\n',createdAt}),
    await createOutboxEvent({eventType:'RETENTION_EDGE_WALLET',aggregateType:'\r\nwallet\t',createdAt}),
  ];
  const maxRows=Math.max(1,before.totalCount);
  const after=await repository.buildOutboxRetentionDryRun({
    ...admin,pageSize:100,maxRows,
  });
  assert.equal(after.totalCount,before.totalCount);
  assert.equal(after.items.some(candidate=>padded.some(item=>
    candidate.eventType===item.eventType || candidate.aggregateType===item.aggregateType
  )),false);
  assert.equal(after.truncated,false,'financial rows after the last eligible cursor must not make has_more true');
});


test('idempotent replay revalidates current WRITE session and cannot use a stale JTI',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const idempotencyKey=`stale-session-replay-${uuid()}`;
  const input={
    ...admin,target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',idempotencyKey,
  };
  const first=await createHold(input);
  await pool.query(
    'UPDATE users SET admin_panel_verified_session_jti=$2,admin_panel_verified_at=NOW(),admin_panel_verified_scope=\'WRITE\' WHERE id=$1',
    [admin.actorId,uuid()],
  );
  await assert.rejects(
    createHold(input),
    error=>error?.code==='ADMIN_PANEL_LOCKED' && error?.status===403,
  );
  assert.equal(await holdCountForEvent(event.id),1);
  assert.equal(await countHoldAuditRows(first.id),1);
});

test('idempotency mappings reject UPDATE and DELETE as immutable evidence',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const idempotencyKey=`immutable-map-${uuid()}`;
  const hold=await createHold({
    ...admin,target:{kind:'EVENT',eventId:event.id},
    holdKind:'ADMIN',reasonCode:'ADMIN_REVIEW',idempotencyKey,
  });
  await assert.rejects(
    pool.query(
      'UPDATE admin_outbox_retention_hold_idempotency SET request_digest=$3 WHERE actor_id=$1 AND key_digest=$2',
      [admin.actorId,idempotencyKeyDigest(idempotencyKey),crypto.randomBytes(32)],
    ),
    error=>error?.code==='55000' && String(error.message).includes('OUTBOX_RETENTION_LEDGER_IMMUTABLE'),
  );
  await assert.rejects(
    pool.query(
      'DELETE FROM admin_outbox_retention_hold_idempotency WHERE actor_id=$1 AND key_digest=$2',
      [admin.actorId,idempotencyKeyDigest(idempotencyKey)],
    ),
    error=>error?.code==='55000' && String(error.message).includes('OUTBOX_RETENTION_LEDGER_IMMUTABLE'),
  );
  assert.equal(await countIdempotencyRows(admin.actorId,idempotencyKey),1);
  assert.equal(await countHoldAuditRows(hold.id),1);
});


test('immutable Outbox hold, release and idempotency evidence reject TRUNCATE',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const hold=await createHold({
    ...admin,target:{kind:'EVENT',eventId:event.id},
    holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',
    idempotencyKey:`truncate-guard-${uuid()}`,
  });
  await repository.releaseOutboxRetentionHold({
    ...admin,holdId:hold.id,reasonCode:'CASE_CLOSED',
  });

  async function assertTruncateRejected(sql) {
    const client=await pool.connect();
    try {
      await client.query('BEGIN');
      await assert.rejects(
        client.query(sql),
        error=>error?.code==='55000'
          && String(error.message).includes('OUTBOX_RETENTION_LEDGER_IMMUTABLE'),
      );
    } finally {
      await client.query('ROLLBACK');
      client.release();
    }
  }

  await assertTruncateRejected('TRUNCATE TABLE admin_outbox_retention_hold_idempotency');
  await assertTruncateRejected('TRUNCATE TABLE outbox_retention_hold_releases');
  await assertTruncateRejected('TRUNCATE TABLE outbox_retention_holds CASCADE');

  assert.equal(await countIdempotencyRows(admin.actorId,`truncate-guard`),0,'distinct digest helper sanity');
  assert.equal(await countHoldAuditRows(hold.id),1);
  assert.equal(await holdCountForEvent(event.id),1);
  const {rows:releaseRows}=await pool.query(
    'SELECT COUNT(*)::int AS count FROM outbox_retention_hold_releases WHERE hold_id=$1',
    [hold.id],
  );
  assert.equal(releaseRows[0].count,1);
});
