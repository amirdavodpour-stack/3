import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

test('admin entry opens the identity verification gate instead of the protected panel', () => {
  const page = fs.readFileSync(path.resolve(import.meta.dirname, '../../lib/features/home/home_page.dart'), 'utf8');
  assert.match(page, /HopeRoutes\.adminAccess\(\)/);
  assert.doesNotMatch(page, /if \(auth\.user\?\['role'\] == 'ADMIN'\).*HopeRoutes\.admin\(\)/s);
});