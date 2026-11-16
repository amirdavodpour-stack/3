import test from 'node:test';
import assert from 'node:assert/strict';
import {
  ADMIN_PERMISSIONS,
  assertAdminPermission,
  assertPrimaryAdmin,
  getAdminPermissions,
  isPrimaryAdmin,
} from '../src/application/admin_panel_access.js';
import { requireAdmin } from '../src/policies/validation.js';
import { createPaymentRoutes } from '../src/routes/payment_routes.js';
import { HttpError } from '../src/api/http_error.js';

const owner = { id: 'owner-1', role: 'ADMIN', email: 'amir.davodpour@gmail.com', googleSubject: 'verified-google-subject' };
const unlinkedOwner = { id: 'owner-unlinked', role: 'ADMIN', email: 'amir.davodpour@gmail.com' };
const admin = { id: 'admin-1', role: 'ADMIN', email: 'ops@example.com' };
const user = { id: 'user-1', role: 'USER', email: 'user@example.com' };

test('primary-owner privileges require a linked verified Google subject in addition to role and email', () => {
  assert.equal(isPrimaryAdmin(owner), true);
  assert.equal(isPrimaryAdmin({ ...owner, email: 'AMIR.DAVODPOUR@GMAIL.COM' }), true);
  assert.equal(isPrimaryAdmin(unlinkedOwner), false);
  assert.equal(isPrimaryAdmin({ role: 'ADMIN', email: 'other@example.com', googleSubject: 'subject' }), false);
  assert.equal(isPrimaryAdmin({ role: 'USER', email: 'amir.davodpour@gmail.com', googleSubject: 'subject' }), false);
});

test('unlinked canonical owner receives no admin permissions and is rejected at the admin boundary', () => {
  assert.deepEqual(getAdminPermissions(unlinkedOwner), []);
  assert.throws(
    () => requireAdmin(unlinkedOwner),
    (error) => error?.status === 403 && error?.code === 'PRIMARY_ADMIN_IDENTITY_REQUIRED',
  );
  assert.equal(requireAdmin(owner), owner);
});

test('only a linked primary administrator may grant ADMIN role', () => {
  assert.equal(assertPrimaryAdmin(owner), true);
  assert.throws(() => assertPrimaryAdmin(unlinkedOwner), /PRIMARY_ADMIN_ONLY/);
  assert.throws(() => assertPrimaryAdmin(admin), /PRIMARY_ADMIN_ONLY/);
  assert.throws(() => assertPrimaryAdmin(user), /PRIMARY_ADMIN_ONLY/);
});

test('primary owner receives the full administrative permission set only after identity linkage', () => {
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
    ADMIN_PERMISSIONS.SANDBOX_WALLET_CREDIT,
  ]) {
    assert.equal(permissions.includes(permission), false, permission);
  }
});

test('non-admin users receive no admin permissions', () => {
  assert.deepEqual(getAdminPermissions(user), []);
});

test('permission guard rejects a standard admin at protected owner-only boundaries', () => {
  assert.equal(assertAdminPermission(owner, ADMIN_PERMISSIONS.MANAGE_ADMINS), true);
  assert.throws(() => assertAdminPermission(admin, ADMIN_PERMISSIONS.MANAGE_ADMINS), /ADMIN_PERMISSION_DENIED/);
  assert.throws(() => assertAdminPermission(unlinkedOwner, ADMIN_PERMISSIONS.MANAGE_ADMINS), /ADMIN_PERMISSION_DENIED/);
  assert.throws(() => assertAdminPermission(user, ADMIN_PERMISSIONS.VIEW_ADMIN_CENTER), /ADMIN_PERMISSION_DENIED/);
});


const foreignJob = { id: 'foreign-job', ownerId: 'another-owner', providerId: 'another-worker', title: 'Private financial record' };
const foreignPayment = { id: 'foreign-payment', status: 'HELD', amount: '900', providerRef: 'private-provider-ref' };

function makeForeignFinancialsRoute(user, { postgres = false, panelVerified = false } = {}) {
  return createPaymentRoutes({
    authUser: async () => user,
    sendJson: (_res, status, data) => ({ status, data }),
    HttpError,
    config: { paymentWebhookSecret: '', adminPanelVerificationMinutes: 15 },
    repo: {
      isAdminPanelVerified: async () => panelVerified,
      listLedgerEntriesForPayment: async () => [{ id: 'private-ledger-entry' }],
    },
    getJob: async () => foreignJob,
    paymentView: async (payment, job) => ({ paymentId: payment?.id ?? null, jobId: job.id }),
    relatedJob: (userId, job) => job.ownerId === userId || job.providerId === userId,
    paymentUseCases: { findByJob: async () => foreignPayment },
    paymentLegacy: {
      findByJob: () => foreignPayment,
      listLedgerEntries: () => [{ id: 'private-ledger-entry' }],
    },
  });
}

async function withDatabaseUrl(value, callback) {
  const previous = process.env.DATABASE_URL;
  if (value == null) delete process.env.DATABASE_URL;
  else process.env.DATABASE_URL = value;
  try { return await callback(); }
  finally {
    if (previous === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = previous;
  }
}

test('financial detail route applies central primary-admin identity guard for nonparticipant access', async () => {
  await withDatabaseUrl(null, async () => {
    const route = makeForeignFinancialsRoute(unlinkedOwner);
    await assert.rejects(
      route({ method: 'GET', url: '/api/v1/payments/financials/foreign-job', headers: {} }, {}, ['payments', 'financials', 'foreign-job']),
      (error) => error?.status === 403 && error?.code === 'PRIMARY_ADMIN_IDENTITY_REQUIRED',
    );
  });
});

test('financial detail route requires admin-panel step-up before exposing a nonparticipant ledger', async () => {
  await withDatabaseUrl('postgresql://unit-test.invalid/hope', async () => {
    const route = makeForeignFinancialsRoute(admin, { postgres: true, panelVerified: false });
    await assert.rejects(
      route({ method: 'GET', url: '/api/v1/payments/financials/foreign-job', headers: {} }, {}, ['payments', 'financials', 'foreign-job']),
      (error) => error?.status === 403 && error?.code === 'ADMIN_PANEL_LOCKED',
    );
  });
});

test('verified operational admin with finance permission can read foreign financial detail', async () => {
  await withDatabaseUrl('postgresql://unit-test.invalid/hope', async () => {
    const route = makeForeignFinancialsRoute(admin, { postgres: true, panelVerified: true });
    const response = await route({ method: 'GET', url: '/api/v1/payments/financials/foreign-job', headers: {} }, {}, ['payments', 'financials', 'foreign-job']);
    assert.equal(response.status, 200);
    assert.equal(response.data.payment.paymentId, foreignPayment.id);
    assert.deepEqual(response.data.ledger, [{ id: 'private-ledger-entry' }]);
  });
});
