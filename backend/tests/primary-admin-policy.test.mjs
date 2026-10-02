import test from 'node:test';
import assert from 'node:assert/strict';
import { isPrimaryAdmin, assertPrimaryAdmin } from '../src/application/admin_panel_access.js';

test('only the canonical owner email is the primary administrator', () => {
  assert.equal(isPrimaryAdmin({ role: 'ADMIN', email: 'amir.davodpour@gmail.com' }), true);
  assert.equal(isPrimaryAdmin({ role: 'ADMIN', email: 'AMIR.DAVODPOUR@GMAIL.COM' }), true);
  assert.equal(isPrimaryAdmin({ role: 'ADMIN', email: 'other@example.com' }), false);
  assert.equal(isPrimaryAdmin({ role: 'USER', email: 'amir.davodpour@gmail.com' }), false);
});

test('only the primary administrator may grant ADMIN role', () => {
  assert.equal(assertPrimaryAdmin({ role: 'ADMIN', email: 'amir.davodpour@gmail.com' }), true);
  assert.throws(() => assertPrimaryAdmin({ role: 'ADMIN', email: 'other@example.com' }), /PRIMARY_ADMIN_ONLY/);
  assert.throws(() => assertPrimaryAdmin({ role: 'USER', email: 'amir.davodpour@gmail.com' }), /PRIMARY_ADMIN_ONLY/);
});