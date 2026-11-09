import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createAdminLegacyAdapter } from '../src/application/legacy/admin_legacy.js';

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


test('legacy suspension review metadata persists through the supported user collection', () => {
  const user={id:'legacy-user-1',email:'legacy-user@example.test',role:'USER',status:'ACTIVE',sessionVersion:0};
  const state={users:[user],adminUserStatusReviewCases:[]};
  const touched=[];
  const db={
    collection:state,
    touch(name){ if(name!=='users') throw new Error('Unknown collection: '+name); touched.push(name); },
  };
  const adapter=createAdminLegacyAdapter({db,findUser:(id)=>state.users.find((u)=>u.id===id),now:()=>new Date('2026-11-06T01:00:00.000Z')});
  const reviewDueAt = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
  const suspended=adapter.setUserStatus(user.id,'SUSPENDED',{
    actorId:'legacy-admin-1',
    reason:'Temporary review required',
    reviewDueAt,
  });
  assert.equal(suspended.status,'SUSPENDED');
  assert.equal(state.adminUserStatusReviewCases.length,1);
  assert.equal(state.adminUserStatusReviewCases[0].reason,'Temporary review required');
  assert.equal(state.adminUserStatusReviewCases[0].reviewDueAt,reviewDueAt);
  assert.deepEqual(touched,['users']);

  const activated=adapter.setUserStatus(user.id,'ACTIVE',{
    actorId:'legacy-admin-1',
    reason:'Manual review completed',
  });
  assert.equal(activated.status,'ACTIVE');
  assert.equal(state.adminUserStatusReviewCases[0].status,'RESOLVED');
  assert.equal(state.adminUserStatusReviewCases[0].resolutionReason,'Manual review completed');
  assert.deepEqual(touched,['users','users']);
});
