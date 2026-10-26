import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const source = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/repository/admin.js'),
  'utf8',
);
const start = source.indexOf('export async function setUserStatus(');
const end = source.indexOf('export async function revokeAdminById(', start);
const implementation = source.slice(start, end);

test('admin status changes atomically revoke refresh tokens as well as access sessions', () => {
  assert.ok(start >= 0 && end > start, 'setUserStatus implementation must exist');
  assert.match(implementation, /withSqlTransaction\(/);
  assert.match(implementation, /session_version\s*=\s*session_version\s*\+\s*1/);
  assert.match(implementation, /UPDATE refresh_tokens SET revoked_at=COALESCE\(revoked_at,NOW\(\)\) WHERE user_id=\$1 AND revoked_at IS NULL/);
});
