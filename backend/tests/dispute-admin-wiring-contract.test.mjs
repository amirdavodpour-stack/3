import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('dispute route is wired and satisfaction conflicts auto-open adjudication', () => {
  const app = read('backend/src/app.js');
  const satisfaction = read('backend/src/routes/job_satisfaction_routes.js');
  const route = read('backend/src/routes/job_dispute_routes.js');

  assert.match(app, /createJobDisputeRoutes/);
  assert.match(app, /parts\[2\] === 'dispute'/);
  assert.match(satisfaction, /SATISFACTION_CONFLICT/);
  assert.match(satisfaction, /createJobDispute/);
  assert.match(satisfaction, /analyzeDisputeWithAI/);
  assert.match(route, /PAYMENT_RELEASE:ADMIN_DISPUTE/);
  assert.match(route, /DISPUTE_REFUND/);
});

test('admin dispute operations must remain behind the verified admin panel', () => {
  const admin = read('backend/src/routes/admin_routes.js');
  assert.match(admin, /ADMIN_PANEL_LOCKED/);
  assert.match(admin, /disputes/);
  assert.match(admin, /ADMIN_DISPUTE_RESOLVE/);
});
test('admin panel exposes a verification state endpoint and UI checks it before loading admin data', () => {
  const route = read('backend/src/routes/admin_routes.js');
  const repo = read('lib/core/admin/admin_repository.dart');
  const page = read('lib/features/admin/admin_page.dart');
  assert.match(route, /parts\[1\]==='access'.*req\.method==='GET'|req\.method==='GET'.*parts\[1\]==='access'/s);
  assert.match(repo, /getPanelAccess/);
  assert.match(page, /_checkPanelAccess|checkingPanel|verified/);
});