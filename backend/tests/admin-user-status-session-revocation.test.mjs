import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const source = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/repository/admin.js'),
  'utf8',
);
const adminRepositorySource = source;
const start = source.indexOf('export async function setUserStatus(');
const end = source.indexOf('export async function revokeAdminById(', start);
const implementation = source.slice(start, end);

test('admin status changes atomically revoke refresh tokens as well as access sessions', () => {
  assert.ok(start >= 0 && end > start, 'setUserStatus implementation must exist');
  assert.match(implementation, /withSqlTransaction\(/);
  assert.match(implementation, /session_version\s*=\s*session_version\s*\+\s*1/);
  assert.match(implementation, /UPDATE refresh_tokens SET revoked_at=COALESCE\(revoked_at,NOW\(\)\) WHERE user_id=\$1 AND revoked_at IS NULL/);
});

const authRepositorySource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/repository/auth.js'),
  'utf8',
);
const privacyRepositorySource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/repository/privacy.js'),
  'utf8',
);
const disputeRepositorySource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/repository/disputes.js'),
  'utf8',
);

function functionSource(source, name, nextName) {
  const start = source.indexOf(`export async function ${name}(`);
  const end = nextName
    ? source.indexOf(`export async function ${nextName}(`, start)
    : source.length;
  assert.ok(start >= 0 && end > start, `${name} implementation must exist`);
  return source.slice(start, end);
}

test('logout and password reset clear admin-panel verification in the session-version transaction', () => {
  const logoutInvalidation = functionSource(
    authRepositorySource,
    'bumpUserSessionVersion',
    'revokeUserRefreshTokens',
  );
  const passwordResetInvalidation = functionSource(
    authRepositorySource,
    'consumeResetTokenAndChangePassword',
    'findProviderByUserId',
  );

  assert.match(logoutInvalidation, /UPDATE users SET[^\`]*session_version\s*=\s*session_version\s*\+\s*1[^\`]*admin_panel_verified_at\s*=\s*NULL/is);
  assert.match(passwordResetInvalidation, /UPDATE users SET[^\`]*password_hash\s*=\s*\$2[^\`]*session_version\s*=\s*session_version\s*\+\s*1[^\`]*admin_panel_verified_at\s*=\s*NULL/is);
});

test('admin session revocation, status changes and role changes clear prior panel unlocks', () => {
  const statusChange = functionSource(adminRepositorySource, 'setUserStatus', 'revokeAdminById');
  const roleRevocation = functionSource(adminRepositorySource, 'revokeAdminById', 'revokeUserSessions');
  const sessionRevocation = functionSource(adminRepositorySource, 'revokeUserSessions', 'listAdminAudit');
  const roleGrant = functionSource(adminRepositorySource, 'grantAdminByEmail');

  for (const [name, implementation] of [
    ['setUserStatus', statusChange],
    ['revokeAdminById', roleRevocation],
    ['revokeUserSessions', sessionRevocation],
    ['grantAdminByEmail', roleGrant],
  ]) {
    assert.match(
      implementation,
      /UPDATE users SET[^\`]*admin_panel_verified_at\s*=\s*NULL/is,
      `${name} must invalidate a previous admin-panel verification`,
    );
  }
});


test('refresh-token reuse invalidates access sessions and admin-panel verification', () => {
  const rotate = functionSource(authRepositorySource, 'rotateRefreshToken', 'revokeRefreshFamily');
  const reuseStart = rotate.indexOf('if(r.revoked_at)');
  const reuseEnd = rotate.indexOf("if(new Date(r.expires_at)", reuseStart);
  assert.ok(reuseStart >= 0 && reuseEnd > reuseStart, 'refresh reuse branch must exist');
  const reuseBranch = rotate.slice(reuseStart, reuseEnd);
  assert.match(
    reuseBranch,
    /UPDATE users SET[^\`]*session_version\s*=\s*session_version\s*\+\s*1[^\`]*admin_panel_verified_at\s*=\s*NULL[^\`]*WHERE id=\$1/is,
  );
  assert.match(reuseBranch, /r\.user_id/,
    'reuse invalidation must target the account owning the compromised token');
});


test('account deletion clears admin-panel verification with the privacy tombstone', () => {
  const deletion = privacyRepositorySource.slice(
    privacyRepositorySource.indexOf('export async function deleteUserPrivacyBundle('),
  );
  assert.match(
    deletion,
    /UPDATE users SET[^\`]*admin_panel_verified_at\s*=\s*NULL[^\`]*status\s*=\s*'DELETED'/is,
  );
});

test('admin-panel verification can only be set or read for active administrator accounts', () => {
  const setVerification = functionSource(disputeRepositorySource, 'setAdminPanelVerified', 'isAdminPanelVerified');
  const readVerification = functionSource(disputeRepositorySource, 'isAdminPanelVerified', 'clearAdminPanelVerification');

  assert.match(setVerification, /role\s*=\s*'ADMIN'\s+AND\s+status\s*=\s*'ACTIVE'/i);
  assert.match(readVerification, /SELECT[^\`]*role[^\`]*status[^\`]*admin_panel_verified_at/is);
  assert.match(readVerification, /rows\[0\]\?\.status\s*===\s*'ACTIVE'/);
});

