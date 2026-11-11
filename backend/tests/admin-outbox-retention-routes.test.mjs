import test from 'node:test';
import assert from 'node:assert/strict';

import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { PRIMARY_ADMIN_EMAIL } from '../src/application/admin_panel_access.js';

const OPS_ADMIN = Object.freeze({
  id:'admin-outbox-operator',
  email:'ops-outbox@example.test',
  displayName:'Outbox Operator',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'google-outbox-operator',
  sessionJti:'ops-outbox-session',
});

const PRIMARY_ADMIN = Object.freeze({
  id:'admin-outbox-primary',
  email:PRIMARY_ADMIN_EMAIL,
  displayName:'Primary Owner',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'google-outbox-primary',
  sessionJti:'primary-outbox-session',
});

const HOLD_ID = '00000000-0000-4000-8000-000000000060';
const EVENT_ID = '00000000-0000-4000-8000-000000000061';
const CREATED_AT = '2026-11-11T00:00:00.000Z';

const DRY_RUN = Object.freeze({
  mode:'DRY_RUN',
  asOf:CREATED_AT,
  limit:100,
  maxRows:500,
  totalCount:1,
  scanned:1,
  pagesRead:1,
  truncated:false,
  retentionPolicyConfigured:false,
  wouldMutate:false,
  mutationCount:0,
  providerCalls:0,
  payloadIncluded:false,
  piiIncluded:false,
  items:[{
    eventType:'NOTIFICATION_DISPATCH',
    aggregateType:'notification',
    status:'DONE',
    createdAt:CREATED_AT,
    terminalAt:CREATED_AT,
    retentionClass:'NOTIFICATION',
    activeHoldCount:0,
    activeHoldKinds:[],
    eligible:false,
    blockers:['RETENTION_PERIOD_NOT_APPROVED'],
  }],
});

