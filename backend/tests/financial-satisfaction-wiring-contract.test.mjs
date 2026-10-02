import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('backend wires wallet insights, satisfaction flow and automatic release', () => {
  const app = read('backend/src/app.js');
  const walletRoutes = read('backend/src/application/wallet_routes.js');
  const satisfactionRoutes = read('backend/src/routes/job_satisfaction_routes.js');

  assert.match(app, /createJobSatisfactionRoutes/);
  assert.match(app, /createFinancialInsightsRoutes/);
  assert.match(walletRoutes, /financial-insights/);
  assert.match(satisfactionRoutes, /evaluateSettlementGate/);
  assert.match(satisfactionRoutes, /processPaymentReleaseNow/);
});

test('generic AI chat is explicitly disabled for users', () => {
  const route = read('backend/src/routes/ai_routes.js');
  const policy = read('backend/src/application/ai_access_policy.js');
  assert.match(route, /assertAutomatedAiAccess/);
  assert.match(route, /AI_USER_ACCESS_DISABLED/);
  assert.match(policy, /JOB_SATISFACTION/);
});
