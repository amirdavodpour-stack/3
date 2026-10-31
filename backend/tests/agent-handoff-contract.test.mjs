import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

for (const file of [
  'AGENT-HANDOFF-PROMPT.md',
  'AGENT-RESOURCE-POLICY.md',
  'tools/agent-preflight.sh',
  'tools/ci-resource-guard.sh',
]) {
  test(`agent handoff contract contains ${file}`, () => {
    const target = path.join(root, file);
    assert.equal(fs.existsSync(target), true, `${file} must exist`);
    const text = fs.readFileSync(target, 'utf8');
    assert.ok(text.length > 300, `${file} must contain substantive contract content`);
  });
}

test('canonical APK helper invokes resource guard before expensive build work', () => {
  const text = fs.readFileSync(path.join(root, 'tools/build_apk_debug.sh'), 'utf8');
  const guard = text.indexOf('bash tools/ci-resource-guard.sh');
  const preflight = text.indexOf('bash tools/android-build-preflight.sh');
  assert.ok(guard >= 0, 'resource guard invocation missing');
  assert.ok(preflight >= 0, 'android preflight invocation missing');
  assert.ok(guard < preflight, 'resource guard must run before Android preflight/build work');
});

test('offline backend suite is process-isolated so test env cannot bleed between files', () => {
  const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'backend/package.json'), 'utf8'));
  assert.equal(packageJson.scripts['test:offline'], 'NODE_ENV=test node tools/run-test-files-isolated.mjs');
  const runner = fs.readFileSync(path.join(root, 'backend/tools/run-test-files-isolated.mjs'), 'utf8');
  assert.match(runner, /spawnSync\(process\.execPath/);
  assert.match(runner, /delete env\.DATABASE_URL/);
  assert.match(runner, /--test-concurrency=1/);
});

test('handoff contract forbids unsupported PASS promotion', () => {
  const text = fs.readFileSync(path.join(root, 'AGENT-HANDOFF-PROMPT.md'), 'utf8');
  for (const needle of ['No fake green', 'Do **not** declare V1 COMPLETE', 'BLOCKED', 'UNVERIFIED']) {
    assert.ok(text.includes(needle), `handoff contract must preserve ${needle}`);
  }
});

test('offline test runner isolates legacy data and storage paths for every test file', () => {
  const runner = fs.readFileSync(path.join(root, 'backend/tools/run-test-files-isolated.mjs'), 'utf8');
  assert.match(runner, /mkdtempSync\(path\.join\(os\.tmpdir\(\), ['"]hope-offline-isolated-/);
  assert.match(runner, /DATA_FILE:\s*path\.join\(testTempDir, ['"]hope\.json['"]\)/);
  assert.match(runner, /STORAGE_DIR:\s*path\.join\(testTempDir, ['"]storage['"]\)/);
  assert.match(runner, /rmSync\(testTempDir,\s*\{\s*recursive:\s*true,\s*force:\s*true\s*\}\)/);
});

test('script-isolated runner splits npm scripts into individual test file paths', () => {
  const result = spawnSync(
    process.execPath,
    [path.join(root, 'backend/tools/run-test-script-isolated.mjs'), '--script', 'test:runner-probe'],
    {
      cwd: path.join(root, 'backend'),
      env: { ...process.env, DATABASE_URL: '' },
      encoding: 'utf8',
      timeout: 20000,
    },
  );
  const output = `${result.stdout || ''}\n${result.stderr || ''}`;
  assert.equal(result.error, undefined, result.error?.message);
  assert.equal(result.status, 0, output);
  assert.match(output, /ISOLATED_TEST_SUMMARY files=1 pass=1 fail=0/);
});
