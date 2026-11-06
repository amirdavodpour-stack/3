import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('..', import.meta.url).pathname, '..');
test('every external workflow action ref is pinned to a full immutable commit SHA', () => {
  for (const file of fs.readdirSync(path.join(root, '.github', 'workflows')).filter((name) => /\.ya?ml$/i.test(name))) {
    const lines = fs.readFileSync(path.join(root, '.github', 'workflows', file), 'utf8').split(/\r?\n/);
    for (const [index, line] of lines.entries()) {
      const match = line.match(/^\s*uses:\s*(.*?)\s*$/i);
      if (!match) continue;
      const value = match[1].replace(/\s+#.*$/, '').trim();
      if (value.startsWith('./')) continue;
      assert.match(
        value,
        /^[^@\s]+@[0-9a-f]{40}$/i,
        `${file}:${index + 1}: external action must use a full 40-character commit SHA: ${value}`,
      );
    }
  }
});

test('production and resilience workflows run backend on Node 24', () => {
  for (const file of ['production-release.yml', 'staging-resilience.yml']) {
    const text = fs.readFileSync(path.join(root, '.github', 'workflows', file), 'utf8');
    assert.match(text, /node-version:\s*'24'/, `${file} must use Node 24`);
  }
});

test('production workflow cleans temporary release keystore', () => {
  const text = fs.readFileSync(path.join(root, '.github', 'workflows', 'production-release.yml'), 'utf8');
  assert.match(text, /Cleanup production keystore/);
  assert.match(text, /rm -f -- \"\$KEYSTORE_PATH\"/);
});
