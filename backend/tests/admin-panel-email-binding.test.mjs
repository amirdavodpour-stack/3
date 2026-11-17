import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyAdminPanelCredentials } from '../src/application/admin_panel_access.js';

test('admin panel access can bind username verification to the configured admin email', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی', email: 'admin@example.com' };
  assert.equal(verifyAdminPanelCredentials({
    user,
    name: 'مدیر اصلی',
    username: 'hope-admin',
    expectedUsername: 'hope-admin',
    expectedEmail: 'admin@example.com',
  }), true);
  assert.throws(() => verifyAdminPanelCredentials({
    user: { ...user, email: 'other@example.com' },
    name: 'مدیر اصلی',
    username: 'hope-admin',
    expectedUsername: 'hope-admin',
    expectedEmail: 'admin@example.com',
  }), /ADMIN_PANEL_CREDENTIALS_INVALID/);
});