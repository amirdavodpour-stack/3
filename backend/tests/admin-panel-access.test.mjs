import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyAdminPanelCredentials } from '../src/application/admin_panel_access.js';

test('admin panel credentials require ADMIN role and exact configured username/name', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی' };
  assert.equal(verifyAdminPanelCredentials({ user: { ...user, email: 'admin@hope.local' }, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: 'hope-admin', expectedEmail: 'admin@hope.local' }), true);
  assert.throws(() => verifyAdminPanelCredentials({ user: { ...user, email: 'admin@hope.local' }, name: 'مدیر دیگر', username: 'hope-admin', expectedUsername: 'hope-admin', expectedEmail: 'admin@hope.local' }), /ADMIN_PANEL_CREDENTIALS_INVALID/);
  assert.throws(() => verifyAdminPanelCredentials({ user: { ...user, role: 'USER', email: 'admin@hope.local' }, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: 'hope-admin', expectedEmail: 'admin@hope.local' }), /ADMIN_PANEL_CREDENTIALS_INVALID/);
  assert.equal(verifyAdminPanelCredentials({ user: { ...user, email: 'other@hope.local' }, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: 'hope-admin' }), true);
});

test('blank or missing configured admin username never unlocks the panel', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی' };
  assert.throws(() => verifyAdminPanelCredentials({ user: { ...user, email: 'admin@hope.local' }, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: '', expectedEmail: 'admin@hope.local' }), /ADMIN_PANEL_CREDENTIALS_INVALID/);
});
test('primary identity controls administrator creation, not general admin panel access', () => {
  const user = { id: 'admin-2', role: 'ADMIN', displayName: 'مدیر دوم', email: 'other@hope.local' };
  assert.equal(verifyAdminPanelCredentials({ user, name: 'مدیر دوم', username: 'hope-admin', expectedUsername: 'hope-admin' }), true);
});
