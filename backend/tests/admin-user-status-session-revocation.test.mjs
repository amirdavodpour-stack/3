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
const coreRepositorySource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/repository/core.js'),
  'utf8',
);
const legacyAdminRepositorySource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/application/legacy/admin_legacy.js'),
  'utf8',
);
const legacyAccountRepositorySource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/application/legacy/account_legacy.js'),
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

test('admin role revocation clears every step-up field and commits its audit atomically', () => {
  const revoke = functionSource(adminRepositorySource, 'revokeAdminById', 'revokeUserSessions');
  assert.match(revoke, /actor\.status\s*!==\s*'ACTIVE'/);
  assert.match(revoke, /ORDER BY id\s+FOR UPDATE/);
  assert.match(revoke, /admin_panel_verified_at\s*=\s*NULL/);
  assert.match(revoke, /admin_panel_verified_session_jti\s*=\s*NULL/);
  assert.match(revoke, /admin_panel_verified_scope\s*=\s*NULL/);
  assert.match(revoke, /UPDATE refresh_tokens/);
  assert.match(revoke, /INSERT INTO audit_logs/);
  assert.match(revoke, /ADMIN_ROLE_REVOKE/);
  assert.match(revoke, /withSqlTransaction/);
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
      /UPDATE users[\s\S]*?admin_panel_verified_at\s*=\s*NULL/is,
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
  assert.match(reuseBranch, /INSERT INTO audit_logs/i,
    'reuse detection must persist a durable audit event in the transaction');
  assert.match(reuseBranch, /AUTH_REFRESH_REUSE_DETECTED/);
  assert.match(reuseBranch, /tokenFamilyId/);
  assert.doesNotMatch(reuseBranch, /oldHash|tokenHash|nextToken/,
    'the durable audit payload must not include raw refresh-token material');
});



