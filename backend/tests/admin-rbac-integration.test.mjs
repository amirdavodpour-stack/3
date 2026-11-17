import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { makeTempEnv, startApiServer, register, closeApi } from './support/hope-test-harness.mjs';

const tmp=makeTempEnv('hope-admin-rbac-');
process.env.ADMIN_PANEL_USERNAME='hope-admin';
const api=await startApiServer();

const auth=(token)=>({Authorization:'Bearer '+token});
async function login(email){const r=await api.json('/auth/login',{method:'POST',body:JSON.stringify({email,password:'pass123456789'})});assert.equal(r.status,200);return r.body.data;}
async function unlock(s){const r=await api.json('/admin/access',{method:'POST',headers:auth(s.accessToken),body:JSON.stringify({name:s.user.displayName,username:'hope-admin'})});assert.equal(r.status,200);return r.body.data;}

test('owner and operational admin receive different backend capabilities',async()=>{
  const ownerReg=await register(api.json,'amir.davodpour@gmail.com','Owner'); const opsReg=await register(api.json,'ops-rbac@example.com','Ops Admin'); const regular=await register(api.json,'rbac-user@example.com','Regular User');
  const ownerRow=api.db.collection.users.find(x=>x.id===ownerReg.user.id); const opsRow=api.db.collection.users.find(x=>x.id===opsReg.user.id); ownerRow.role='ADMIN'; opsRow.role='ADMIN'; await api.db.save();
  const owner=await login(ownerReg.user.email); const ops=await login(opsReg.user.email); const ownerAccess=await unlock(owner); const opsAccess=await unlock(ops);
  const ownerOnly=['admin.manage_admins','admin.delete_jobs','admin.resolve_disputes','admin.resolve_payouts','admin.revoke_sessions','admin.sandbox_wallet_credit'];
  for(const p of ownerOnly) assert.equal(ownerAccess.permissions.includes(p),true,p); assert.equal(opsAccess.permissions.includes('admin.moderate_jobs'),true);
  for(const p of ownerOnly) assert.equal(opsAccess.permissions.includes(p),false,p);
  for(const r of [
    await api.json('/admin/admins',{method:'POST',headers:auth(ops.accessToken),body:JSON.stringify({email:regular.user.email})}),
    await api.json('/admin/jobs/nope',{method:'DELETE',headers:auth(ops.accessToken)}),
    await api.json('/admin/payouts/nope/resolve',{method:'POST',headers:auth(ops.accessToken),body:JSON.stringify({decision:'FAILED'})}),
    await api.json('/admin/disputes/nope',{method:'POST',headers:auth(ops.accessToken),body:JSON.stringify({resolution:'HOLD'})}),
    await api.json('/wallet/sandbox-credit',{method:'POST',headers:auth(ops.accessToken),body:JSON.stringify({userId:regular.user.id,amount:100,idempotencyKey:'ops-denied'})}),
    await api.json('/admin/users/'+owner.user.id+'/status',{method:'POST',headers:auth(ops.accessToken),body:JSON.stringify({status:'SUSPENDED'})})
  ]) assert.equal(r.status,403);
  assert.equal((await api.json('/admin/users/'+regular.user.id+'/status',{method:'POST',headers:auth(ops.accessToken),body:JSON.stringify({status:'SUSPENDED'})})).status,200);
  assert.equal((await api.json('/admin/users/'+ops.user.id+'/status',{method:'POST',headers:auth(owner.accessToken),body:JSON.stringify({status:'SUSPENDED'})})).status,200);
  const sess=await api.json('/admin/users/'+regular.user.id+'/revoke-sessions',{method:'POST',headers:auth(owner.accessToken),body:JSON.stringify({})}); assert.equal(sess.status,200); assert.equal(sess.body.data.revoked,true);
  assert.equal((await api.json('/admin/admins/'+ops.user.id,{method:'DELETE',headers:auth(owner.accessToken)})).status,200); assert.equal(api.db.collection.users.find(x=>x.id===ops.user.id).role,'USER');
  assert.equal((await api.json('/admin/admins/'+owner.user.id,{method:'DELETE',headers:auth(owner.accessToken)})).status,403);
});
after(async()=>closeApi({...api,tmp}));