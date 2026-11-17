import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

test('ApiClient exposes scoped extra headers for admin panel sessions', () => {
  const source = fs.readFileSync(path.resolve(import.meta.dirname, '../../lib/core/network/api_client.dart'), 'utf8');
  assert.match(source, /Map<String, String>\? headers/);
  assert.match(source, /\.\.\.\?headers/);
  assert.match(source, /requestHeaders\['Authorization'\]/);
  assert.match(source, /\.patch\(uri, headers: requestHeaders/);
});