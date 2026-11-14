import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createAdminRoutes } from '../src/routes/admin_routes.js';
import { HttpError } from '../src/api/http_error.js';

const screen = fs.readFileSync(
  new URL('../../lib/features/admin/admin_operations_page.dart', import.meta.url),
  'utf8',
);
const payoutCardStart = screen.indexOf('Widget _payoutCard(');
const payoutCardEnd = screen.indexOf('Future<void> _resolvePayout', payoutCardStart);
const payoutCard = payoutCardStart >= 0 && payoutCardEnd > payoutCardStart
  ? screen.slice(payoutCardStart, payoutCardEnd)
  : '';

test('admin payout cards render active reconciliation cases instead of hiding nested API data', () => {
  assert.ok(payoutCard, 'admin operations page must define its payout card');
  assert.match(payoutCard, /row\['reconciliationCases'\]/);
  assert.match(payoutCard, /is List/);
  assert.match(payoutCard, /whereType<Map>/);
});

test('admin payout cards display case type, severity, state and expected/observed evidence', () => {
  assert.match(payoutCard, /caseType/);
  assert.match(payoutCard, /severity/);
  assert.match(payoutCard, /status/);
  assert.match(payoutCard, /expected/);
  assert.match(payoutCard, /observed/);
  assert.match(payoutCard, /CRITICAL/);
});

test('admin outbox-event reconciliation queue is read-only and requires payout visibility permission', async () => {
  const admin = {
    id:'outbox-reconciliation-admin',
    email:'ops-outbox@example.test',
    displayName:'Operations Admin',
    role:'ADMIN',
    status:'ACTIVE',
    googleSubject:'google-outbox-admin',
    sessionJti:'outbox-reconciliation-session',
  };
  const cases = [{
    id:'00000000-0000-4000-8000-000000000101',
    caseType:'PAYOUT_OUTBOX_INTEGRITY_MISMATCH',
    resourceType:'outbox_event',
    resourceId:'00000000-0000-4000-8000-000000000102',
    severity:'CRITICAL',
    status:'OPEN',
    expected:{payoutId:'00000000-0000-4000-8000-000000000103'},
    observed:{reason:'PAYOUT_OUTBOX_IDENTITY_MISMATCH'},
    eventType:'PAYOUT_EXECUTE',
    eventStatus:'DONE',
  }];
  const calls = [];
  const page = {cases,hasMore:true,nextCursor:'next-cursor'};
  const repo = {
    async isAdminPanelVerified() { return true; },
    async listActiveOutboxEventReconciliationCases(options) {
      calls.push(options);
      return page;
    },
  };
  const route = createAdminRoutes({
    authUser:async()=>admin,
    requireAdmin:(candidate)=>{
      if(candidate?.role!=='ADMIN') throw new HttpError(403,'FORBIDDEN','Administrator access required');
      return candidate;
    },
    readBody:async(req)=>req.body||{},
    sendJson:(_res,status,data)=>({status,data}),
    HttpError,
    URL:globalThis.URL,
    repo,
    config:{
      adminMfaRequired:true,
      adminPanelReadVerificationMinutes:15,
      adminPanelWriteVerificationMinutes:5,
    },
  });
  const response = await route(
    {method:'GET',url:'/api/v1/admin/reconciliation-cases/outbox-events?limit=25&cursor=opaque-cursor',headers:{host:'localhost'}},
    {},
    ['admin','reconciliation-cases','outbox-events'],
  );
  assert.equal(response.status,200);
  assert.deepEqual(response.data,page);
  assert.deepEqual(calls,[{limit:'25',cursor:'opaque-cursor'}]);
});

test('non-administrators cannot read event-scoped payout reconciliation cases', async () => {
  let listCalls = 0;
  const route = createAdminRoutes({
    authUser:async()=>({id:'user-1',role:'USER',status:'ACTIVE'}),
    requireAdmin:(candidate)=>{
      if(candidate?.role!=='ADMIN') throw new HttpError(403,'FORBIDDEN','Administrator access required');
      return candidate;
    },
    readBody:async()=>({}),
    sendJson:(_res,status,data)=>({status,data}),
    HttpError,
    URL:globalThis.URL,
    repo:{
      async listActiveOutboxEventReconciliationCases() { listCalls += 1; return []; },
    },
    config:{adminMfaRequired:false},
  });
  await assert.rejects(
    route(
      {method:'GET',url:'/api/v1/admin/reconciliation-cases/outbox-events',headers:{host:'localhost'}},
      {},
      ['admin','reconciliation-cases','outbox-events'],
    ),
    (error)=>error?.status===403 && error?.code==='FORBIDDEN',
  );
  assert.equal(listCalls,0);
});

