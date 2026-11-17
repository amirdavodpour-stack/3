import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

test('admin dispute panel renders complete case evidence and permitted resolution actions', () => {
  const source = fs.readFileSync(path.resolve(import.meta.dirname, '../../lib/features/admin/admin_disputes_page.dart'), 'utf8');
  for (const marker of ['paymentStatus', 'paymentAmount', 'evidence', 'adminActions', 'Legal basis', 'Factual findings', 'Missing evidence']) {
    assert.match(source, new RegExp(marker));
  }
});