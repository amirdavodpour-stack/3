import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
const root=path.resolve(import.meta.dirname,'../..');
const read=(p)=>fs.readFileSync(path.join(root,p),'utf8');

test('human chat UI uses messaging endpoints and exposes job/admin routes',()=>{
  const repo=read('lib/core/chat/chat_repository.dart');
  const page=read('lib/features/chat/chat_page.dart');
  const routes=read('lib/core/router/app_routes.dart');
  assert.match(repo,/\/messaging\/conversations/);
  assert.doesNotMatch(page,/HOPE Assistant|Ask HOPE anything/);
  assert.match(routes,/jobChat\(String jobId\)/);
  assert.match(routes,/adminChat\(\)/);
});