const adminRepositorySource = fs.readFileSync(
  new URL('../../lib/core/admin/admin_repository.dart', import.meta.url),
  'utf8',
);

test('admin repository exposes a cursor-paginated event reconciliation read API', () => {
  assert.match(adminRepositorySource, /listActiveOutboxEventReconciliationCases/);
  assert.match(adminRepositorySource, /\/admin\/reconciliation-cases\/outbox-events/);
  assert.match(adminRepositorySource, /nextCursor/);
  assert.match(adminRepositorySource, /hasMore/);
});

test('admin operations renders event quarantine independently from unknown payout cards', () => {
  assert.match(screen, /_outboxEventReconciliationCases/);
  assert.match(screen, /_loadMoreOutboxEventCases/);
  assert.match(screen, /listActiveOutboxEventReconciliationCases/);
  assert.match(screen, /Outbox event integrity cases|Outbox event reconciliation|پرونده‌های یکپارچگی رویداد Outbox/);
  assert.match(screen, /_reconciliationCaseCard\([^)]*showResourceLocator:\s*true/);
});

test('event-scoped reconciliation cards identify the Outbox event and observed state', () => {
  assert.match(screen, /showResourceLocator/);
  assert.match(screen, /resourceId/);
  assert.match(screen, /eventType/);
  assert.match(screen, /eventStatus/);
});

test('event reconciliation queue requires current-session READ step-up verification', async () => {
  let listCalls = 0;
  const route = createAdminRoutes({
    authUser:async()=>({
      id:'outbox-read-stepup-admin',
      email:'ops@example.test',
      role:'ADMIN',
      status:'ACTIVE',
      sessionJti:'outbox-read-session',
    }),
    requireAdmin:(candidate)=>{
      if(candidate?.role!=='ADMIN') throw new HttpError(403,'FORBIDDEN','Administrator access required');
      return candidate;
    },
    readBody:async()=>({}),
    sendJson:(_res,status,data)=>({status,data}),
    HttpError,
    URL:globalThis.URL,
    repo:{
      async isAdminPanelVerified(...args) {
        assert.deepEqual(args,['outbox-read-stepup-admin',15,'outbox-read-session','READ']);
        return false;
      },
      async listActiveOutboxEventReconciliationCases() {
        listCalls += 1;
        return [];
      },
    },
    config:{
      adminMfaRequired:true,
      adminPanelReadVerificationMinutes:15,
    },
  });
  await assert.rejects(
    route(
      {method:'GET',url:'/api/v1/admin/reconciliation-cases/outbox-events',headers:{host:'localhost'}},
      {},
      ['admin','reconciliation-cases','outbox-events'],
    ),
    (error)=>error?.status===403 && error?.code==='ADMIN_PANEL_LOCKED',
  );
  assert.equal(listCalls,0);
});

test('invalid event reconciliation cursors return a client error without querying data', async () => {
  const admin = {
    id:'outbox-cursor-admin',
    email:'ops@example.test',
    role:'ADMIN',
    status:'ACTIVE',
    googleSubject:'google-outbox-cursor',
    sessionJti:'outbox-cursor-session',
  };
  const route = createAdminRoutes({
    authUser:async()=>admin,
    requireAdmin:(candidate)=>candidate,
    readBody:async()=>({}),
    sendJson:(_res,status,data)=>({status,data}),
    HttpError,
    URL:globalThis.URL,
    repo:{
      async isAdminPanelVerified() { return true; },
      async listActiveOutboxEventReconciliationCases() {
        const error=new Error('INVALID_RECONCILIATION_CURSOR');
        error.code='INVALID_RECONCILIATION_CURSOR';
        throw error;
      },
    },
    config:{
      adminMfaRequired:true,
      adminPanelReadVerificationMinutes:15,
    },
  });
  await assert.rejects(
    route(
      {method:'GET',url:'/api/v1/admin/reconciliation-cases/outbox-events?cursor=broken',headers:{host:'localhost'}},
      {},
      ['admin','reconciliation-cases','outbox-events'],
    ),
    (error)=>error?.status===400 && error?.code==='INVALID_RECONCILIATION_CURSOR',
  );
});
