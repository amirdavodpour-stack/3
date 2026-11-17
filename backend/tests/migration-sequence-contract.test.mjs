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