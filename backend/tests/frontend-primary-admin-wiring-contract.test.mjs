import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('admin UI exposes administrator creation only to the primary owner', () => {
  const page = read('lib/features/admin/admin_page.dart');
  const repository = read('lib/core/admin/admin_repository.dart');
  assert.match(page, /_isPrimaryAdmin/);
  assert.match(page, /Add new administrator|افزودن مدیر جدید/);
  assert.match(page, /grantAdminByEmail/);
  assert.match(repository, /POST', '\/admin\/admins'/);
});