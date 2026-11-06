import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const ROOT = new URL('../', import.meta.url);

test('administrator promotion requires target provider identity and stores the grant audit in the same transaction', async () => {
  const repository = await readFile(new URL('src/repository/admin.js', ROOT), 'utf8');
  const legacy = await readFile(new URL('src/application/legacy/admin_legacy.js', ROOT), 'utf8');
  const routes = await readFile(new URL('src/routes/admin_routes.js', ROOT), 'utf8');

  const grantStart = repository.indexOf('export async function grantAdminByEmail(');
  const grantEnd = repository.indexOf('export async function revokeAdminById(', grantStart);
  const grant = repository.slice(grantStart, grantEnd);
  assert.match(grant, /google_subject/);
  assert.match(grant, /ADMIN_PROVIDER_IDENTITY_REQUIRED/);
  assert.match(grant, /status\s*!==\s*'ACTIVE'/);
  assert.match(grant, /ORDER BY id\s+FOR UPDATE/);
  assert.match(grant, /admin_panel_verified_scope=NULL/);
  assert.match(grant, /INSERT INTO audit_logs/);
  assert.match(grant, /ADMIN_ROLE_GRANT/);
  assert.match(legacy, /googleSubject/);
  assert.match(legacy, /ADMIN_PROVIDER_IDENTITY_REQUIRED/);
  assert.match(routes, /if\s*\(!process\.env\.DATABASE_URL\)/);
});
