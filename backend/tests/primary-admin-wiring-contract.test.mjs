import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('admin promotion endpoint is primary-owner-only and audit logged', () => {
  const route = read('backend/src/routes/admin_routes.js');
  const useCases = read('backend/src/application/use_cases/admin_use_cases.js');
  const ports = read('backend/src/application/ports/repository_ports.js');
  const repo = read('backend/src/repository/admin.js');
  assert.match(route, /parts\[1\]==='admins'/);
  assert.match(route, /assertPrimaryAdmin\(me\)/);
  assert.match(route, /grantAdminByEmail\(email, me\.id\)/);
  assert.match(route, /ADMIN_ROLE_GRANT/);
  assert.match(useCases, /grantAdminByEmail/);
  assert.match(ports, /grantAdminByEmail/);
  assert.match(repo, /PRIMARY_ADMIN_ONLY/);
});
test('primary-admin privileges require a linked verified Google identity at every authorization layer', () => {
  const access = read('backend/src/application/admin_panel_access.js');
  const validation = read('backend/src/policies/validation.js');
  const auth = read('backend/src/routes/auth_routes.js');
  const repo = read('backend/src/repository/admin.js');
  const legacy = read('backend/src/application/legacy/admin_legacy.js');

  assert.match(access, /shouldBootstrapPrimaryAdmin\(\{ email, verifiedIdentity = false, googleSubject \}/);
  assert.match(access, /Boolean\(normalize\(googleSubject\)\)/);
  assert.match(access, /isPrimaryAdminEmail\(user\.email\) && Boolean\(normalize\(user\.googleSubject\)\)/);
  assert.match(access, /isPrimaryAdminEmail\(user\.email\) && !normalize\(user\.googleSubject\)/);
  assert.match(validation, /PRIMARY_ADMIN_IDENTITY_REQUIRED/);
  assert.match(validation, /isPrimaryAdminEmail\(user\.email\) && !String\(user\.googleSubject \|\| ''\)\.trim\(\)/);
  assert.match(auth, /shouldBootstrapPrimaryAdmin\(\{ email: identity\.email, verifiedIdentity: true, googleSubject: identity\.subject \}\)/);
  assert.match(repo, /SELECT id,email,role,google_subject FROM users WHERE id=\$1 FOR UPDATE/);
  assert.equal((repo.match(/!String\(actors\[0\]\.google_subject \|\| ''\)\.trim\(\)/g) || []).length, 2);
  assert.equal((legacy.match(/!String\(actor\.googleSubject \|\| ''\)\.trim\(\)/g) || []).length, 2);
});
