import test from 'node:test';
import assert from 'node:assert/strict';
import { createAnalyticsRoutes } from '../src/routes/analytics_routes.js';
import { HttpError } from '../src/api/http_error.js';

test('admin analytics endpoint refuses data access while the verified Admin Panel is locked', async () => {
  const originalDatabaseUrl = process.env.DATABASE_URL;
  process.env.DATABASE_URL = 'postgres://unit-test.invalid/hope';
  try {
    let panelCheckCalled = false;
    const routes = createAnalyticsRoutes({
      authUser: async () => ({ id: 'admin-1', role: 'ADMIN' }),
      requireAdmin: (user) => user,
      readBody: async () => ({}),
      sendJson: async (_res, status, data) => ({ status, data }),
      HttpError,
      sanitizeTelemetryProperties: (value) => value || {},
      recordAnalyticsEvent: async () => ({ eventName: 'test', created: true }),
      recordCrash: async () => ({ id: 'crash-1' }),
      logEvent: () => {},
      config: { adminPanelVerificationMinutes: 5 },
      repo: {
        isAdminPanelVerified: async (userId, minutes) => {
          panelCheckCalled = true;
          assert.equal(userId, 'admin-1');
          assert.equal(minutes, 5);
          return false;
        },
        getAnalyticsSummary: async () => ({ sensitive: true }),
        getCrashSummary: async () => ({ sensitive: true }),
      },
      getProductFunnelSummary: async () => ({ sensitive: true }),
      localProductFunnelSummary: async () => ({ sensitive: true }),
      legacy: { analyticsSummary: () => ({ sensitive: true }), crashSummary: () => ({ sensitive: true }) },
    });

    await assert.rejects(
      routes.analyticsAdminRoutes(
        { method: 'GET', url: '/api/v1/analytics/admin', headers: { host: 'localhost' } },
        {},
        [],
      ),
      (error) => error?.status === 403 && error?.code === 'ADMIN_PANEL_LOCKED',
    );
    assert.equal(panelCheckCalled, true);
  } finally {
    if (originalDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = originalDatabaseUrl;
  }
});
