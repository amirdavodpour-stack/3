import test from 'node:test';
import assert from 'node:assert/strict';
import { isPrimaryAdminEmail, shouldBootstrapPrimaryAdmin } from '../src/application/admin_panel_access.js';

test('the designated primary admin email is recognized case-insensitively', () => {
  assert.equal(isPrimaryAdminEmail('amir.davodpour@gmail.com'), true);
  assert.equal(isPrimaryAdminEmail('AMIR.DAVODPOUR@GMAIL.COM'), true);
  assert.equal(isPrimaryAdminEmail('other@example.com'), false);
});

test('only the designated email bootstraps as ADMIN', () => {
  assert.equal(shouldBootstrapPrimaryAdmin({ email: 'amir.davodpour@gmail.com', verifiedIdentity: true }), true);
  assert.equal(shouldBootstrapPrimaryAdmin({ email: 'amir.davodpour@gmail.com', verifiedIdentity: false }), false);
  assert.equal(shouldBootstrapPrimaryAdmin('other@example.com'), false);
});