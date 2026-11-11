import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { PRIMARY_ADMIN_EMAIL } from '../src/application/admin_panel_access.js';

const OPS_ADMIN = Object.freeze({
  id:'outbox-retention-ops-admin',
  email:'ops-outbox-retention@example.test',
  displayName:'Outbox Retention Operator',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'google-ops-outbox-retention',
  sessionJti:'outbox-retention-ops-session',
});

const PRIMARY_ADMIN = Object.freeze({
  id:'outbox-retention-primary-admin',
  email:PRIMARY_ADMIN_EMAIL,
  displayName:'Primary Owner',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'google-primary-outbox-retention',
  sessionJti:'outbox-retention-primary-session',
});

const EVENT_ID='00000000-0000-4000-8000-000000000061';
const AGGREGATE_ID='00000000-0000-4000-8000-000000000062';
const HOLD_ID='00000000-0000-4000-8000-000000000063';

async function withDatabaseUrl(value, callback) {
  const previous=process.env.DATABASE_URL;
  if(value==null) delete process.env.DATABASE_URL;
  else process.env.DATABASE_URL=value;
  try { return await callback(); }
  finally {
    if(previous===undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL=previous;
  }
}

function makeHarness({
  user=OPS_ADMIN,
  verified=true,
  plan={
    mode:'DRY_RUN',
    asOf:'2026-11-11T08:00:00.000Z',
    scanned:2,
    pagesRead:2,
    totalCount:9,
    truncated:true,
    wouldMutate:false,
    mutationCount:0,
    providerCalls:0,
    retentionPolicyConfigured:false,
    payloadIncluded:false,
    piiIncluded:false,
    items:[{eligible:false,blockers:['RETENTION_PERIOD_NOT_APPROVED']}],
  },
  createResult={id:HOLD_ID,targetKind:'EVENT',holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST'},
  releaseResult={id:HOLD_ID,released:true,releasedBy:PRIMARY_ADMIN.id,reasonCode:'CASE_CLOSED'},
  createError=null,
  releaseError=null,
}={}) {
  const audit=[];
  const calls=[];
  const verificationCalls=[];
  const repo={
    async isAdminPanelVerified(...args) {
      verificationCalls.push(args);
      return verified;
    },
    async buildOutboxRetentionDryRun(input) {
      calls.push(['dry-run',input]);
      return plan;
    },
    async createOutboxRetentionHold(input) {
      calls.push(['create-hold',input]);
      if(createError) throw createError;
      return createResult;
    },
    async releaseOutboxRetentionHold(input) {
      calls.push(['release-hold',input]);
      if(releaseError) throw releaseError;
      return releaseResult;
    },
  };
  const route=createAdminRoutes({
    authUser:async()=>user,
    requireAdmin:(candidate)=>{
      if(candidate?.role!=='ADMIN') throw new HttpError(403,'FORBIDDEN','Administrator access required');
      return candidate;
    },
    readBody:async(req)=>req.body||{},
    sendJson:async(_res,status,data)=>({status,data}),
    HttpError,
    URL:globalThis.URL,
    config:{
      adminMfaRequired:true,
      adminPanelReadVerificationMinutes:15,
      adminPanelWriteVerificationMinutes:5,
    },
    createAudit:async(...args)=>audit.push(args),
    repo,
  });
  const invoke=(method,parts,body={},query='')=>route({
    method,
    url:'/api/v1/'+parts.join('/')+query,
    headers:{host:'localhost'},
    body,
  },{},parts);
  return {route,invoke,repo,audit,calls,verificationCalls};
}

test('Outbox retention dry-run is available to authorized audit readers with READ step-up',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness();
    const response=await h.invoke(
      'GET',
      ['admin','privacy','outbox-retention','dry-run'],
      {},
      '?pageSize=1&maxRows=2',
    );
    assert.equal(response.status,200);
    assert.equal(response.data.wouldMutate,false);
    assert.deepEqual(h.verificationCalls,[
      [OPS_ADMIN.id,15,OPS_ADMIN.sessionJti,'READ'],
    ]);
    assert.deepEqual(h.calls,[['dry-run',{
      actorId:OPS_ADMIN.id,
      sessionJti:OPS_ADMIN.sessionJti,
      pageSize:1,
      maxRows:2,
    }]]);
    assert.equal(h.audit.length,1);
    assert.equal(h.audit[0][0],'ADMIN_OUTBOX_RETENTION_DRY_RUN');
    assert.equal(h.audit[0][1],OPS_ADMIN.id);
    assert.equal(h.audit[0][5].wouldMutate,false);
    assert.equal(h.audit[0][5].providerCalls,0);
    assert.equal(JSON.stringify(h.audit[0][5]).includes(EVENT_ID),false);
    assert.equal(JSON.stringify(h.audit[0][5]).includes('PRIVATE'),false);
  });
});

