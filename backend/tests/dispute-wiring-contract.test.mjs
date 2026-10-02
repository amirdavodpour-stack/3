import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('dispute persistence exposes create, list, read and resolve operations', () => {
  const repo = read('backend/src/repository/job_disputes.js');
  assert.match(repo, /createJobDispute/);
  assert.match(repo, /listAdminDisputes/);
  assert.match(repo, /getAdminDispute/);
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