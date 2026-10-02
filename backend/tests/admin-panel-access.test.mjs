import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyAdminPanelCredentials } from '../src/application/admin_panel_access.js';

test('admin panel credentials require ADMIN role and exact configured username/name', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی' };
  assert.equal(verifyAdminPanelCredentials({ user, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: 'hope-admin' }), true);
  assert.throws(() => verifyAdminPanelCredentials({ user, name: 'مدیر دیگر', username: 'hope-admin', expectedUsername: 'hope-admin' }), /ADMIN_PANEL_CREDENTIALS_INVALID/);
  assert.throws(() => verifyAdminPanelCredentials({ user: { ...user, role: 'USER' }, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: 'hope-admin' }), /ADMIN_PANEL_CREDENTIALS_INVALID/);
});

test('blank or missing configured admin username never unlocks the panel', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی' };
  assert.throws(() => verifyAdminPanelCredentials({ user, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: '' }), /ADMIN_PANEL_CREDENTIALS_INVALID/);
});