import test from 'node:test';
import assert from 'node:assert/strict';
import { createWalletRoutes } from '../src/application/wallet_routes.js';
import { HttpError } from '../src/api/http_error.js';

test('sandbox wallet credit refuses to mutate balances while Admin Panel verification is locked', async () => {
  const originalDatabaseUrl = process.env.DATABASE_URL;
  const originalNodeEnv = process.env.NODE_ENV;
  process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';
  process.env.NODE_ENV = 'production';
  try {
    let panelCheckCalled = false;
    const routes = createWalletRoutes({
      authUser: async () => ({ id: 'primary-admin', email: 'amir.davodpour@gmail.com', role: 'ADMIN' }),
      adminGuard: (user) => user,
      readBody: async () => ({ userId: 'target-user', amount: '100', idempotencyKey: 'test-credit' }),
      sendJson: async (_res, status, data) => ({ status, data }),
      HttpError,
      config: {
        paymentProvider: 'internal',
        internalWalletAdminCreditEnabled: true,
        adminPanelVerificationMinutes: 5,
      },
      walletRepo: {
        isAdminPanelVerified: async (userId, minutes) => {
          panelCheckCalled = true;
          assert.equal(userId, 'primary-admin');
          assert.equal(minutes, 5);
          return false;
        },
      },
    });

    await assert.rejects(
      routes({ method: 'POST', url: '/api/v1/wallet/sandbox-credit', headers: { host: 'localhost' } }, {}, ['wallet', 'sandbox-credit']),
      (error) => error?.status === 403 && error?.code === 'ADMIN_PANEL_LOCKED',
    );
    assert.equal(panelCheckCalled, true);
  } finally {
    if (originalDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDatabaseUrl;
    if (originalNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = originalNodeEnv;
  }
});
