import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createAdminLegacyAdapter } from '../src/application/legacy/admin_legacy.js';

const ROOT = new URL('../', import.meta.url);

test('administrator promotion requires target provider identity and stores the grant audit in the same transaction', async () => {
  const repository = await readFile(new URL('src/repository/admin.js', ROOT), 'utf8');
  const legacy = await readFile(new URL('src/application/legacy/admin_legacy.js', ROOT), 'utf8');
  const routes = await readFile(new URL('src/routes/admin_routes.js', ROOT), 'utf8');

  const grantStart = repository.indexOf('export async function grantAdminByEmail(');
  const grantEnd = repository.indexOf('export async function revokeAdminById(', grantStart);
  const grant = repository.slice(grantStart, grantEnd);
  assert.match(grant, /google_subject/);
  assert.match(grant, /ADMIN_PROVIDER_IDENTITY_REQUIRED/);
  assert.match(grant, /status\s*!==\s*'ACTIVE'/);
  assert.match(grant, /ORDER BY id\s+FOR UPDATE/);
  assert.match(grant, /admin_panel_verified_scope=NULL/);
  assert.match(grant, /INSERT INTO audit_logs/);
  assert.match(grant, /ADMIN_ROLE_GRANT/);
  assert.match(legacy, /googleSubject/);
  assert.match(legacy, /ADMIN_PROVIDER_IDENTITY_REQUIRED/);
  assert.match(routes, /if\s*\(!process\.env\.DATABASE_URL\)/);
});

test('legacy administrator promotion requires an already-linked provider identity and clears stale step-up', () => {
  const actor = {
    id:'primary-owner',
    email:'amir.davodpour@gmail.com',
    role:'ADMIN',
    status:'ACTIVE',
    googleSubject:'verified-primary-google-subject',
  };
  const unlinked = {
    id:'unlinked-target',
    email:'unlinked@example.test',
    role:'USER',
    status:'ACTIVE',
    sessionVersion:4,
    googleSubject:null,
  };
  const linked = {
    id:'linked-target',
    email:'linked@example.test',
    role:'USER',
    status:'ACTIVE',
    sessionVersion:7,
    googleSubject:'verified-target-google-subject',
    adminPanelVerifiedAt:'2026-11-06T00:00:00.000Z',
    adminPanelVerifiedSessionJti:'prior-session',
    adminPanelVerifiedScope:'WRITE',
  };
  const state={users:[actor,unlinked,linked],audit:[]};
  const touched=[];
  const db={
    collection:state,
    touch(name){ if(name!=='users' && name!=='audit') throw new Error('Unknown collection: '+name); touched.push(name); },
  };
  const adapter=createAdminLegacyAdapter({
    db,
    findUser:(id)=>state.users.find((user)=>user.id===id),
    now:()=>new Date('2026-11-06T18:00:00.000Z'),
  });

  assert.throws(
    ()=>adapter.grantAdminByEmail(unlinked.email,actor.id),
    (error)=>error?.code==='ADMIN_PROVIDER_IDENTITY_REQUIRED',
  );
  assert.equal(unlinked.role,'USER');
  assert.equal(unlinked.sessionVersion,4);

  const promoted=adapter.grantAdminByEmail(linked.email,actor.id);
  assert.equal(promoted.role,'ADMIN');
  assert.equal(promoted.roleGrantApplied,true);
  assert.equal(promoted.sessionVersion,8);
  assert.equal(promoted.googleSubject,'verified-target-google-subject');
  assert.equal(promoted.adminPanelVerifiedAt,null);
  assert.equal(promoted.adminPanelVerifiedSessionJti,null);
  assert.equal(promoted.adminPanelVerifiedScope,null);

  const idempotent=adapter.grantAdminByEmail(linked.email,actor.id);
  assert.equal(idempotent.role,'ADMIN');
  assert.equal(idempotent.roleGrantApplied,false);
  assert.equal(linked.sessionVersion,8);
});

test('legacy admin role revocation requires an active verified owner and clears all step-up state', () => {
  const actor={id:'owner',email:'amir.davodpour@gmail.com',role:'ADMIN',status:'ACTIVE',googleSubject:'owner-google-sub'};
  const target={id:'target-admin',email:'admin-target@example.test',role:'ADMIN',status:'ACTIVE',googleSubject:'target-google-sub',sessionVersion:9,adminPanelVerifiedAt:'2026-11-06T00:00:00.000Z',adminPanelVerifiedSessionJti:'old-jti',adminPanelVerifiedScope:'WRITE'};
  const state={users:[actor,target]};
  const touched=[];
  const db={collection:state,touch(name){if(name!=='users')throw new Error('Unknown collection: '+name);touched.push(name);}};
  const adapter=createAdminLegacyAdapter({db,findUser:(id)=>state.users.find((user)=>user.id===id),now:()=>new Date('2026-11-06T20:00:00.000Z')});
  const revoked=adapter.revokeAdminById(target.id,actor.id);
  assert.equal(revoked.role,'USER');
  assert.equal(revoked.sessionVersion,10);
  assert.equal(revoked.googleSubject,'target-google-sub');
  assert.equal(revoked.adminPanelVerifiedAt,null);
  assert.equal(revoked.adminPanelVerifiedSessionJti,null);
  assert.equal(revoked.adminPanelVerifiedScope,null);
  assert.deepEqual(touched,['users']);

  actor.status='SUSPENDED';
  target.role='ADMIN';
  assert.throws(
    ()=>adapter.revokeAdminById(target.id,actor.id),
    (error)=>error?.code==='PRIMARY_ADMIN_ONLY',
  );
  assert.equal(target.role,'ADMIN','an inactive primary-owner actor must not mutate administrator roles');
});
