import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('dispute persistence exposes create, list, read and resolve operations', () => {
  const repo = read('backend/src/repository/disputes.js');
  assert.match(repo, /createJobDispute/);
  assert.match(repo, /listAdminDisputes/);
  assert.match(repo, /getAdminDispute/);
  assert.match(repo, /getJobDisputeContext/);
  assert.match(repo, /updateJobDisputeAnalysis/);
  assert.match(repo, /resolveJobDispute/);
});

test('job routes expose user-triggered dispute and satisfaction conflict can invoke the analyzer', () => {
  const routes = read('backend/src/routes/job_dispute_routes.js');
  assert.match(routes, /POST/);
  assert.match(routes, /dispute/);
  const satisfaction = read('backend/src/routes/job_satisfaction_routes.js');
  assert.match(satisfaction, /analyzeDisputeWithAI/);
});

test('admin routes expose dispute report and explicit financial resolution', () => {
  const routes = read('backend/src/routes/admin_routes.js');
  assert.match(routes, /admin.*disputes/);
  assert.match(routes, /RELEASE/);
  assert.match(routes, /REFUND/);
  assert.match(routes, /resolveJobDispute/);
});
test('admin dispute decisions claim a fenced resolution before financial side effects and HOLD cancels pending release', () => {
  const route = read('backend/src/routes/job_dispute_routes.js');
  const claim = route.indexOf('repo.claimJobDisputeResolution');
  const financialAction = route.indexOf('await resolvePayment(dispute,resolution,me.id,reason)');
  const finalize = route.indexOf('repo.completeJobDisputeResolution');
  assert.ok(claim >= 0 && financialAction > claim,
    'the durable one-winner claim must commit before release/refund/HOLD side effects');
  assert.ok(finalize > financialAction,
    'the dispute may become RESOLVED only after its financial action is confirmed');
  assert.match(route, /repo\.holdPaymentForDispute/);
  assert.match(route, /DISPUTE_RESOLUTION_IN_PROGRESS/);
  assert.match(route, /existing\?\.status==='RESOLVING'/);
  assert.match(route, /repo\.abandonJobDisputeResolutionClaim/);
});


test('participants can open disputes during active work as well as after completion', () => {
  const routes = read('backend/src/routes/job_dispute_routes.js');
  assert.match(routes, /DISPUTABLE_JOB_STATUSES/);
  for (const status of ['IN_PROGRESS','DELIVERED','UNDER_REVIEW','COMPLETED']) {
    assert.match(routes, new RegExp(status));
  }
});


test('opening a dispute holds payment before creating the case and blocks later release', () => {
  const route = read('backend/src/routes/job_dispute_routes.js');
  const hold = route.indexOf('const held=await repo.holdPaymentForDispute');
  const create = route.indexOf('repo.createJobDispute', hold);
  assert.ok(hold >= 0 && create > hold,
    'the payment must be held before a new dispute is persisted');
  assert.match(route, /DISPUTE_PAYMENT_ALREADY_SETTLED/);
  assert.match(route, /PAYMENT_RELEASE_IN_PROGRESS/);

  const payments = read('backend/src/routes/payment_routes.js');
  assert.match(payments, /JOB_DISPUTE_OPEN/);
  const satisfaction = read('backend/src/routes/job_satisfaction_routes.js');
  assert.match(satisfaction, /existingDispute && existingDispute.status !== 'RESOLVED'/);

  const outbox = read('backend/src/repository/outbox.js');
  assert.match(outbox, /DISPUTE_RELEASE_CLAIM_REQUIRED/);
  const disputes = read('backend/src/repository/disputes.js');
  assert.match(disputes, /CASE WHEN \$2='HOLD' THEN 'ADMIN_REVIEW' ELSE 'RESOLVED' END/);
});
