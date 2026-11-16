import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const read = (relativePath) => {
  const file = path.resolve(import.meta.dirname, relativePath);
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
};

const migrationDir = path.resolve(import.meta.dirname, '../src/db/migrations');
const migrationNames = fs.readdirSync(migrationDir).filter((name) => /^\d+_[a-z0-9_]+\.js$/i.test(name)).sort();
const migrationFile = migrationNames.find((name) => name === '057_outbox_dedupe_registry.js') || '';
const migration = migrationFile ? read('../src/db/migrations/' + migrationFile) : '';
const registry = read('../src/repository/outbox_dedupe_registry.js');
const facade = read('../src/repository.js');

const producers = [
  { name:'PAYMENT_CREATE_HOLD', path:'../src/repository/payment_funding.js', policy:'STATUS_GATED_REQUEUE' },
  { name:'PAYMENT_RELEASE + SECURITY_ALERT_TERMINAL_FAILURE_SIGNAL', path:'../src/repository/outbox.js', policy:['STATUS_GATED_REQUEUE','FIRST_WINS'] },
  { name:'PAYMENT_REFUND', path:'../src/repository/payment_refunds.js', policy:'STATUS_GATED_REQUEUE' },
  { name:'PAYOUT_EXECUTE', path:'../src/repository/payouts.js', policy:'CREATE_ONLY' },
  { name:'NOTIFICATION_DISPATCH', path:'../src/repository/notifications.js', policy:'FIRST_WINS' },
  { name:'AUTH_REFRESH_REUSE_ALERT', path:'../src/repository/auth.js', policy:'FIRST_WINS' },
];

