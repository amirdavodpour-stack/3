#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const testsDir = path.join(root, 'tests');
const files = fs.readdirSync(testsDir)
  .filter((name) => name.endsWith('.test.mjs') && name !== 's3-integration.test.mjs')
  .sort()
  .map((name) => path.join(testsDir, name));

const env = { ...process.env, NODE_ENV: 'test' };
delete env.DATABASE_URL;

let failed = 0;
let passedFiles = 0;
for (const file of files) {
  const rel = path.relative(root, file);
  process.stdout.write(`\n=== OFFLINE ISOLATED: ${rel} ===\n`);
  // Some test files import the DB graph before their setup helpers assign DATA_FILE.
  // Provide unique paths before Node evaluates any module so these tests cannot touch
  // the repository's default JSON database or leak state into the next child process.
  const testTempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'hope-offline-isolated-'));
  const childEnv = {
    ...env,
    DATA_FILE: path.join(testTempDir, 'hope.json'),
    STORAGE_DIR: path.join(testTempDir, 'storage'),
  };
  let result;
  try {
    result = spawnSync(process.execPath, ['--test', '--test-concurrency=1', file], {
      cwd: root,
      env: childEnv,
      stdio: 'inherit',
    });
  } finally {
    fs.rmSync(testTempDir, { recursive: true, force: true });
  }
  if (result.error) {
    console.error(`[offline-isolated] ${rel}: ${result.error.message}`);
    failed += 1;
    continue;
  }
  if (result.status !== 0) {
    console.error(`[offline-isolated] FAIL ${rel} (exit ${result.status})`);
    failed += 1;
  } else {
    passedFiles += 1;
  }
}

console.log(`\nOFFLINE_ISOLATED_SUMMARY files=${files.length} pass=${passedFiles} fail=${failed}`);
process.exit(failed ? 1 : 0);
