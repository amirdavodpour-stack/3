import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const file = fs.readFileSync(new URL('../src/wallet_ledger.js', import.meta.url), 'utf8');

test('idempotency reservation uses insert-only conflict handling', () => {
  assert.match(file, /ON CONFLICT\(principal_id,operation,idempotency_key\) DO NOTHING\s+RETURNING \*/s);
  assert.doesNotMatch(file, /ON CONFLICT\(principal_id,operation,idempotency_key\) DO UPDATE SET request_hash=EXCLUDED\.request_hash,status='PROCESSING'/s);
});

test('idempotency conflict path re-locks the existing row before deciding', () => {
  assert.match(file, /SELECT \* FROM idempotency_keys[\s\S]*FOR UPDATE/);
  assert.match(file, /status === 'SUCCEEDED'/);
  assert.match(file, /status === 'PROCESSING'/);
  assert.match(file, /status='PROCESSING',resource_type=NULL,resource_id=NULL,response_code=NULL,response_body=NULL/);
});

test('idempotency race failure is explicit rather than silently re-executing', () => {
  assert.match(file, /IDEMPOTENCY_RESERVATION_LOST/);
});
