import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('Flutter exposes verified admin entry and dispute controls', () => {
  const routes = read('lib/core/router/app_routes.dart');
  const home = read('lib/features/home/home_page.dart');
  const repo = read('lib/core/admin/admin_repository.dart');
  const access = read('lib/features/admin/admin_access_page.dart');
  const disputes = read('lib/features/admin/admin_disputes_page.dart');

  assert.match(routes, /adminAccess/);
  assert.match(routes, /adminDisputes/);
  assert.match(home, /HopeRoutes\.adminAccess\(\)/);
  assert.match(repo, /verifyPanelAccess/);
  assert.match(repo, /resolveDispute/);
  assert.match(access, /AdminAccessPage/);
  assert.match(disputes, /RELEASE/);
  assert.match(disputes, /REFUND/);
  assert.match(disputes, /HOLD/);
});