function makeHarness({user=OPS_ADMIN,verified=true,repoOverrides={}}={}) {
  const calls=[];
  const audit=[];
  const verificationCalls=[];
  const repo={
    async isAdminPanelVerified(...args) {
      verificationCalls.push(args);
      return verified;
    },
    async buildOutboxRetentionDryRun(options) {
      calls.push(['dry-run',options]);
      return DRY_RUN;
    },
    async createOutboxRetentionHold(options) {
      calls.push(['create-hold',options]);
      return {
        id:HOLD_ID,
        targetKind:options.target.kind,
        holdKind:options.holdKind,
        reasonCode:options.reasonCode,
        createdAt:CREATED_AT,
      };
    },
    async releaseOutboxRetentionHold(options) {
      calls.push(['release-hold',options]);
      return {
        id:options.holdId,
        released:true,
        releasedBy:options.actorId,
        reasonCode:options.reasonCode,
        releasedAt:CREATED_AT,
      };
    },
    ...repoOverrides,
  };

  const routes=createAdminRoutes({
    authUser:async()=>user,
    requireAdmin:(candidate)=>{
      if (!candidate || candidate.status!=='ACTIVE' || candidate.role!=='ADMIN') {
        throw new HttpError(403,'FORBIDDEN','Administrator access required');
      }
      if (
        candidate.email?.toLowerCase()===PRIMARY_ADMIN_EMAIL.toLowerCase()
        && !String(candidate.googleSubject||'').trim()
      ) {
        throw new HttpError(403,'PRIMARY_ADMIN_IDENTITY_REQUIRED','Link a verified Google account before administering HOPE');
      }
      return candidate;
    },
    readBody:async(req)=>req.body ?? {},
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

  const invoke=(method,parts,body={},query='')=>routes({
    method,
    url:'/api/v1/'+parts.join('/')+query,
    headers:{host:'localhost','content-type':'application/json'},
    body,
  },{},parts);

  return {invoke,repo,calls,audit,verificationCalls};
}

test('Outbox dry-run is a session-bound READ endpoint with sanitized inventory and summary audit',async()=>{
  const h=makeHarness();
  const response=await h.invoke(
    'GET',
    ['admin','outbox-retention','dry-run'],
    {},
    '?pageSize=100&maxRows=500',
  );

  assert.equal(response.status,200);
  assert.equal(response.data.mode,'DRY_RUN');
  assert.equal(response.data.wouldMutate,false);
  assert.equal(response.data.mutationCount,0);
  assert.equal(response.data.providerCalls,0);
  assert.deepEqual(h.verificationCalls,[
    [OPS_ADMIN.id,15,OPS_ADMIN.sessionJti,'READ'],
  ]);
  assert.deepEqual(h.calls,[
    ['dry-run',{
      actorId:OPS_ADMIN.id,
      sessionJti:OPS_ADMIN.sessionJti,
      pageSize:100,
      maxRows:500,
    }],
  ]);
  assert.equal(h.audit[0]?.[0],'ADMIN_OUTBOX_RETENTION_DRY_RUN');
  assert.equal(h.audit[0]?.[1],OPS_ADMIN.id);
  assert.equal(JSON.stringify(response.data).includes(EVENT_ID),false);
});

test('operational administrators cannot create or release Outbox holds',async()=>{
  const h=makeHarness();
  await assert.rejects(
    h.invoke('POST',['admin','outbox-retention','holds'],{
      target:{kind:'EVENT',eventId:EVENT_ID},
      holdKind:'LEGAL',
      reasonCode:'LEGAL_REQUEST',
    }),
    (error)=>error?.status===403 && error?.code==='ADMIN_PERMISSION_DENIED',
  );
  await assert.rejects(
    h.invoke('POST',['admin','outbox-retention','holds',HOLD_ID,'release'],{
      reasonCode:'CASE_CLOSED',
    }),
    (error)=>error?.status===403 && error?.code==='ADMIN_PERMISSION_DENIED',
  );
  assert.equal(h.calls.length,0);
  assert.equal(h.audit.length,0);
});

test('only linked primary admin can create a hold with actor and session derived from authentication',async()=>{
  const h=makeHarness({user:PRIMARY_ADMIN});
  const target={kind:'EVENT',eventId:EVENT_ID};
  const response=await h.invoke('POST',['admin','outbox-retention','holds'],{
    target,
    holdKind:'LEGAL',
    reasonCode:'LEGAL_REQUEST',
  });

  assert.equal(response.status,201);
  assert.deepEqual(h.verificationCalls,[
    [PRIMARY_ADMIN.id,5,PRIMARY_ADMIN.sessionJti,'WRITE'],
  ]);
  assert.deepEqual(h.calls,[
    ['create-hold',{
      actorId:PRIMARY_ADMIN.id,
      sessionJti:PRIMARY_ADMIN.sessionJti,
      target,
      holdKind:'LEGAL',
      reasonCode:'LEGAL_REQUEST',
    }],
  ]);
  assert.deepEqual(Object.keys(response.data).sort(),[
    'createdAt','holdKind','id','reasonCode','targetKind',
  ]);
  assert.equal(h.audit.length,0,'the repository must write common audit atomically with hold evidence');
});

test('release response is projected to a safe DTO without actor identifiers',async()=>{
  const h=makeHarness({user:PRIMARY_ADMIN});
  const response=await h.invoke(
    'POST',
    ['admin','outbox-retention','holds',HOLD_ID,'release'],
    {reasonCode:'CASE_CLOSED'},
  );

  assert.equal(response.status,200);
  assert.deepEqual(h.calls,[
    ['release-hold',{
      actorId:PRIMARY_ADMIN.id,
      sessionJti:PRIMARY_ADMIN.sessionJti,
      holdId:HOLD_ID,
      reasonCode:'CASE_CLOSED',
    }],
  ]);
  assert.deepEqual(Object.keys(response.data).sort(),[
    'id','reasonCode','released','releasedAt',
  ]);
  assert.equal('releasedBy' in response.data,false);
  assert.equal('actorId' in response.data,false);
});

test('hold requests reject caller-supplied identity fields, invalid UUIDs and unsupported reasons',async()=>{
  const h=makeHarness({user:PRIMARY_ADMIN});
  await assert.rejects(
    h.invoke('POST',['admin','outbox-retention','holds'],{
      target:{kind:'EVENT',eventId:'not-a-uuid'},
      holdKind:'LEGAL',
      reasonCode:'LEGAL_REQUEST',
    }),
    (error)=>error?.status===400,
  );
  await assert.rejects(
    h.invoke('POST',['admin','outbox-retention','holds'],{
      target:{kind:'EVENT',eventId:EVENT_ID},
      holdKind:'LEGAL',
      reasonCode:'FREE_TEXT_REASON',
    }),
    (error)=>error?.status===400,
  );
  await assert.rejects(
    h.invoke('POST',['admin','outbox-retention','holds'],{
      target:{kind:'EVENT',eventId:EVENT_ID},
      holdKind:'LEGAL',
      reasonCode:'LEGAL_REQUEST',
      actorId:'attacker-controlled-actor',
      sessionJti:'attacker-controlled-session',
    }),
    (error)=>error?.status===400,
  );
  assert.equal(h.calls.length,0);
});

test('invalid and duplicate dry-run query parameters are rejected before inventory access',async()=>{
  const h=makeHarness();
  await assert.rejects(
    h.invoke('GET',['admin','outbox-retention','dry-run'],{},'?pageSize=101'),
    (error)=>error?.status===400,
  );
  await assert.rejects(
    h.invoke('GET',['admin','outbox-retention','dry-run'],{},'?pageSize=10&pageSize=20'),
    (error)=>error?.status===400,
  );
  assert.equal(h.calls.length,0);
});

test('repository conflict is mapped to a stable public error without SQL details',async()=>{
  const h=makeHarness({
    user:PRIMARY_ADMIN,
    repoOverrides:{
      async releaseOutboxRetentionHold() {
        throw Object.assign(
          new Error('duplicate key value violates unique constraint outbox_retention_hold_releases_pkey'),
          {code:'OUTBOX_RETENTION_HOLD_ALREADY_RELEASED'},
        );
      },
    },
  });

  await assert.rejects(
    h.invoke('POST',['admin','outbox-retention','holds',HOLD_ID,'release'],{
      reasonCode:'CASE_CLOSED',
    }),
    (error)=>error?.status===409
      && error?.code==='OUTBOX_RETENTION_HOLD_ALREADY_RELEASED'
      && !String(error.message).includes('duplicate key'),
  );
});
