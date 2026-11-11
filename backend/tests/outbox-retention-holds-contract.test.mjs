import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const migrationPath = new URL('../src/db/migrations/058_outbox_retention_holds.js', import.meta.url);
const repositoryPath = new URL('../src/repository/outbox_retention.js', import.meta.url);
const repositoryIndexPath = new URL('../src/repository.js', import.meta.url);
const migration = fs.existsSync(migrationPath) ? fs.readFileSync(migrationPath, 'utf8') : '';
const retention = fs.existsSync(repositoryPath) ? fs.readFileSync(repositoryPath, 'utf8') : '';
const repositoryIndex = fs.readFileSync(repositoryIndexPath, 'utf8');

test('Outbox holds use their own event and aggregate record classes, not Chat legal holds', () => {
  assert.ok(migration.length > 0, 'migration 058 must define Outbox retention holds');
  assert.match(migration, /outbox_retention_holds/);
  assert.match(migration, /outbox_retention_hold_releases/);
  assert.match(migration, /target_kind IN \('EVENT','AGGREGATE'\)/);
  assert.match(migration, /hold_kind IN \('LEGAL','ADMIN'\)/);
  assert.match(migration, /reason_code/);
  assert.doesNotMatch(migration, /chat_conversation_legal_holds/);
});

test('repository exposes create, release and candidate hold-check operations', () => {
  assert.ok(retention.length > 0, 'Outbox retention repository must exist');
  assert.match(repositoryIndex, /repository\/outbox_retention\.js/);
  assert.match(retention, /export async function createOutboxRetentionHold\(/);
  assert.match(retention, /export async function releaseOutboxRetentionHold\(/);
  assert.match(retention, /export async function createOutboxRetentionHoldWithClient\(/);
  assert.match(retention, /export async function checkOutboxRetentionTargetHoldsWithClient\(/);
});

test('hold creation and release have append-only actor/reason evidence', () => {
  assert.match(retention, /requirePrimaryAdmin:\s*true/,
    'Outbox hold mutations must preserve the existing primary-admin-only privacy hold policy');
  assert.match(retention, /INSERT INTO outbox_retention_holds/);
  assert.match(retention, /INSERT INTO outbox_retention_hold_releases/);
  assert.match(retention, /created_by/);
  assert.match(retention, /released_by/);
  assert.match(retention, /reason_code/);
  assert.match(migration, /BEFORE UPDATE OR DELETE ON outbox_retention_holds/);
  assert.match(migration, /BEFORE UPDATE OR DELETE ON outbox_retention_hold_releases/);
});

test('hold creation and future purge candidate checks share deterministic target locks', () => {
  assert.match(retention, /pg_advisory_xact_lock/);
  assert.match(retention, /lockOutboxRetentionTargetWithClient/);
  assert.match(retention, /set_config\('hopev2\\.outbox_retention_xact_marker'/,
    'WithClient lock helpers must prove an explicit transaction is active before acquiring transaction-scoped locks');
  assert.match(retention, /current_setting\('transaction_isolation'\)/,
    'candidate gate must fail closed rather than inspect holds through a stale repeatable-read snapshot');
  const create = retention.slice(
    retention.indexOf('export async function createOutboxRetentionHoldWithClient('),
    retention.indexOf('\nexport async function createOutboxRetentionHold(', retention.indexOf('export async function createOutboxRetentionHoldWithClient(')),
  );
  const check = retention.slice(
    retention.indexOf('export async function checkOutboxRetentionTargetHoldsWithClient('),
  );
  assert.match(create, /lockOutboxRetentionTargetWithClient/);
  assert.match(check, /lockOutboxRetentionTargetWithClient/);
});

test('read-only dry-run uses one repeatable-read read-only snapshot and keyset pages', () => {
  const start = retention.indexOf('export async function buildOutboxRetentionDryRun(');
  assert.ok(start >= 0, 'Outbox retention dry-run must be implemented');
  const dryRun = retention.slice(start);
  assert.match(dryRun, /BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY/);
  assert.match(dryRun, /\(o\.created_at\s*,\s*o\.id\)\s*>\s*\(/);
  assert.match(dryRun, /pagesRead/);
  assert.match(dryRun, /wouldMutate\s*:\s*false/);
  assert.match(dryRun, /mutationCount\s*:\s*0/);
  assert.match(dryRun, /providerCalls\s*:\s*0/);
  assert.match(dryRun, /RETENTION_PERIOD_NOT_APPROVED/);
  assert.match(dryRun, /FINANCIAL_RECORDS_EXCLUDED/);
  assert.doesNotMatch(dryRun, /o\.payload|payload->|last_error|failure_message/);
  assert.doesNotMatch(dryRun, /UPDATE\s+outbox_events|DELETE\s+FROM\s+outbox_events|INSERT\s+INTO/i);
});

test('hold operations never transition or revive an Outbox event', () => {
  assert.doesNotMatch(retention, /UPDATE\s+outbox_events|DELETE\s+FROM\s+outbox_events|INSERT\s+INTO\s+outbox_events/i);
  assert.match(retention, /ACTIVE_HOLD/);
});
