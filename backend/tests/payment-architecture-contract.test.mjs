import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const createJobPayload = fs.readFileSync(new URL('../../lib/features/marketplace/create_job_payload.dart', import.meta.url), 'utf8');
const createJobValidator = fs.readFileSync(new URL('../../lib/features/marketplace/create_job_validator.dart', import.meta.url), 'utf8');

const routes = fs.readFileSync(new URL('../src/routes/payment_routes.js', import.meta.url), 'utf8');
const webhook = fs.readFileSync(new URL('../src/application/payment_webhook.js', import.meta.url), 'utf8');
const policy = fs.readFileSync(new URL('../src/application/payment_policy.js', import.meta.url), 'utf8');

test('payment route delegates policy and webhook mechanics to application modules', () => {
  assert.match(routes, /application\/payment_policy\.js/);
  assert.match(routes, /application\/payment_webhook\.js/);
  assert.doesNotMatch(routes, /createHmac\(/);
  assert.doesNotMatch(routes, /timingSafeEqual\(/);
  assert.match(webhook, /createHmac\(/);
  assert.match(webhook, /timingSafeEqual\(/);
  assert.match(policy, /validateIdempotencyPair/);
});

test('payment route remains an HTTP adapter rather than a business-rule container', () => {
  const lines = routes.split('\n').length;
  assert.ok(lines < 190, `payment route grew to ${lines} lines; keep orchestration in application modules`);
});


test('Flutter TOMAN job creation never coerces monetary input through double', () => {
  assert.doesNotMatch(createJobPayload, /double\.parse\(input\.(minBudget|maxBudget|monthlySalary)/);
  assert.match(createJobPayload, /'budgetMin': int\.parse\(input\.minBudget\.trim\(\)\)/);
  assert.match(createJobPayload, /'budgetMax': int\.parse\(input\.maxBudget\.trim\(\)\)/);
  assert.match(createJobPayload, /int\.parse\(input\.monthlySalary\.trim\(\)\)/);
  assert.match(createJobValidator, /RegExp\(r'\^\\d\+\$'/);
  assert.match(createJobValidator, /9000000000000000/);
});


test('payment release requires and persists the provider release reference', () => {
  const handler = fs.readFileSync(new URL('../src/outbox_handlers.js', import.meta.url), 'utf8');
  const outbox = fs.readFileSync(new URL('../src/repository/outbox.js', import.meta.url), 'utf8');
  assert.match(handler, /result\.status !== 'RELEASED' \|\| !result\.releaseRef/);
  assert.match(handler, /providerReleaseRef:result\.releaseRef/);
  assert.match(outbox, /providerReleaseRef = null/);
  assert.match(outbox, /settlementProviderRef = providerReleaseRef \|\| payment\.provider_ref/);
  assert.match(outbox, /SETTLEMENT_PROVIDER_REF_REQUIRED/);
});
