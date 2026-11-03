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

test('primary administrator panel unlock enforces the configured allowed email', () => {
  const route = read('backend/src/routes/admin_routes.js');
  assert.match(
    route,
    /expectedEmail:\s*isPrimaryAdminEmail\(me\.email\)\s*\?\s*config\.adminPanelAllowedEmail\s*:\s*undefined/,
  );
});


test('admin panel unlock requires one recent step-up proof and independent account/IP throttles', () => {
  const route = read('backend/src/routes/admin_routes.js');
  const app = read('backend/src/app.js');
  const googleAuth = read('backend/src/google_auth.js');
  const page = read('lib/features/admin/admin_access_page.dart');
  const repository = read('lib/core/admin/admin_repository.dart');

  assert.match(route, /rateLimitAuth\\(req,\\s*config\\.authRateLimitMax,\\s*config\\.rateLimitWindowMs\\)/);
  assert.match(route, /rateLimitAuthAccount\\(\\s*`admin-panel:\\$\\{me\\.id\\}`\\s*,\\s*config\\.authRateLimitMax,\\s*config\\.rateLimitWindowMs\\)/);
  assert.match(route, /hasPassword\\s*===\\s*hasGoogle/);
  assert.match(route, /verifyPassword\\(password,\\s*me\\.passwordHash\\s*\\|\\|\\s*DUMMY_PASSWORD_HASH\\)/);
  assert.match(route, /verifyGoogleIdToken\\(idToken,\\s*config\\.googleOAuthClientId\\)/);
  assert.match(route, /identity\\.subject\\s*!==\\s*me\\.googleSubject/);
  assert.match(route, /identity\\.email[\\s\\S]*me\\.email/);
  assert.match(route, /identity\\.issuedAt/);
  assert.match(route, /ADMIN_PANEL_UNLOCK[\\s\\S]*method/);
  assert.match(app, /verifyPassword,\\s*verifyGoogleIdToken,\\s*rateLimitAuth,\\s*rateLimitAuthAccount,\\s*DUMMY_PASSWORD_HASH/);
  assert.match(googleAuth, /issuedAt:\\s*Number\\(payload\\.iat\\)/);
  assert.match(page, /obscureText:\\s*true/);
  assert.match(page, /GoogleSignInService/);
  assert.match(page, /\\.authenticate\\(\\)/);
  assert.match(repository, /verifyPanelAccess\\(String name, String username,\\s*\\{String\\? password, String\\? idToken\\}\\)/);
});
