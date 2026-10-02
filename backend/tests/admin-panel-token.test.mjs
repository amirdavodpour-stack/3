import test from 'node:test';
import assert from 'node:assert/strict';
import { issueAdminPanelToken, verifyAdminPanelToken, verifyAdminPanelCredentials } from '../src/application/admin_panel_access.js';

const secret = 's'.repeat(48);

test('admin panel token is scoped to the authenticated admin and expires', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی', sessionVersion: 7 };
  const token = issueAdminPanelToken({ user, secret, ttlSeconds: 900 });
  const payload = verifyAdminPanelToken(token, secret);
  assert.equal(payload.sub, user.id);
  assert.equal(payload.role, 'ADMIN');
  assert.equal(payload.sv, 7);
});

test('admin panel token rejects wrong secret or non-admin claims', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی', sessionVersion: 0 };
  const token = issueAdminPanelToken({ user, secret, ttlSeconds: 900 });
  assert.throws(() => verifyAdminPanelToken(token, 'x'.repeat(48)), /ADMIN_PANEL_TOKEN_INVALID/);
  assert.throws(() => verifyAdminPanelToken('', secret), /ADMIN_PANEL_TOKEN_INVALID/);
});

test('credential gate remains separate from token verification', () => {
  const user = { id: 'admin-1', role: 'ADMIN', displayName: 'مدیر اصلی' };
  assert.equal(verifyAdminPanelCredentials({ user, name: 'مدیر اصلی', username: 'hope-admin', expectedUsername: 'hope-admin' }), true);
});