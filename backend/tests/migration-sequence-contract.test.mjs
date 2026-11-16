import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import path from 'node:path';

test('database migration filenames use a unique contiguous version sequence', () => {
  const dir = path.resolve(import.meta.dirname, '../src/db/migrations');
  const files = readdirSync(dir)
    .filter((name) => /^\d+_[a-z0-9_]+\.js$/i.test(name))
    .sort();

  const versions = files.map((name) => Number(name.split('_', 1)[0]));
  assert.equal(new Set(versions).size, versions.length, 'migration versions must be unique');

  for (let i = 1; i < versions.length; i += 1) {
    assert.equal(versions[i], versions[i - 1] + 1, 'migration sequence must be contiguous');
  }
});
test('combined Outbox and event-reconciliation migrations keep the canonical ordered slots 055-060', async () => {
  const { loadMigrations } = await import('../src/db/migrations.js');
  const migrations = await loadMigrations();
  const tail = migrations.filter((migration) => migration.version >= 55)
    .map(({ version, name, file }) => ({ version, name, file }));
  assert.deepEqual(tail, [
    { version: 55, name: 'outbox_terminal_clock', file: '055_outbox_terminal_clock.js' },
    { version: 56, name: 'outbox_error_redaction', file: '056_outbox_error_redaction.js' },
    { version: 57, name: 'outbox_dedupe_registry', file: '057_outbox_dedupe_registry.js' },
    { version: 58, name: 'outbox_retention_holds', file: '058_outbox_retention_holds.js' },
    { version: 59, name: 'reconciliation_case_events', file: '059_reconciliation_case_events.js' },
    { version: 60, name: 'reconciliation_event_attestation_and_disposition', file: '060_reconciliation_event_attestation_and_disposition.js' },
  ]);
});
