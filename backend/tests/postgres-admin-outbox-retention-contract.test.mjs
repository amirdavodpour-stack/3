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
}={}) {
  const id=uuid();
  await pool.query(
    `INSERT INTO outbox_events(
       id,event_type,aggregate_type,aggregate_id,payload,status,attempts,available_at,created_at
     ) VALUES($1,$2,$3,$4,'{}'::jsonb,$5,0,NOW(),NOW())`,
    [id,eventType,aggregateType,aggregateId,status],
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
  await pool.query(
    `CREATE TRIGGER hope_test_outbox_retention_audit_failure
       BEFORE INSERT ON audit_logs
       FOR EACH ROW
       EXECUTE FUNCTION hope_test_outbox_retention_audit_failure($1)`,
    [action],
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
    repository.createOutboxRetentionHold({
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
    repository.createOutboxRetentionHold({
      ...admin,
      target:{kind:'AGGREGATE',aggregateType:'payment',aggregateId:payment.aggregateId},
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    }),
    (error)=>error?.code==='OUTBOX_RETENTION_FINANCIAL_TARGET_EXCLUDED',
  );
  await assert.rejects(
    repository.createOutboxRetentionHold({
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
  const hold=await repository.createOutboxRetentionHold({
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
  const hold=await repository.createOutboxRetentionHold({
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

  try {
    await installAuditFailureTrigger('ADMIN_OUTBOX_RETENTION_HOLD_CREATED');
    await assert.rejects(
      repository.createOutboxRetentionHold({
        ...admin,
        target:{kind:'EVENT',eventId:event.id},
        holdKind:'LEGAL',
        reasonCode:'LEGAL_REQUEST',
      }),
      (error)=>String(error.message).includes('OUTBOX_RETENTION_AUDIT_INJECTED_FAILURE'),
    );
    assert.equal(await holdCountForEvent(event.id),0);
  } finally {
    await removeAuditFailureTrigger();
  }
});

test('audit failure rolls back hold release in the same transaction',{skip:!enabled},async()=>{
  const admin=await createPrimaryAdmin();
  const event=await createOutboxEvent();
  const hold=await repository.createOutboxRetentionHold({
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

after(async()=>{
  if (enabled) await dbModule.db.close();
});
