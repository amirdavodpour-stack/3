import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

test('dispute migration refuses rollback while dispute records exist', () => {
  const file = fs.readFileSync(path.resolve(import.meta.dirname, '../src/db/migrations/030_job_disputes.js'), 'utf8');
  assert.match(file, /Cannot rollback job_disputes while it contains data/);
  assert.match(file, /SELECT 1 FROM job_disputes LIMIT 1/);
});