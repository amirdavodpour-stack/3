import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const ROOT = new URL('../', import.meta.url);

test('temporary admin suspension requires reason, review deadline, durable case and atomic audit', async () => {
  const repository = await readFile(new URL('src/repository/admin.js', ROOT), 'utf8');
  const route = await readFile(new URL('src/routes/admin_routes.js', ROOT), 'utf8');
  const useCases = await readFile(new URL('src/application/use_cases/admin_use_cases.js', ROOT), 'utf8');
  const migration = await readFile(new URL('src/db/migrations/048_admin_user_status_review_cases.js', ROOT), 'utf8');

  assert.match(repository, /admin_user_status_review_cases/);
  assert.match(repository, /reviewDueAt/);
  assert.match(repository, /resolution_reason/);
  assert.match(repository, /ADMIN_USER_STATUS/);
  assert.match(repository, /actorId/);
  assert.match(route, /body\?\.reason/);
  assert.match(route, /reviewDueAt/);
  assert.match(useCases, /setUserStatus: \(id, status, options\)/);
  assert.match(migration, /review_due_at/);
  assert.match(migration, /resolved_by/);
  assert.match(migration, /CREATE UNIQUE INDEX[\s\S]*status='OPEN'/);
  assert.doesNotMatch(repository, /review_due_at[\s\S]*UPDATE users SET status='ACTIVE'/i,
    'a review deadline is not an automatic reactivation trigger');
});
