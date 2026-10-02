import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ADMIN_PERMISSIONS,
  assertAdminPermission,
  getAdminPermissions,
} from '../src/application/admin_panel_access.js';

const owner = { id: 'owner-1', role: 'ADMIN', email: 'amir.davodpour@gmail.com' };
const admin = { id: 'admin-1', role: 'ADMIN', email: 'ops@example.com' };
const user = { id: 'user-1', role: 'USER', email: 'user@example.com' };

test('primary owner receives the full administrative permission set', () => {
  const permissions = getAdminPermissions(owner);
  for (const permission of Object.values(ADMIN_PERMISSIONS)) {
    assert.equal(permissions.includes(permission), true, permission);
  }
});

test('standard administrators receive operational permissions but not governance or money-movement controls', () => {
  const permissions = getAdminPermissions(admin);
  for (const permission of [
    ADMIN_PERMISSIONS.VIEW_ADMIN_CENTER,
    ADMIN_PERMISSIONS.MANAGE_USERS,
    ADMIN_PERMISSIONS.MODERATE_JOBS,
    ADMIN_PERMISSIONS.MANAGE_APPLICATIONS,
    ADMIN_PERMISSIONS.TRUST_SAFETY,
    ADMIN_PERMISSIONS.VIEW_FINANCE,
    ADMIN_PERMISSIONS.VIEW_PAYOUTS,
    ADMIN_PERMISSIONS.VIEW_AUDIT,
  ]) {
    assert.equal(permissions.includes(permission), true, permission);
  }
  for (const permission of [
    ADMIN_PERMISSIONS.MANAGE_ADMINS,
    ADMIN_PERMISSIONS.DELETE_JOBS,
    ADMIN_PERMISSIONS.RESOLVE_DISPUTES,
    ADMIN_PERMISSIONS.RESOLVE_PAYOUTS,
    ADMIN_PERMISSIONS.REVOKE_SESSIONS,
  ]) {
    assert.equal(permissions.includes(permission), false, permission);
  }
});

test('non-admin users receive no admin permissions', () => {
  assert.deepEqual(getAdminPermissions(user), []);
});

test('permission guard rejects a standard admin at protected owner-only boundaries', () => {
  assert.equal(assertAdminPermission(owner, ADMIN_PERMISSIONS.MANAGE_ADMINS), true);
  assert.throws(
    () => assertAdminPermission(admin, ADMIN_PERMISSIONS.MANAGE_ADMINS),
    /ADMIN_PERMISSION_DENIED/,
  );
  assert.throws(
    () => assertAdminPermission(user, ADMIN_PERMISSIONS.VIEW_ADMIN_CENTER),
    /ADMIN_PERMISSION_DENIED/,
  );
});
