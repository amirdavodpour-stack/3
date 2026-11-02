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
  assert.match(satisfaction, /openJobDisputeWithHold/);
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
test('admin dispute gate honors the configured Admin Panel verification duration', () => {
  const app = read('backend/src/app.js');
  const route = read('backend/src/routes/job_dispute_routes.js');
  assert.match(app, /createJobDisputeRoutes\(\{[^\n]*config/);
  assert.match(route, /repo\.isAdminPanelVerified\(me\.id,\s*config\?\.adminPanelVerificationMinutes\s*\?\?\s*15\)/);
  assert.doesNotMatch(route, /repo\.isAdminPanelVerified\(me\.id,\s*15\)/);
});

test('admin dispute endpoint delegates to the claim-fenced dispute route', async () => {
  const { createAdminRoutes } = await import('../src/routes/admin_routes.js');
  const admin = {
    id: 'admin-1',
    role: 'ADMIN',
    email: 'amir.davodpour@gmail.com',
    googleSubject: 'verified-google-subject',
    displayName: 'Primary Admin',
    sessionVersion: 1,
  };
  const delegatedCalls = [];
  const route = createAdminRoutes({
    authUser: async () => admin,
    requireAdmin: (user) => user,
    readBody: async (req) => req.url.endsWith('/access')
      ? { name: 'Primary Admin', username: 'admin-panel-secret' }
      : { resolution: 'HOLD', reason: 'keep case open' },
    sendJson: (_res, status, body) => ({ status, body }),
    HttpError: class HttpError extends Error {
      constructor(status, code, message) { super(message); this.status = status; this.code = code; }
    },
    repo: {
      isAdminPanelVerified: async () => true,
      setAdminPanelVerified: async () => true,
      getAdminDispute: async () => { throw new Error('legacy dispute resolver was reached'); },
    },
    config: { adminPanelUsername: 'admin-panel-secret', adminPanelVerificationMinutes: 15 },
    createAudit: async () => {},
    jobDisputeRoutes: async (_req, _res, parts) => {
      delegatedCalls.push(parts.join('/'));
      return { delegated: true };
    },
  });

  await route(
    { method: 'POST', url: '/api/v1/admin/access', headers: {} },
    {},
    ['admin', 'access'],
  );
  const response = await route(
    { method: 'POST', url: '/api/v1/admin/disputes/dispute-1', headers: {} },
    {},
    ['admin', 'disputes', 'dispute-1'],
  );

  assert.deepEqual(delegatedCalls, ['admin/disputes/dispute-1']);
  assert.deepEqual(response, { delegated: true });
});
