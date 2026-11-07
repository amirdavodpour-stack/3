import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import * as dbModule from '../src/db.js';
import { transitionAdminJobApplication } from '../src/repository/applications.js';
import { setAdminPanelVerified } from '../src/repository/disputes.js';
import { creditWallet } from '../src/wallet_ledger.js';

const enabled=Boolean(process.env.DATABASE_URL);
if(process.env.REQUIRE_INTEGRATION==='1'&&!enabled) throw new Error('REQUIRE_INTEGRATION=1 but DATABASE_URL is missing');
if(enabled) await dbModule.initDatabase();
const pool=enabled?dbModule.getPool():null;
const uid=()=>crypto.randomUUID();

async function createUser(role,prefix) {
  const id=uid();
  await pool.query(
    `INSERT INTO users(id,email,password_hash,display_name,role,status,session_version,created_at,google_subject)
     VALUES($1,$2,'postgres-admin-application-test','Application integration fixture',$3,'ACTIVE',0,NOW(),$4)`,
    [id,`${prefix}-${id}@example.test`,role,`google-${id}`],
  );
  return id;
}

async function createApplication(candidateId,prefix) {
  const ownerId=await createUser('USER',`${prefix}-owner`);
  const providerId=await createUser('USER',`${prefix}-provider`);
  const {rows:categories}=await pool.query('SELECT id FROM categories WHERE is_active=TRUE ORDER BY created_at NULLS FIRST,id LIMIT 1');
  assert.ok(categories[0],'at least one active category is required for the integration fixture');
  const jobId=uid();
  await pool.query(
    `INSERT INTO jobs(id,owner_id,provider_id,title,description,category_id,job_type,budget_type,budget_min,budget_max,duration,acceptance_criteria,status,city,kind,visibility,created_at,updated_at)
     VALUES($1,$2,$3,'Admin application integration fixture','Fixture description',$4,'FIXED','FIXED',100,100,1,'Acceptance test','PUBLISHED','Integration test city','JOB','PUBLIC',NOW(),NOW())`,
    [jobId,ownerId,providerId,categories[0].id],
  );
  const applicationId=uid();
  await pool.query(
    `INSERT INTO job_applications(id,job_id,candidate_id,resume_text,skills,status,created_at,updated_at)
     VALUES($1,$2,$3,'Candidate resume','PostgreSQL, testing','PENDING',NOW(),NOW())`,
    [applicationId,jobId,candidateId],
  );
  return {jobId,applicationId,ownerId,providerId};
}

async function createAdminContext(prefix) {
  const adminId=await createUser('ADMIN',prefix);
  const sessionJti=`${prefix}-session-${uid()}`;
  assert.ok(await setAdminPanelVerified(adminId,sessionJti,'WRITE'));
  return {adminId,sessionJti};
}

const actionCases=[
  {from:'PENDING',to:'SHORTLISTED',audit:'ADMIN_APPLICATION_SHORTLIST',type:'APPLICATION_SHORTLISTED',title:'Shortlisted',body:'Application moved to shortlist'},
  {from:['PENDING','SHORTLISTED'],to:'FORWARDED',audit:'ADMIN_APPLICATION_FORWARD',type:'APPLICATION_FORWARDED',title:'Forwarded',body:'Application forwarded to employer'},
  {from:['PENDING','SHORTLISTED'],to:'REJECTED',audit:'ADMIN_APPLICATION_REJECT',type:'APPLICATION_REJECTED',title:'Rejected',body:'Application rejected'},
];

function optionsFor(admin,action) {
  return {
    actorId:admin.adminId,
    sessionJti:admin.sessionJti,
    verificationMinutes:5,
    notification:{type:action.type,title:action.title,body:action.body,channels:['IN_APP','PUSH','EMAIL']},
  };
}

test('PostgreSQL admin application transitions atomically persist state, actor audit, and retryable notification events', {skip:!enabled,timeout:30_000}, async()=>{
  for(const action of actionCases) {
    const admin=await createAdminContext(`application-${action.to.toLowerCase()}`);
    const candidateId=await createUser('USER',`candidate-${action.to.toLowerCase()}`);
    const fixture=await createApplication(candidateId,`application-${action.to.toLowerCase()}`);
    const changed=await transitionAdminJobApplication(fixture.applicationId,action.from,action.to,optionsFor(admin,action));
    assert.equal(changed?.status,action.to);

    const {rows:audit}=await pool.query(
      'SELECT actor_id,action,meta FROM audit_logs WHERE entity_type=\'job_application\' AND entity_id=$1 AND action=$2',
      [fixture.applicationId,action.audit],
    );
    assert.equal(audit.length,1);
    assert.equal(audit[0].actor_id,admin.adminId);
    assert.equal(audit[0].meta.fromStatus,'PENDING');
    assert.equal(audit[0].meta.toStatus,action.to);
    assert.equal(audit[0].meta.sessionJti,admin.sessionJti);

    const dedupeKey=`application:${fixture.applicationId}:${action.type}`;
    const {rows:notifications}=await pool.query(
      `SELECT id,user_id,type,data FROM notifications WHERE user_id=$1 AND data->>'dedupeKey'=$2`,
      [candidateId,dedupeKey],
    );
    assert.equal(notifications.length,1);
    assert.equal(notifications[0].type,action.type);
    assert.equal(notifications[0].data.channels.length,3);
    const {rows:events}=await pool.query(
      `SELECT payload->>'channel' AS channel,status FROM outbox_events
        WHERE event_type='NOTIFICATION_DISPATCH' AND aggregate_type='notification' AND aggregate_id=$1
        ORDER BY payload->>'channel'`,
      [notifications[0].id],
    );
    assert.deepEqual(events.map((event)=>event.channel),['EMAIL','IN_APP','PUSH']);
    assert.ok(events.every((event)=>event.status==='PENDING'), 'all delivery channels must be retryable from the outbox');
  }
});