test('Outbox retention dry-run fails closed without current-session READ step-up',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({verified:false});
    await assert.rejects(
      h.invoke('GET',['admin','privacy','outbox-retention','dry-run']),
      (error)=>error?.status===403&&error?.code==='ADMIN_PANEL_LOCKED',
    );
    assert.equal(h.calls.length,0);
    assert.equal(h.audit.length,0);
  });
});

test('Outbox retention dry-run bounds pageSize and maxRows before scanning',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness();
    await assert.rejects(
      h.invoke('GET',['admin','privacy','outbox-retention','dry-run'],{},'?pageSize=101'),
      (error)=>error?.status===400&&error?.code==='INVALID_RETENTION_PAGE_SIZE',
    );
    await assert.rejects(
      h.invoke('GET',['admin','privacy','outbox-retention','dry-run'],{},'?maxRows=1001'),
      (error)=>error?.status===400&&error?.code==='INVALID_RETENTION_MAX_ROWS',
    );
    await assert.rejects(
      h.invoke('GET',['admin','privacy','outbox-retention','dry-run'],{},'?pageSize=1.5'),
      (error)=>error?.status===400&&error?.code==='INVALID_RETENTION_PAGE_SIZE',
    );
    assert.equal(h.calls.length,0);
    assert.equal(h.audit.length,0);
  });
});

test('operational administrators cannot create or release Outbox retention holds',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({user:OPS_ADMIN});
    await assert.rejects(
      h.invoke('POST',['admin','privacy','outbox-retention','holds'],{
        target:{kind:'EVENT',eventId:EVENT_ID},
        holdKind:'LEGAL',
        reasonCode:'LEGAL_REQUEST',
      }),
      (error)=>error?.status===403&&error?.code==='ADMIN_PERMISSION_DENIED',
    );
    await assert.rejects(
      h.invoke('POST',['admin','privacy','outbox-retention','holds',HOLD_ID,'release'],{
        reasonCode:'CASE_CLOSED',
      }),
      (error)=>error?.status===403&&error?.code==='ADMIN_PERMISSION_DENIED',
    );
    assert.equal(h.calls.length,0);
    assert.equal(h.audit.length,0);
  });
});

test('Primary Admin creates an event hold and releases it with WRITE step-up and code-only reasons',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({user:PRIMARY_ADMIN});
    const created=await h.invoke(
      'POST',
      ['admin','privacy','outbox-retention','holds'],
      {
        target:{kind:'EVENT',eventId:EVENT_ID},
        holdKind:'LEGAL',
        reasonCode:'LEGAL_REQUEST',
      },
    );
    assert.equal(created.status,201);
    assert.equal(created.data.id,HOLD_ID);
    assert.deepEqual(h.calls[0],['create-hold',{
      actorId:PRIMARY_ADMIN.id,
      sessionJti:PRIMARY_ADMIN.sessionJti,
      target:{kind:'EVENT',eventId:EVENT_ID},
      holdKind:'LEGAL',
      reasonCode:'LEGAL_REQUEST',
    }]);
    assert.deepEqual(h.verificationCalls[0],[
      PRIMARY_ADMIN.id,5,PRIMARY_ADMIN.sessionJti,'WRITE',
    ]);

    const released=await h.invoke(
      'POST',
      ['admin','privacy','outbox-retention','holds',HOLD_ID,'release'],
      {reasonCode:'CASE_CLOSED'},
    );
    assert.equal(released.status,200);
    assert.equal(released.data.released,true);
    assert.deepEqual(h.calls[1],['release-hold',{
      actorId:PRIMARY_ADMIN.id,
      sessionJti:PRIMARY_ADMIN.sessionJti,
      holdId:HOLD_ID,
      reasonCode:'CASE_CLOSED',
    }]);
    assert.deepEqual(h.verificationCalls[1],[
      PRIMARY_ADMIN.id,5,PRIMARY_ADMIN.sessionJti,'WRITE',
    ]);
  });
});

test('Primary Admin can create an aggregate hold without storing free-text reasons',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({user:PRIMARY_ADMIN});
    const response=await h.invoke(
      'POST',
      ['admin','privacy','outbox-retention','holds'],
      {
        target:{kind:'AGGREGATE',aggregateType:'notification',aggregateId:AGGREGATE_ID},
        holdKind:'ADMIN',
        reasonCode:'ADMIN_REVIEW',
        reason:'do not persist free text',
      },
    );
    assert.equal(response.status,201);
    assert.deepEqual(h.calls[0][1],{
      actorId:PRIMARY_ADMIN.id,
      sessionJti:PRIMARY_ADMIN.sessionJti,
      target:{kind:'AGGREGATE',aggregateType:'notification',aggregateId:AGGREGATE_ID},
      holdKind:'ADMIN',
      reasonCode:'ADMIN_REVIEW',
    });
    assert.equal(JSON.stringify(h.calls[0][1]).includes('do not persist free text'),false);
  });
});

