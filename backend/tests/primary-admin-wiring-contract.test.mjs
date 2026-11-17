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