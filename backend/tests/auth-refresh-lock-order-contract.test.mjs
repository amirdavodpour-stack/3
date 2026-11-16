import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const authRepository = fs.readFileSync(path.join(root, 'backend/src/repository/auth.js'), 'utf8');
const authRoutes = fs.readFileSync(path.join(root, 'backend/src/routes/auth_routes.js'), 'utf8');

function functionSource(source, name, nextName) {
  const start = source.indexOf(`export async function ${name}(`);
  const end = nextName ? source.indexOf(`export async function ${nextName}(`, start) : source.length;
  assert.ok(start >= 0 && end > start, `${name} implementation must exist`);
  return source.slice(start, end);
}

test('refresh-token rotation locks and validates the owner before locking the token row', () => {
  const rotate = functionSource(authRepository, 'rotateRefreshToken', 'revokeRefreshFamily');
  const userLock = rotate.indexOf('FROM users WHERE id=$1 FOR UPDATE');
  const tokenLock = rotate.indexOf('FROM refresh_tokens WHERE token_hash=$1 AND user_id=$2 FOR UPDATE');

  assert.ok(userLock >= 0, 'rotation must lock the owner account row');
  assert.ok(tokenLock > userLock, 'rotation must lock/re-read the refresh-token row only after the owner row');
  assert.match(rotate, /user\.status\s*!==\s*'ACTIVE'/, 'inactive accounts must not rotate a token');
});

test('logout revokes refresh tokens and increments session version in one user-first transaction', () => {
  const logout = functionSource(authRepository, 'logoutUser', 'bumpUserSessionVersion');
  const userLock = logout.indexOf('FROM users WHERE id=$1 FOR UPDATE');
  const tokenRevoke = logout.indexOf('UPDATE refresh_tokens');
  const versionBump = logout.indexOf('UPDATE users SET session_version=session_version+1');

  assert.match(logout, /withSqlTransaction\(/);
  assert.ok(userLock >= 0 && tokenRevoke > userLock, 'logout must lock the user before revoking refresh rows');
  assert.ok(versionBump > tokenRevoke, 'session version must advance in the same transaction after token revocation');
  assert.match(logout, /admin_panel_verified_at=NULL/);
  assert.match(logout, /admin_panel_verified_session_jti=NULL/);
});

test('PostgreSQL logout route uses the atomic repository operation', () => {
  const start = authRoutes.indexOf("if (req.method === 'POST' && route === 'logout')");
  const end = authRoutes.indexOf("if (req.method === 'POST' && route === 'password-reset/confirm')", start);
  assert.ok(start >= 0 && end > start, 'logout route must exist');
  const logoutRoute = authRoutes.slice(start, end);

  assert.match(logoutRoute, /repo\.logoutUser\(user\.id\)/);
  assert.doesNotMatch(logoutRoute, /repo\.revokeUserRefreshTokens|repo\.bumpUserSessionVersion/);
});
