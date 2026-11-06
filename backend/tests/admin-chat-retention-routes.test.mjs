import test from 'node:test';
import assert from 'node:assert/strict';

import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';
import { PRIMARY_ADMIN_EMAIL } from '../src/application/admin_panel_access.js';

const OPS_ADMIN = Object.freeze({
  id:'retention-ops-admin',
  email:'ops-retention@example.test',
  displayName:'Retention Operator',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'google-ops-retention',
  sessionJti:'retention-ops-session-jti',
});

const PRIMARY_ADMIN = Object.freeze({
  id:'retention-primary-admin',
  email:PRIMARY_ADMIN_EMAIL,
  displayName:'Primary Owner',
  role:'ADMIN',
  status:'ACTIVE',
  googleSubject:'google-primary-retention',
  sessionJti:'retention-primary-session-jti',
});

const CONVERSATION_ID = '00000000-0000-4000-8000-000000000001';
const HOLD_ID = '00000000-0000-4000-8000-000000000002';

const EMPTY_PLAN = Object.freeze({
  mode:'DRY_RUN',
  asOf:'2026-11-06T00:00:00.000Z',
  limit:200,
  scanned:0,
  wouldMutate:false,
  mutationCount:0,
  providerDeleteCalls:0,
  summary:{},
  items:[],
  totalCount:0,
  hasMore:false,
  nextCursor:null,
  pageComplete:true,
  inventoryComplete:true,
  cursorProvided:false,
});