test('linking a Google identity clears prior admin-panel verification', () => {
  const link = functionSource(coreRepositorySource, 'linkGoogleSubject', 'findUserById');
  assert.match(
    link,
    /UPDATE users SET[^\`]*google_subject\s*=\s*\$2[^\`]*admin_panel_verified_at\s*=\s*NULL[^\`]*WHERE id=\$1/is,
  );
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

test('deleted account tombstones are terminal and lose administrator privileges', () => {
  const statusChange = functionSource(adminRepositorySource, 'setUserStatus', 'revokeAdminById');
  const deletion = privacyRepositorySource.slice(
    privacyRepositorySource.indexOf('export async function deleteUserPrivacyBundle('),
  );
  const legacyStatusStart = legacyAdminRepositorySource.indexOf('setUserStatus(id, status');
  const legacyStatusEnd = legacyAdminRepositorySource.indexOf('revokeAdminById(id, actorId)', legacyStatusStart);
  const legacyStatusChange = legacyAdminRepositorySource.slice(legacyStatusStart, legacyStatusEnd);
  const legacyDeletion = legacyAccountRepositorySource.slice(
    legacyAccountRepositorySource.indexOf('async deleteUserPrivacyBundle'),
  );

  assert.match(statusChange, /status\s*===\s*'DELETED'/,
    'PostgreSQL status changes must reject deleted account tombstones');
  assert.match(adminRoutesSource, /target\.status\s*===\s*'DELETED'/,
    'the admin API must reject reactivation before attempting a status update');
  assert.match(deletion, /role\s*=\s*'USER'/,
    'PostgreSQL deletion must strip any administrator role from the tombstone');
  assert.match(legacyStatusChange, /status\s*===\s*'DELETED'/,
    'legacy status changes must reject deleted account tombstones');
  assert.match(legacyDeletion, /role:\s*'USER'/,
    'legacy deletion must strip any administrator role from the tombstone');
});

test('admin-panel verification can only be set or read for active administrator accounts', () => {
  const setVerification = functionSource(disputeRepositorySource, 'setAdminPanelVerified', 'isAdminPanelVerified');
  const readVerification = functionSource(disputeRepositorySource, 'isAdminPanelVerified', 'clearAdminPanelVerification');

  assert.match(setVerification, /role\s*=\s*'ADMIN'\s+AND\s+status\s*=\s*'ACTIVE'/i);
  assert.match(readVerification, /SELECT[^\`]*role[^\`]*status[^\`]*admin_panel_verified_at/is);
  assert.match(readVerification, /row\?\.status\s*===\s*'ACTIVE'/);
});



import { createSessionService } from '../src/services/session.js';
import { signAccessToken, verifyAccessToken } from '../src/security.js';

const sessionServiceSource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/services/session.js'),
  'utf8',
);
const adminRoutesSource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/routes/admin_routes.js'),
  'utf8',
);
const disputeRoutesSource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/routes/job_dispute_routes.js'),
  'utf8',
);
const analyticsRoutesSource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/routes/analytics_routes.js'),
  'utf8',
);
const humanChatRoutesSource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/routes/human_chat_routes.js'),
  'utf8',
);
const walletRoutesSource = fs.readFileSync(
  path.resolve(import.meta.dirname, '../src/application/wallet_routes.js'),
  'utf8',
);

test('authUser binds a non-enumerable session JTI to each validated access-token user', async () => {
  const secret = 'session-jti-contract-secret-with-enough-entropy';
  const user = {
    id: 'admin-session-jti',
    role: 'ADMIN',
    status: 'ACTIVE',
    sessionVersion: 4,
    email: 'admin-session-jti@example.test',
  };
  const config = {
    accessSecret: secret,
    accessIssuer: 'hope-api',
    accessAudience: 'hope-mobile',
  };
  const service = createSessionService({
    config,
    repo: {},
    legacy: { findUserById: async () => ({ ...user }) },
    logEvent: () => {},
    now: () => new Date().toISOString(),
  });
  const firstToken = signAccessToken({ sub: user.id, sv: 4 }, secret, 300, {
    issuer: config.accessIssuer,
    audience: config.accessAudience,
  });
  const secondToken = signAccessToken({ sub: user.id, sv: 4 }, secret, 300, {
    issuer: config.accessIssuer,
    audience: config.accessAudience,
  });
  const firstPayload = verifyAccessToken(firstToken, secret, {
    issuer: config.accessIssuer,
    audience: config.accessAudience,
  });
  const secondPayload = verifyAccessToken(secondToken, secret, {
    issuer: config.accessIssuer,
    audience: config.accessAudience,
  });

  const firstUser = await service.authUser({ headers: { authorization: `Bearer ${firstToken}` } });
  const secondUser = await service.authUser({ headers: { authorization: `Bearer ${secondToken}` } });

  assert.equal(firstUser.sessionJti, firstPayload.jti);
  assert.equal(secondUser.sessionJti, secondPayload.jti);
  assert.notEqual(firstUser.sessionJti, secondUser.sessionJti);
  assert.equal(Object.keys(firstUser).includes('sessionJti'), false);
  assert.equal(JSON.stringify(firstUser).includes(firstPayload.jti), false);
});

test('admin-panel repository persists and checks the exact bound session JTI', () => {
  const setVerification = functionSource(disputeRepositorySource, 'setAdminPanelVerified', 'isAdminPanelVerified');
  const readVerification = functionSource(disputeRepositorySource, 'isAdminPanelVerified', 'clearAdminPanelVerification');
  const clearVerification = functionSource(disputeRepositorySource, 'clearAdminPanelVerification');
  const migration = fs.readFileSync(
    path.resolve(import.meta.dirname, '../src/db/migrations/041_admin_panel_session_binding.js'),
    'utf8',
  );

  assert.match(setVerification, /admin_panel_verified_session_jti/);
  assert.match(setVerification, /sessionJti/);
  assert.match(readVerification, /admin_panel_verified_session_jti/);
  assert.match(readVerification, /sessionJti/);
  assert.match(clearVerification, /admin_panel_verified_session_jti\s*=\s*NULL/);
  assert.match(migration, /ADD COLUMN IF NOT EXISTS admin_panel_verified_session_jti TEXT/);
  assert.match(migration, /DROP COLUMN IF EXISTS admin_panel_verified_session_jti/);
});

test('every protected admin route supplies the authenticated session JTI to the verification guard', () => {
  assert.match(adminRoutesSource, /repo\.isAdminPanelVerified\(me\.id,\s*config\.adminPanelVerificationMinutes,\s*me\.sessionJti\)/);
  assert.match(disputeRoutesSource, /repo\.isAdminPanelVerified\(me\.id,\s*config\?\.adminPanelVerificationMinutes\s*\?\?\s*15,\s*me\.sessionJti\)/);
  assert.match(analyticsRoutesSource, /repo\.isAdminPanelVerified\(me\.id,\s*config\?\.adminPanelVerificationMinutes\s*\?\?\s*15,\s*me\.sessionJti\)/);
  assert.match(humanChatRoutesSource, /repo\.isAdminPanelVerified\(admin\.id,\s*config\?\.adminPanelVerificationMinutes\s*\?\?\s*15,\s*admin\.sessionJti\)/);
  assert.match(walletRoutesSource, /walletRepo\.isAdminPanelVerified\(me\.id,\s*config\?\.adminPanelVerificationMinutes\s*\?\?\s*15,\s*me\.sessionJti\)/);
});

test('legacy admin-panel verification is bound to the active session JTI', () => {
  assert.match(adminRoutesSource, /sessionJti/);
  assert.match(adminRoutesSource, /legacyVerifiedAdmins\.set\(me\.id,\s*\{[^}]*sessionJti/);
  assert.match(adminRoutesSource, /legacyVerifiedAdmins\.get\(userId\)[\s\S]*verification\.sessionJti\s*===\s*sessionJti/);
});
