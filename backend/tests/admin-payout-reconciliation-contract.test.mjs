import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const screen = fs.readFileSync(
  new URL('../../lib/features/admin/admin_operations_page.dart', import.meta.url),
  'utf8',
);
const payoutCardStart = screen.indexOf('Widget _payoutCard(');
const payoutCardEnd = screen.indexOf('Future<void> _resolvePayout', payoutCardStart);
const payoutCard = payoutCardStart >= 0 && payoutCardEnd > payoutCardStart
  ? screen.slice(payoutCardStart, payoutCardEnd)
  : '';

test('admin payout cards render active reconciliation cases instead of hiding nested API data', () => {
  assert.ok(payoutCard, 'admin operations page must define its payout card');
  assert.match(payoutCard, /row\['reconciliationCases'\]/);
  assert.match(payoutCard, /is List/);
  assert.match(payoutCard, /whereType<Map>/);
});

test('admin payout cards display case type, severity, state and expected/observed evidence', () => {
  assert.match(payoutCard, /caseType/);
  assert.match(payoutCard, /severity/);
  assert.match(payoutCard, /status/);
  assert.match(payoutCard, /expected/);
  assert.match(payoutCard, /observed/);
  assert.match(payoutCard, /CRITICAL/);
});
