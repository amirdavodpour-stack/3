import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => {
  try { return fs.readFileSync(new URL(path, import.meta.url), 'utf8'); }
  catch { return ''; }
};

const migration = read('../src/db/migrations/057_outbox_dedupe_registry.js');
const registry = read('../src/repository/outbox_dedupe_registry.js');
const funding = read('../src/repository/payment_funding.js');
const outbox = read('../src/repository/outbox.js');
const refunds = read('../src/repository/payment_refunds.js');
const payouts = read('../src/repository/payouts.js');
const notifications = read('../src/repository/notifications.js');
const auth = read('../src/repository/auth.js');

test('migration 057 creates a minimal digest-only Outbox dedupe registry and backfills existing keyed events', () => {
  assert.ok(migration, 'migration 057 must exist');
  assert.match(migration, /version:\s*57/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS outbox_dedupe_registry/);
  for (const field of ['dedupe_key_hash','event_id','event_type','identity_mode','state','terminal_status','terminal_at','archived_at','tombstoned_at','hash_version']) {
    assert.match(migration, new RegExp(field), 'registry must store ' + field);
  }
  assert.match(migration, /createHash\(['"]sha256['"]\)/);
  assert.match(migration, /FROM outbox_events/);
  assert.match(migration, /dedupe_key IS NOT NULL/);
  assert.doesNotMatch(migration, /payload\s+JSONB|aggregate_id\s+UUID|dedupe_key\s+TEXT/i,
    'the registry must not duplicate payload, aggregate identifiers, or raw dedupe keys');
});

test('central Outbox writer reserves the registry and reuses the original event UUID', () => {
  assert.ok(registry, 'central registry writer must exist');
  assert.match(registry, /export async function createOrReuseOutboxEventWithClient/);
  assert.match(registry, /createHash\(['"]sha256['"]\)/);
  assert.match(registry, /OUTBOX_DEDUPE_IDENTITY_CONFLICT/);
  assert.match(registry, /OUTBOX_DEDUPE_REGISTRY_ORPHANED/);
  assert.match(registry, /TOMBSTONED/);
  assert.match(registry, /ARCHIVED/);
});

test('all seven production event producers use the shared registry writer rather than direct Outbox INSERTs', () => {
  const producers = [
    ['funding', funding],
    ['release and terminal signal', outbox],
    ['refund', refunds],
    ['payout', payouts],
    ['notification', notifications],
    ['refresh-reuse alert', auth],
  ];
  for (const [name, source] of producers) {
    assert.ok(source, name + ' source must load');
    assert.match(source, /createOrReuseOutboxEventWithClient/,
      name + ' must reserve event identity through the central writer');
    assert.doesNotMatch(source, /INSERT INTO outbox_events/i,
      name + ' must not bypass the registry');
  }
});

test('producer conflict policies preserve existing business semantics', () => {
  assert.match(funding, /REQUEUE_ALWAYS/);
  assert.match(outbox, /REQUEUE_UNLESS_DONE/);
  assert.match(refunds, /REQUEUE_IF_FAILED/);
  assert.match(payouts, /CREATE_ONLY/);
  assert.match(notifications, /DO_NOTHING/);
  assert.match(auth, /DO_NOTHING/);
  assert.match(auth, /identityMode:\s*['"]AGGREGATE['"]/);
  assert.match(outbox, /identityMode:\s*['"]AGGREGATE['"]/);
});

test('registry state is monotonic and does not turn tombstoned events active again', () => {
  assert.match(migration, /ACTIVE/);
  assert.match(migration, /ARCHIVED/);
  assert.match(migration, /TOMBSTONED/);
  assert.match(registry, /OUTBOX_DEDUPE_TOMBSTONED/);
  assert.match(registry, /OUTBOX_DEDUPE_ARCHIVED/);
  assert.doesNotMatch(registry, /SET\s+state\s*=\s*['"]ACTIVE['"]\s+WHERE/i);
});
