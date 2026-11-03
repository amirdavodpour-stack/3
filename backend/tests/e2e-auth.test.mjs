import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hope-auth-'));
if (!process.env.DATABASE_URL) process.env.DATA_FILE = path.join(tmp, 'hope.json');
process.env.STORAGE_DIR = path.join(tmp, 'storage');
process.env.NODE_ENV = 'test';
process.env.EXPOSE_EMAIL_VERIFICATION_CODE_IN_DEVELOPMENT = 'true';
const { createServer } = await import('../src/app.js');
const { db } = await import('../src/db.js');
const server = createServer();
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}/api/v1`;
const json = (url, options = {}) => fetch(base + url, {
  ...options,
  headers: {'Content-Type': 'application/json', ...(options.headers || {})},
}).then(async (r) => ({status: r.status, body: await r.json()}));

test('password registration remains pending until email verification issues the first session', async () => {
  const registration = await json('/auth/register', {
    method: 'POST',
    body: JSON.stringify({email: 'auth@example.com', password: 'pass123456789', displayName: 'Auth User'}),
  });
  assert.equal(registration.status, 202);
  assert.equal(registration.body.data.verificationRequired, true);
  assert.equal(registration.body.data.accessToken, undefined);
  const pending = db.collection.users.find((u) => u.email === 'auth@example.com');
  assert.equal(pending.status, 'PENDING_EMAIL_VERIFICATION');

  const pendingLogin = await json('/auth/login', {
    method: 'POST',
    body: JSON.stringify({email: 'auth@example.com', password: 'pass123456789'}),
  });
  assert.equal(pendingLogin.status, 401);

  const verified = await json('/auth/email/verify', {
    method: 'POST',
    body: JSON.stringify({code: registration.body.data.verificationCode}),
  });
  assert.equal(verified.status, 200);
  assert.equal(verified.body.data.user.status, 'ACTIVE');
  assert.ok(verified.body.data.accessToken);

  const login = await json('/auth/login', {
    method: 'POST',
    body: JSON.stringify({email: 'auth@example.com', password: 'pass123456789'}),
  });
  assert.equal(login.status, 200);
  assert.equal(login.body.data.user.id, verified.body.data.user.id);
});

test('duplicate email is rejected without a second account', async () => {
  const duplicate = await json('/auth/register', {
    method: 'POST',
    body: JSON.stringify({email: 'auth@example.com', password: 'pass123456789', displayName: 'Another'}),
  });
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.body.error.code, 'EMAIL_IN_USE');
  assert.equal(db.collection.users.filter((u) => u.email === 'auth@example.com').length, 1);
});


test('public job responses do not expose account email addresses', async () => {
  const categories = await json('/categories');
  assert.equal(categories.status, 200);
  const categoryId = categories.body.data[0].id;
  const owner = await json('/auth/register', {
    method: 'POST',
    body: JSON.stringify({email: 'privacy@example.com', password: 'pass123456789', displayName: 'Privacy Owner'}),
  });
  assert.equal(owner.status, 202);
  const ownerVerification = await json('/auth/email/verify', {method: 'POST', body: JSON.stringify({code: owner.body.data.verificationCode})});
  assert.equal(ownerVerification.status, 200);
  const created = await json('/jobs', {
    method: 'POST',
    headers: {Authorization: `Bearer ${ownerVerification.body.data.accessToken}`},
    body: JSON.stringify({title:'Public job',description:'Public',categoryId,jobType:'FIXED',budgetType:'FIXED',budgetMin:10,budgetMax:20,duration:1,acceptanceCriteria:'done'}),
  });
  assert.equal(created.status, 201);
  const published = await json(`/jobs/${created.body.data.id}/publish`, {method: 'POST', headers: {Authorization: `Bearer ${ownerVerification.body.data.accessToken}`}});
  assert.equal(published.status, 200);
  const listing = await json('/jobs');
  const item = listing.body.data.find((j) => j.id === created.body.data.id);
  assert.ok(item);
  assert.equal(item.owner.email, undefined);
});

test('inactive accounts cannot create a login session', async () => {
  const registration = await json('/auth/register', {
    method: 'POST',
    body: JSON.stringify({email: 'inactive@example.com', password: 'pass123456789', displayName: 'Inactive'}),
  });
  assert.equal(registration.status, 202);
  const verified = await json('/auth/email/verify', {method: 'POST', body: JSON.stringify({code: registration.body.data.verificationCode})});
  assert.equal(verified.status, 200);
  const user = db.collection.users.find((u) => u.email === 'inactive@example.com');
  user.status = 'DISABLED';
  const login = await json('/auth/login', {
    method: 'POST',
    body: JSON.stringify({email: 'inactive@example.com', password: 'pass123456789'}),
  });
  assert.equal(login.status, 401);
  assert.equal(login.body.error.code, 'INVALID_CREDENTIALS');
});

test('malformed stored password hashes fail closed', async () => {
  const user = db.collection.users.find((u) => u.email === 'auth@example.com');
  user.passwordHash = 'not-a-valid-hash';
  const login = await json('/auth/login', {
    method: 'POST',
    body: JSON.stringify({email: 'auth@example.com', password: 'pass123456789'}),
  });
  assert.equal(login.status, 401);
  assert.equal(login.body.error.code, 'INVALID_CREDENTIALS');
});

after(async () => {
  await db.close();
  await new Promise((resolve) => server.close(resolve));
  fs.rmSync(tmp, {recursive: true, force: true});
});
