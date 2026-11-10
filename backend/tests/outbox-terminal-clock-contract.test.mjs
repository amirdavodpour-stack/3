import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const migrationPath = path.join(here,'../src/db/migrations/055_outbox_terminal_clock.js');
const migrationExists = fs.existsSync(migrationPath);
const migration = migrationExists ? fs.readFileSync(migrationPath,'utf8') : '';
const outbox = fs.readFileSync(path.join(here,'../src/repository/outbox.js'),'utf8');

test('migration 055 installs a universal Outbox terminal clock without historical backfill',()=>{
  assert.equal(migrationExists,true,'migration 055 must exist');
  assert.match(migration,/version:\s*55/);
  assert.match(migration,/name:\s*'outbox_terminal_clock'/);
  assert.match(migration,/ADD COLUMN IF NOT EXISTS terminal_at TIMESTAMPTZ/);
  assert.match(migration,/CREATE OR REPLACE FUNCTION hope_set_outbox_terminal_at/);
  assert.match(migration,/BEFORE INSERT OR UPDATE ON outbox_events/);
  assert.match(migration,/terminal_at IS NULL\s+OR status IN \('DONE','FAILED','CANCELLED'\)/);
  assert.doesNotMatch(migration,/UPDATE\s+outbox_events\s+SET\s+terminal_at/i,
    'legacy terminal timestamps must remain unknown rather than being inferred from processed_at');
});

test('terminal clock is assigned only by a state transition and is preserved for duplicate terminal callbacks',()=>{
  assert.match(migration,/IF NEW\.status IS DISTINCT FROM OLD\.status THEN/);
  assert.match(migration,/NEW\.terminal_at\s*:=\s*NOW\(\)/);
  assert.match(migration,/NEW\.terminal_at\s*:=\s*OLD\.terminal_at/);
  assert.match(migration,/NEW\.terminal_at\s*:=\s*NULL/);
});

test('generic Outbox retry, completion and security replay continue to use the shared Outbox table',()=>{
  assert.match(outbox,/export async function failOutboxEvent/);
  assert.match(outbox,/export async function completeOutboxEvent/);
  assert.match(outbox,/export async function replaySecurityAlert/);
  assert.match(outbox,/status='PENDING'/);
});
