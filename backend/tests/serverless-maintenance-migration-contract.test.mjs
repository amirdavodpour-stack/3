import test from 'node:test';
import assert from 'node:assert/strict';
import { loadMigrations } from '../src/db/migrations.js';

test('maintenance replay and cross-invocation lease protection are the final schema migrations', async () => {
  const migrations = await loadMigrations();
  const tail = migrations.filter((migration) => migration.version >= 60)
    .map(({ version, name, file }) => ({ version, name, file }));
  assert.deepEqual(tail, [
    { version: 60, name: 'reconciliation_event_attestation_and_disposition', file: '060_reconciliation_event_attestation_and_disposition.js' },
    { version: 61, name: 'serverless_maintenance_runs', file: '061_serverless_maintenance_runs.js' },
    { version: 62, name: 'serverless_maintenance_lease', file: '062_serverless_maintenance_lease.js' },
  ]);
});

import { checksumMigration, assertDatabaseSchemaCurrent } from '../src/db/migrations.js';

test('serverless schema verification is read-only and accepts the exact committed migration checksums', async () => {
  const migrations = await loadMigrations();
  const statements = [];
  const result = await assertDatabaseSchemaCurrent({
    async query(sql) {
      statements.push(sql);
      return { rows: migrations.map((migration) => ({
        version: migration.version,
        name: migration.name,
        checksum: checksumMigration(migration),
      })) };
    },
  });
  assert.equal(result.applied, migrations.length);
  assert.equal(result.latestVersion, 62);
  assert.equal(statements.length, 1);
  assert.match(statements[0], /^SELECT version, name, checksum FROM schema_migrations/);
});

test('serverless schema verification rejects missing, extra, or checksum-drifted migration records', async () => {
  const migrations = await loadMigrations();
  const completeRows = migrations.map((migration) => ({
    version: migration.version,
    name: migration.name,
    checksum: checksumMigration(migration),
  }));
  await assert.rejects(
    () => assertDatabaseSchemaCurrent({ async query() { return { rows: completeRows.slice(0, -1) }; } }),
    /schema is not current/,
  );
  await assert.rejects(
    () => assertDatabaseSchemaCurrent({ async query() { return { rows: [...completeRows, { version: 999, name: 'unknown', checksum: 'x' }] }; } }),
    /schema is not current/,
  );
  const drifted = completeRows.map((row) => ({ ...row }));
  drifted[0].checksum = '0'.repeat(64);
  await assert.rejects(
    () => assertDatabaseSchemaCurrent({ async query() { return { rows: drifted }; } }),
    /schema is not current/,
  );
});
