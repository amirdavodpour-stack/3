import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { PRIMARY_ADMIN_EMAIL } from '../src/application/admin_panel_access.js';

const PRIMARY_ADMIN = Object.freeze({
  id:'security-replay-primary-admin',
  email:PRIMARY_ADMIN_EMAIL,
  displayName:'Primary Owner',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'verified-security-replay-owner',
  sessionJti:'security-replay-owner-session',
});
const OPS_ADMIN = Object.freeze({
  id:'security-replay-ops-admin',
  email:'ops-security-replay@example.test',
  displayName:'Operations Admin',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'verified-security-replay-ops',
  sessionJti:'security-replay-ops-session',
});
const EVENT_ID='00000000-0000-4000-8000-000000000053';
const IDEMPOTENCY_KEY='hope-admin-replay-000000000053';
const REASON='Receiver was restored and delivery logs were reconciled.';

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

function makeHarness({user=PRIMARY_ADMIN,verified=true}={}) {
  const calls=[];
  const verificationCalls=[];
  const repo={
    async isAdminPanelVerified(...args) {
      verificationCalls.push(args);
      return verified;
    },
  };
  const adminUseCases={
    async replaySecurityAlert(options) {
      calls.push(options);
      return {
        eventId:options.eventId,
        status:'PENDING',
        replayed:true,
        alreadyReplayed:false,
        replayCount:1,
      };
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
    adminUseCases,
    repo,
  });
  const invoke=(headers={'idempotency-key':IDEMPOTENCY_KEY},body={reason:REASON},parts=['admin','security-alerts',EVENT_ID,'replay'])=>route({
    method:'POST',
    url:'/api/v1/'+parts.join('/'),
    headers:{host:'localhost',...headers},
    body,
  },{},parts);
  return {invoke,route,calls,verificationCalls};
}

test('primary admin replays one security alert through the PostgreSQL-only use case with WRITE step-up',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness();
    const response=await h.invoke();
    assert.equal(response.status,200);
    assert.deepEqual(response.data,{
      eventId:EVENT_ID,
      status:'PENDING',
      replayed:true,
      alreadyReplayed:false,
      replayCount:1,
    });
    assert.deepEqual(h.verificationCalls,[[PRIMARY_ADMIN.id,5,PRIMARY_ADMIN.sessionJti,'WRITE']]);
    assert.deepEqual(h.calls,[{
      eventId:EVENT_ID,
      actorId:PRIMARY_ADMIN.id,
      sessionJti:PRIMARY_ADMIN.sessionJti,
      verificationMinutes:5,
      reason:REASON,
      idempotencyKey:IDEMPOTENCY_KEY,
    }]);
  });
});

test('operational administrators cannot replay security alerts',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({user:OPS_ADMIN});
    await assert.rejects(
      h.invoke(),
      (error)=>error?.status===403&&['ADMIN_PERMISSION_DENIED','PRIMARY_ADMIN_ONLY'].includes(error?.code),
    );
    assert.equal(h.calls.length,0);
  });
});

test('security alert replay requires current-session WRITE step-up',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness({verified:false});
    await assert.rejects(
      h.invoke(),
      (error)=>error?.status===403&&error?.code==='ADMIN_PANEL_LOCKED',
    );
    assert.equal(h.calls.length,0);
  });
});

test('security alert replay rejects malformed event id, reason, missing or duplicated idempotency keys',async()=>{
  await withDatabaseUrl('postgresql://unit-test.invalid/hope',async()=>{
    const h=makeHarness();
    await assert.rejects(
      h.invoke({'idempotency-key':IDEMPOTENCY_KEY},{reason:'   '}),
      (error)=>error?.status===400,
    );
    await assert.rejects(
      h.invoke({}, {reason:REASON}),
      (error)=>error?.status===400,
    );
    await assert.rejects(
      h.invoke({'idempotency-key':[IDEMPOTENCY_KEY,IDEMPOTENCY_KEY]},{reason:REASON}),
      (error)=>error?.status===400,
    );
    await assert.rejects(
      h.invoke({'idempotency-key':'k'.repeat(201)},{reason:REASON}),
      (error)=>error?.status===400,
    );
    await assert.rejects(
      h.invoke({'idempotency-key':IDEMPOTENCY_KEY},{reason:'r'.repeat(1001)}),
      (error)=>error?.status===400,
    );
    await assert.rejects(
      h.invoke({'idempotency-key':IDEMPOTENCY_KEY},{reason:REASON},['admin','security-alerts','not-a-uuid','replay']),
      (error)=>error?.status===400,
    );
    assert.equal(h.calls.length,0);
  });
});

test('replay API fails closed when PostgreSQL persistence is unavailable',async()=>{
  await withDatabaseUrl(null,async()=>{
    const h=makeHarness();
    await assert.rejects(
      h.invoke(),
      (error)=>error?.status===503&&error?.code==='SECURITY_ALERT_REPLAY_UNAVAILABLE',
    );
    assert.equal(h.calls.length,0);
  });
});


test('OpenAPI documents the narrow primary-admin replay request contract',async()=>{
  const source=await readFile(new URL('../openapi/openapi.yaml',import.meta.url),'utf8');
  const start=source.indexOf('  /admin/security-alerts/{eventId}/replay:');
  const end=source.indexOf('  /admin/jobs/{id}/moderate:',start);
  assert.ok(start>=0&&end>start,'dedicated security alert replay path must be documented');
  const operation=source.slice(start,end);
  assert.match(operation,/security:\s*\[\{bearerAuth:\s*\[\]\}\]/);
  assert.match(operation,/name: Idempotency-Key/);
  assert.match(operation,/in: header/);
  assert.match(operation,/requestBody:/);
  assert.match(operation,/reason: \{type: string, minLength: 3, maxLength: 1000\}/);
  assert.match(operation,/'403': \{description: Requires verified primary admin/);
  assert.match(operation,/'409': \{description: Event is not replayable/);
});