test('Outbox hold routes reject malformed targets, hold kinds and unknown reason codes before repository calls',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({user:PRIMARY_ADMIN});
    const path=['admin','privacy','outbox-retention','holds'];
    const invalidBodies=[
      {target:{kind:'EVENT',eventId:'not-a-uuid'},holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST'},
      {target:{kind:'AGGREGATE',aggregateType:'unknown',aggregateId:AGGREGATE_ID},holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST'},
      {target:{kind:'AGGREGATE',aggregateType:'notification',aggregateId:'bad'},holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST'},
      {target:{kind:'OTHER'},holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST'},
      {target:{kind:'EVENT',eventId:EVENT_ID},holdKind:'UNSUPPORTED',reasonCode:'LEGAL_REQUEST'},
      {target:{kind:'EVENT',eventId:EVENT_ID},holdKind:'LEGAL',reasonCode:'FREE_TEXT'},
    ];
    for(const body of invalidBodies){
      await assert.rejects(
        h.invoke('POST',path,body),
        (error)=>error?.status===400,
      );
    }
    assert.equal(h.calls.length,0);
  });
});

test('Outbox hold route maps missing targets and already-released holds to stable HTTP status codes',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const missing=makeHarness({user:PRIMARY_ADMIN,createError:Object.assign(new Error('not found'),{code:'OUTBOX_RETENTION_TARGET_NOT_FOUND'})});
    await assert.rejects(
      missing.invoke('POST',['admin','privacy','outbox-retention','holds'],{
        target:{kind:'EVENT',eventId:EVENT_ID},holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',
      }),
      (error)=>error?.status===404&&error?.code==='OUTBOX_RETENTION_TARGET_NOT_FOUND',
    );

    const released=makeHarness({user:PRIMARY_ADMIN,releaseError:Object.assign(new Error('already released'),{code:'OUTBOX_RETENTION_HOLD_ALREADY_RELEASED'})});
    await assert.rejects(
      released.invoke('POST',['admin','privacy','outbox-retention','holds',HOLD_ID,'release'],{
        reasonCode:'CASE_CLOSED',
      }),
      (error)=>error?.status===409&&error?.code==='OUTBOX_RETENTION_HOLD_ALREADY_RELEASED',
    );
  });
});

test('Outbox retention endpoints fail closed when PostgreSQL persistence is unavailable',async()=>{
  await withDatabaseUrl(null,async()=>{
    const h=makeHarness({user:PRIMARY_ADMIN});
    await assert.rejects(
      h.invoke('GET',['admin','privacy','outbox-retention','dry-run']),
      (error)=>error?.status===503&&error?.code==='OUTBOX_RETENTION_UNAVAILABLE',
    );
    await assert.rejects(
      h.invoke('POST',['admin','privacy','outbox-retention','holds'],{
        target:{kind:'EVENT',eventId:EVENT_ID},holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',
      }),
      (error)=>error?.status===503&&error?.code==='OUTBOX_RETENTION_UNAVAILABLE',
    );
    assert.equal(h.calls.length,0);
  });
});

test('Outbox retention endpoints fail closed when repository capabilities are unavailable',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({user:PRIMARY_ADMIN});
    delete h.repo.buildOutboxRetentionDryRun;
    delete h.repo.createOutboxRetentionHold;
    delete h.repo.releaseOutboxRetentionHold;
    await assert.rejects(
      h.invoke('GET',['admin','privacy','outbox-retention','dry-run']),
      (error)=>error?.status===503&&error?.code==='OUTBOX_RETENTION_UNAVAILABLE',
    );
    await assert.rejects(
      h.invoke('POST',['admin','privacy','outbox-retention','holds'],{
        target:{kind:'EVENT',eventId:EVENT_ID},holdKind:'LEGAL',reasonCode:'LEGAL_REQUEST',
      }),
      (error)=>error?.status===503&&error?.code==='OUTBOX_RETENTION_UNAVAILABLE',
    );
    assert.equal(h.calls.length,0);
  });
});

test('OpenAPI documents Outbox retention routes without any delete or TTL operation',async()=>{
  const source=await readFile(new URL('../openapi/openapi.yaml',import.meta.url),'utf8');
  const dryRunStart=source.indexOf('  /admin/privacy/outbox-retention/dry-run:');
  const holdsStart=source.indexOf('  /admin/privacy/outbox-retention/holds:');
  const releaseStart=source.indexOf('  /admin/privacy/outbox-retention/holds/{holdId}/release:');
  assert.ok(dryRunStart>=0&&holdsStart>dryRunStart&&releaseStart>holdsStart,
    'Outbox retention GET/create/release endpoints must be documented');
  assert.equal(source.includes('/admin/privacy/outbox-retention/purge'),false);
  assert.equal(source.includes('/admin/privacy/outbox-retention/archive'),false);
  const holdOperation=source.slice(holdsStart,releaseStart);
  assert.match(holdOperation,/reasonCode/);
  assert.doesNotMatch(holdOperation,/reason: {type: string/);
});
