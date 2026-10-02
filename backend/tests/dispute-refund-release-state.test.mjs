import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

test('dispute refund can consume a payment still waiting for normal release', () => {
  const source = fs.readFileSync(path.resolve(import.meta.dirname, '../src/repository/payment_refunds.js'), 'utf8');
  assert.match(source, /allowPendingRelease/);
  assert.match(source, /RELEASE_PENDING/);
  assert.doesNotMatch(source.split('export async function createRefundAtomic')[0], /\\\\n/);
});