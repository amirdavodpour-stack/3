import test from 'node:test';
import assert from 'node:assert/strict';
import { verifyAdminPanelCredentials } from '../src/application/admin_panel_access.js';
import { createPaymentRoutes } from '../src/routes/payment_routes.js';
import { HttpError } from '../src/api/http_error.js';

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


test('admin financials require current session-bound Admin Panel verification', async () => {
  const originalDatabaseUrl = process.env.DATABASE_URL;
  const sessionJti = 'payment-financials-session-jti';
  process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';
  try {
    let panelCheckCalls = 0;
    const routes = createPaymentRoutes({
      authUser: async () => ({
        id: 'ops-admin',
        email: 'ops-admin@example.com',
        role: 'ADMIN',
        sessionJti,
      }),
      readBody: async () => ({}),
      readRawBody: async () => Buffer.from('{}'),
      sendJson: async (_res, status, data) => ({ status, data }),
      HttpError,
      config: { adminPanelVerificationMinutes: 7 },
      db: {},
      repo: {
        isAdminPanelVerified: async (userId, minutes, actualSessionJti) => {
          panelCheckCalls += 1;
          assert.equal(userId, 'ops-admin');
          assert.equal(minutes, 7);
          assert.equal(actualSessionJti, sessionJti);
          return true;
        },
        listLedgerEntriesForPayment: async () => [],
      },
      getJob: async () => ({ id: 'job-1', ownerId: 'owner-1', providerId: 'worker-1' }),
      relatedJob: () => false,
      paymentUseCases: {
        findByJob: async () => ({ id: 'payment-1', status: 'HELD' }),
      },
      paymentLegacy: {},
      paymentView: async (payment, job) => ({ paymentId: payment?.id || null, jobId: job.id }),
    });

    const response = await routes(
      { method: 'GET', url: '/api/v1/payments/financials/job-1', headers: { host: 'localhost' } },
      {},
      ['payments', 'financials', 'job-1'],
    );

    assert.equal(panelCheckCalls, 1);
    assert.equal(response.status, 200);
    assert.deepEqual(response.data, {
      payment: { paymentId: 'payment-1', jobId: 'job-1' },
      ledger: [],
    });
  } finally {
    if (originalDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDatabaseUrl;
  }
});
