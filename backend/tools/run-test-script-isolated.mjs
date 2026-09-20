#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));

function parseArgs(argv) {
  if (argv[0] === '--script' && argv[1]) return {script: argv[1], files: null};
  if (argv[0] === '--files' && argv.length > 1) return {script: null, files: argv.slice(1)};
  throw new Error('usage: run-test-script-isolated.mjs --script <npm-script> | --files <test...>');
}

function filesFromScript(name) {
  const script = String(packageJson.scripts?.[name] || '');
  if (!script) throw new Error(`Unknown npm script: ${name}`);
  const files = script.split(/\\s+/).filter((item) => item.endsWith('.test.mjs'));
  if (!files.length) throw new Error(`npm script ${name} contains no .test.mjs files`);
  return [...new Set(files)];
}

const {script, files: explicitFiles} = parseArgs(process.argv.slice(2));
const files = explicitFiles || filesFromScript(script);
const perFileTimeoutMs = 90000;
let failed = 0;
let passed = 0;

console.log(`[isolated] running ${files.length} test files in separate processes`);

for (const file of files) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'hope-isolated-suite-'));
  const env = {
    ...process.env,
    NODE_ENV: 'test',
    DATABASE_URL: '',
    DATA_FILE: path.join(temp, 'hope.json'),
    STORAGE_DIR: path.join(temp, 'storage'),
  };

  console.log(`\\n=== ISOLATED TEST: ${file} ===`);
  const result = spawnSync(
    process.execPath,
    ['--test', '--test-concurrency=1', '--test-timeout=60000', file],
    {
      cwd: root,
      env,
      stdio: 'inherit',
      timeout: perFileTimeoutMs,
      killSignal: 'SIGTERM',
    },
  );

  if (result.error) {
    console.error(`[isolated] ERROR ${file}: ${result.error.message}`);
    failed += 1;
  } else if (result.status !== 0) {
    console.error(`[isolated] FAIL ${file}: exit=${result.status}${result.signal ? ` signal=${result.signal}` : ''}`);
    failed += 1;
  } else {
    passed += 1;
  }
  fs.rmSync(temp, {recursive: true, force: true});
}

console.log(`\\nISOLATED_TEST_SUMMARY files=${files.length} pass=${passed} fail=${failed}`);
process.exit(failed ? 1 : 0);