test('migration 057 creates the permanent Outbox dedupe identity registry', () => {
  assert.ok(migrationFile, 'migration 057_outbox_dedupe_registry.js must exist');
  assert.match(migration, /version\s*:\s*57/);
  assert.match(migration, /name\s*:\s*['"]outbox_dedupe_registry['"]/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS outbox_dedupe_registry/i);
});

test('registry stores versioned digest and immutable event identity, never raw dedupe key or payload', () => {
  const tableStart = migration.indexOf('CREATE TABLE IF NOT EXISTS outbox_dedupe_registry');
  const tableEnd = migration.indexOf(');', tableStart);
  assert.ok(tableStart >= 0 && tableEnd > tableStart, 'registry table definition must be present');
  const table = migration.slice(tableStart, tableEnd);
  assert.match(table, /key_digest\s+BYTEA\s+NOT NULL/i);
  assert.match(table, /digest_version\s+SMALLINT\s+NOT NULL/i);
  assert.match(table, /original_event_id\s+UUID\s+NOT NULL/i);
  assert.match(table, /event_type\s+TEXT\s+NOT NULL/i);
  assert.match(table, /aggregate_type\s+TEXT\s+NOT NULL/i);
  assert.match(table, /aggregate_id\s+UUID/i);
  assert.match(table, /conflict_policy\s+TEXT\s+NOT NULL/i);
  assert.match(table, /state\s+TEXT\s+NOT NULL/i);
  assert.doesNotMatch(table, /\bdedupe_key\s+TEXT\b/i);
  assert.doesNotMatch(table, /\bpayload\s+JSONB\b/i);
});

test('migration backfills every existing non-null Outbox key to its original event UUID', () => {
  assert.match(migration, /INSERT\s+INTO\s+outbox_dedupe_registry/i);
  assert.match(migration, /SELECT[\s\S]*FROM\s+outbox_events/i);
  assert.match(migration, /WHERE\s+dedupe_key\s+IS\s+NOT\s+NULL/i);
  assert.match(migration, /original_event_id[\s\S]*id/i);
  assert.doesNotMatch(migration, /ON CONFLICT\s*\(\s*key_digest\s*\)[\s\S]*?DO NOTHING/i, 'a digest/identity conflict during backfill must fail closed, never silently skip a legacy mapping');
});

test('registry hashes exact key bytes with a domain-separated versioned SHA-256 digest', () => {
  assert.match(registry, /createHash\(['"]sha256['"]\)/);
  assert.match(registry, /hopev2:outbox-dedupe:v1/);
  assert.match(registry, /DIGEST_VERSION\s*=\s*1/);
});

test('registry reservation fails closed for identity mismatch, orphan and archived/tombstoned keys', () => {
  assert.match(registry, /reserveOutboxDedupeKeyWithClient/);
  assert.match(registry, /OUTBOX_DEDUPE_IDENTITY_CONFLICT/);
  assert.match(registry, /OUTBOX_DEDUPE_ORPHANED/);
  assert.match(registry, /OUTBOX_DEDUPE_TOMBSTONED/);
  assert.match(registry, /OUTBOX_DEDUPE_ARCHIVED/);
  assert.match(registry, /FOR UPDATE/);
  assert.match(registry, /event_type/);
  assert.match(registry, /aggregate_type/);
  assert.match(registry, /aggregate_id/);
});

test('reserved insertion is bound to the reservation identity and versioned key digest', () => {
  assert.match(registry, /reservation\.eventType\s*!==\s*eventType/);
  assert.match(registry, /reservation\.aggregateType\s*!==\s*aggregateType/);
  assert.match(registry, /reservation\.aggregateId/);
  assert.match(registry, /reservation\.digestVersion/);
  assert.match(registry, /reservation\.keyDigest/);
  assert.match(registry, /requestedDigest\s*=\s*createOutboxDedupeDigest\(dedupeKey\)/);
  assert.match(registry, /reservedDigest\.equals\(requestedDigest\)/);
});

test('registry declares event-class-specific create-only, first-wins and status-gated requeue policies', () => {
  for (const policy of ['CREATE_ONLY','FIRST_WINS','STATUS_GATED_REQUEUE']) {
    assert.ok(registry.includes(policy), 'missing policy ' + policy);
  }
  for (const eventType of [
    'PAYMENT_CREATE_HOLD',
    'PAYMENT_RELEASE',
    'PAYMENT_REFUND',
    'PAYOUT_EXECUTE',
    'NOTIFICATION_DISPATCH',
    'AUTH_REFRESH_REUSE_ALERT',
    'SECURITY_ALERT_TERMINAL_FAILURE_SIGNAL',
  ]) {
    assert.ok(registry.includes(eventType), 'missing event-class policy for ' + eventType);
  }
});

test('every Outbox producer reserves its global dedupe identity in the same transaction', () => {
  for (const producer of producers) {
    const source = read(producer.path);
    assert.ok(source, producer.name + ' producer source must be readable');
    assert.match(source, /reserveOutboxDedupeKeyWithClient/,
      producer.name + ' must reserve identity through the registry helper');
    assert.doesNotMatch(source, /ON CONFLICT\s*\(\s*dedupe_key\s*\)/i,
      producer.name + ' must not bypass the global registry with a local dedupe upsert');
    const policies = Array.isArray(producer.policy) ? producer.policy : [producer.policy];
    for (const policy of policies) {
      assert.ok(source.includes(policy), producer.name + ' must declare ' + policy);
    }
  }
  assert.match(facade, /outbox_dedupe_registry\.js/);
});

test('normal and admin-dispute releases preserve different dedupe namespaces', () => {
  const normalRoute = read('../src/routes/payment_routes.js');
  const disputeRoute = read('../src/routes/job_dispute_routes.js');
  assert.match(normalRoute, /PAYMENT_RELEASE:\$\{payment\.id\}/);
  assert.match(disputeRoute, /PAYMENT_RELEASE:ADMIN_DISPUTE:\$\{payment\.id\}/);
});

test('Outbox event identity immutability remains enforced by migration 038', () => {
  const immutable = read('../src/db/migrations/038_outbox_event_identity_immutability.js');
  assert.match(immutable, /dedupe_key/);
  assert.match(immutable, /payload/);
  assert.match(immutable, /aggregate_id/);
});