test('PostgreSQL application audit failure rolls back status, notification and outbox rows together', {skip:!enabled,timeout:30_000}, async()=>{
  const admin=await createAdminContext('application-audit-rollback');
  const candidateId=await createUser('USER','candidate-audit-rollback');
  const fixture=await createApplication(candidateId,'application-audit-rollback');
  const suffix=uid().replaceAll('-','');
  const triggerName=`test_application_audit_fail_${suffix}`;
  const functionName=`test_application_audit_fn_${suffix}`;
  const action={type:'APPLICATION_SHORTLISTED',title:'Shortlisted',body:'Application moved to shortlist'};
  const dedupeKey=`application:${fixture.applicationId}:${action.type}`;

  try {
    await pool.query(
      `CREATE FUNCTION ${functionName}() RETURNS trigger LANGUAGE plpgsql AS $$
       BEGIN
         IF NEW.action='ADMIN_APPLICATION_SHORTLIST' AND NEW.entity_id='${fixture.applicationId}'::uuid THEN
           RAISE EXCEPTION 'SIMULATED_APPLICATION_AUDIT_FAILURE';
         END IF;
         RETURN NEW;
       END $$`,
    );
    await pool.query(`CREATE TRIGGER ${triggerName} BEFORE INSERT ON audit_logs FOR EACH ROW EXECUTE FUNCTION ${functionName}()`);
    await assert.rejects(
      transitionAdminJobApplication(fixture.applicationId,'PENDING','SHORTLISTED',{
        actorId:admin.adminId,sessionJti:admin.sessionJti,verificationMinutes:5,notification:action,
      }),
      /SIMULATED_APPLICATION_AUDIT_FAILURE/,
    );
  } finally {
    await pool.query(`DROP TRIGGER IF EXISTS ${triggerName} ON audit_logs`).catch(()=>{});
    await pool.query(`DROP FUNCTION IF EXISTS ${functionName}()`).catch(()=>{});
  }

  const {rows:application}=await pool.query('SELECT status FROM job_applications WHERE id=$1',[fixture.applicationId]);
  assert.equal(application[0]?.status,'PENDING');
  const {rows:audits}=await pool.query("SELECT id FROM audit_logs WHERE entity_id=$1 AND action='ADMIN_APPLICATION_SHORTLIST'",[fixture.applicationId]);
  assert.equal(audits.length,0);
  const {rows:notifications}=await pool.query("SELECT id FROM notifications WHERE user_id=$1 AND data->>'dedupeKey'=$2",[candidateId,dedupeKey]);
  assert.equal(notifications.length,0);
  const {rows:events}=await pool.query(
    "SELECT id FROM outbox_events WHERE event_type='NOTIFICATION_DISPATCH' AND payload->>'data' IS NOT NULL AND payload->'data'->>'applicationId'=$1",
    [fixture.applicationId],
  );
  assert.equal(events.length,0);
});

test('PostgreSQL sandbox credit records the acting administrator as ledger actor and idempotency principal', {skip:!enabled,timeout:30_000}, async()=>{
  const admin=await createAdminContext('sandbox-credit-admin');
  const beneficiaryId=await createUser('USER','sandbox-credit-beneficiary');
  const idempotencyKey=`sandbox-credit-${uid()}`;
  const result=await creditWallet({
    userId:beneficiaryId,
    actorId:admin.adminId,
    amount:'125',
    idempotencyKey,
    referenceType:'SANDBOX_WALLET_CREDIT',
    metadata:{actorId:admin.adminId,sandbox:true},
  });
  const {rows}=await pool.query(
    `SELECT fo.actor_type,fo.actor_id,ik.principal_id,ik.operation,ik.status,
            we.metadata,wa.user_id AS beneficiary_id
       FROM financial_operations fo
       JOIN idempotency_keys ik ON ik.resource_id=fo.id AND ik.resource_type='financial_operation'
       JOIN wallet_entries we ON we.financial_operation_id=fo.id
       JOIN wallet_accounts wa ON wa.id=we.wallet_id
      WHERE fo.id=$1`,
    [result.operationId],
  );
  assert.equal(rows.length,1);
  assert.equal(rows[0].actor_type,'ADMIN');
  assert.equal(rows[0].actor_id,admin.adminId);
  assert.equal(rows[0].principal_id,admin.adminId);
  assert.equal(rows[0].operation,'TOP_UP');
  assert.equal(rows[0].status,'SUCCEEDED');
  assert.equal(rows[0].metadata.actorId,admin.adminId);
  assert.equal(rows[0].metadata.sandbox,true);
  assert.equal(rows[0].beneficiary_id,beneficiaryId);
});

after(async()=>{if(enabled) await dbModule.db.close();});