function makeHarness({user=OPS_ADMIN,verified=true,plan=EMPTY_PLAN}={}) {
  const audit=[];
  const calls=[];
  const verificationCalls=[];
  let holdId=0;
  const repo={
    async isAdminPanelVerified(...args) {
      verificationCalls.push(args);
      return verified;
    },
    async buildChatRetentionDryRun(options) {
      calls.push(['dry-run',options]);
      return plan;
    },
    async createChatConversationLegalHold(input) {
      calls.push(['create-hold',input]);
      holdId+=1;
      return {
        id:HOLD_ID,
        conversationId:input.conversationId,
        holdKind:input.holdKind,
        reason:input.reason,
        createdBy:input.createdBy,
        releasedAt:null,
      };
    },
    async releaseChatConversationLegalHold(input) {
      calls.push(['release-hold',input]);
      return {
        id:input.holdId,
        conversationId:'00000000-0000-4000-8000-000000000001',
        releasedBy:input.releasedBy,
        releaseReason:input.releaseReason,
        releasedAt:'2026-11-06T00:00:00.000Z',
      };
    },
  };
  const route=createAdminRoutes({
    authUser:async()=>user,
    requireAdmin:(candidate)=>{
      if(candidate?.role!=='ADMIN')throw new HttpError(403,'FORBIDDEN','Administrator access required');
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

test('admin chat-retention dry-run requires session-bound READ verification and VIEW_AUDIT',async()=>{
  const h=makeHarness();
  const response=await h.invoke('GET',['admin','privacy','chat-retention','dry-run']);
  assert.equal(response.status,200);
  assert.equal(response.data,EMPTY_PLAN);
  assert.deepEqual(h.verificationCalls,[
    [OPS_ADMIN.id,15,OPS_ADMIN.sessionJti,'READ'],
  ]);
  assert.deepEqual(h.calls,[['dry-run',{limit:200,cursor:null}]]);
  assert.equal(h.audit.length,1);
  assert.equal(h.audit[0][0],'ADMIN_CHAT_RETENTION_DRY_RUN');
  assert.equal(h.audit[0][1],OPS_ADMIN.id);
  assert.equal(h.audit[0][2],'chat_retention');
  assert.equal(h.audit[0][5].wouldMutate,false);
});

test('admin chat-retention dry-run fails closed when current READ step-up is absent',async()=>{
  const h=makeHarness({verified:false});
  await assert.rejects(
    h.invoke('GET',['admin','privacy','chat-retention','dry-run']),
    (error)=>error?.status===403&&error?.code==='ADMIN_PANEL_LOCKED',
  );
  assert.equal(h.calls.length,0);
  assert.equal(h.audit.length,0);
});

test('operational administrators cannot create or release privacy holds',async()=>{
  const h=makeHarness();
  await assert.rejects(
    h.invoke('POST',['admin','privacy','chat-retention','holds'],{
      conversationId:'00000000-0000-4000-8000-000000000001',holdKind:'LEGAL',reason:'Preserve dispute evidence',
    }),
    (error)=>error?.status===403&&error?.code==='ADMIN_PERMISSION_DENIED',
  );
  await assert.rejects(
    h.invoke('POST',['admin','privacy','chat-retention','holds',HOLD_ID,'release'],{
      reason:'Hold no longer required',
    }),
    (error)=>error?.status===403&&error?.code==='ADMIN_PERMISSION_DENIED',
  );
  assert.equal(h.calls.length,0);
  assert.equal(h.audit.length,0);
});

test('primary admin can create and release legal holds with WRITE step-up and audited reasons',async()=>{
  const h=makeHarness({user:PRIMARY_ADMIN});
  const created=await h.invoke('POST',['admin','privacy','chat-retention','holds'],{
    conversationId:'00000000-0000-4000-8000-000000000001',
    holdKind:'LEGAL',
    reason:'Preserve evidence for an open dispute',
  });
  assert.equal(created.status,201);
  assert.equal(created.data.id,HOLD_ID);
  assert.deepEqual(h.calls[0],['create-hold',{
    conversationId:'00000000-0000-4000-8000-000000000001',
    holdKind:'LEGAL',
    reason:'Preserve evidence for an open dispute',
    createdBy:PRIMARY_ADMIN.id,
  }]);
  assert.deepEqual(h.verificationCalls[0],[
    PRIMARY_ADMIN.id,5,PRIMARY_ADMIN.sessionJti,'WRITE',
  ]);
  assert.equal(h.audit[0][0],'ADMIN_CHAT_LEGAL_HOLD_CREATED');
  assert.equal(h.audit[0][5].reason,'Preserve evidence for an open dispute');

  const released=await h.invoke('POST',['admin','privacy','chat-retention','holds',HOLD_ID,'release'],{
    reason:'Dispute finally resolved; legal preservation no longer required',
  });
  assert.equal(released.status,200);
  assert.equal(released.data.id,HOLD_ID);
  assert.deepEqual(h.calls[1],['release-hold',{
    holdId:HOLD_ID,
    releasedBy:PRIMARY_ADMIN.id,
    releaseReason:'Dispute finally resolved; legal preservation no longer required',
  }]);
  assert.deepEqual(h.verificationCalls[1],[
    PRIMARY_ADMIN.id,5,PRIMARY_ADMIN.sessionJti,'WRITE',
  ]);
  assert.equal(h.audit[1][0],'ADMIN_CHAT_LEGAL_HOLD_RELEASED');
  assert.equal(h.audit[1][5].reason,'Dispute finally resolved; legal preservation no longer required');
});

test('legal hold mutations reject invalid identifiers, kinds and empty reasons',async()=>{
  const h=makeHarness({user:PRIMARY_ADMIN});
  await assert.rejects(
    h.invoke('POST',['admin','privacy','chat-retention','holds'],{
      conversationId:'not-a-uuid',holdKind:'LEGAL',reason:'Reason is present',
    }),
    (error)=>error?.status===400,
  );
  await assert.rejects(
    h.invoke('POST',['admin','privacy','chat-retention','holds'],{
      conversationId:'00000000-0000-4000-8000-000000000001',holdKind:'INVALID',reason:'Reason is present',
    }),
    (error)=>error?.status===400,
  );
  await assert.rejects(
    h.invoke('POST',['admin','privacy','chat-retention','holds'],{
      conversationId:'00000000-0000-4000-8000-000000000001',holdKind:'LEGAL',reason:'   ',
    }),
    (error)=>error?.status===400,
  );
  assert.equal(h.calls.length,0);
  assert.equal(h.audit.length,0);
});

test('admin chat-retention dry-run paginates with a stable cursor and reports inventory completeness',async()=>{
  const plan={...EMPTY_PLAN,limit:1,scanned:1,totalCount:7,hasMore:true,nextCursor:'eyJjdXJzb3IiOiIxIn0',pageComplete:false,inventoryComplete:false};
  const h=makeHarness({plan});
  const response=await h.invoke('GET',['admin','privacy','chat-retention','dry-run'],{},'?limit=1&cursor=eyJjdXJzb3IiOiIxIn0');
  assert.equal(response.status,200);
  assert.equal(response.data.hasMore,true);
  assert.equal(response.data.totalCount,7);
  assert.equal(response.data.inventoryComplete,false);
  assert.deepEqual(h.calls,[['dry-run',{limit:1,cursor:'eyJjdXJzb3IiOiIxIn0'}]]);
  assert.equal(h.audit[0][5].hasMore,true);
  assert.equal(h.audit[0][5].totalCount,7);
  assert.equal(h.audit[0][5].cursorProvided,true);
});

test('admin chat-retention dry-run rejects invalid page limits before scanning',async()=>{
  const h=makeHarness();
  await assert.rejects(
    h.invoke('GET',['admin','privacy','chat-retention','dry-run'],{},'?limit=1001'),
    (error)=>error?.status===400&&error?.code==='INVALID_RETENTION_LIMIT',
  );
  await assert.rejects(
    h.invoke('GET',['admin','privacy','chat-retention','dry-run'],{},'?limit=1.5'),
    (error)=>error?.status===400&&error?.code==='INVALID_RETENTION_LIMIT',
  );
  assert.equal(h.calls.length,0);
  assert.equal(h.audit.length,0);
});
