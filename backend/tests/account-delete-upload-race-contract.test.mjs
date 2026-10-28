import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(new URL('..', import.meta.url).pathname);
const read = (file) => readFileSync(path.join(ROOT, file), 'utf8');

test('PostgreSQL account deletion selects cleanup keys under upload row locks in the deletion transaction', () => {
  const privacy = read('src/repository/privacy.js');
  const deletion = privacy.slice(privacy.indexOf('export async function deleteUserPrivacyBundle'));
  assert.match(deletion, /withSqlTransaction\(async\s*\(client\)/);
  assert.match(deletion, /SELECT id,role FROM users WHERE id=\$1 FOR NO KEY UPDATE/);
  assert.match(deletion, /SELECT\s+id\s*,\s*storage_key\s+FROM\s+uploads\s+WHERE\s+uploaded_by=\$1\s+ORDER BY\s+id\s+FOR UPDATE/i);
  assert.match(deletion, /NOT EXISTS\s*\(\s*SELECT 1 FROM evidence/i);
  assert.match(deletion, /NOT EXISTS\s*\(\s*SELECT 1 FROM chat_message_attachments/i);
  assert.match(deletion, /deletableUploadKeys/);
  assert.match(deletion, /SELECT id,storage_key FROM upload_intents WHERE uploaded_by=\$1 ORDER BY id FOR UPDATE/);
  assert.match(deletion, /pendingUploadIntentKeys/);
  assert.doesNotMatch(deletion, /DELETE FROM upload_intents WHERE uploaded_by=\$1/,
    'pending presigned keys must remain available to the expiry/grace cleanup worker');
});

test('PostgreSQL account route uses cleanup keys returned by the atomic deletion operation', () => {
  const route = read('src/routes/account_routes.js');
  assert.match(route, /deleteUserPrivacyBundle\(me\.id,\s*replacement\)/);
  assert.match(route, /deleted\.deletableUploadKeys/);
  assert.match(route, /deleted\.pendingUploadIntentKeys/);
  assert.match(route, /privacyRepo\.deleteUserPrivacyBundle/);
  assert.doesNotMatch(route, /privacyRepo\.listDeletableUserUploadKeys/,
    'PostgreSQL cleanup candidates must be returned by the locked deletion transaction');
  assert.match(route, /legacyDeletableUploadKeys[\s\S]*?legacyAccount\.deleteUserPrivacyBundle/,
    'the explicit legacy test adapter must preserve its pre-delete key snapshot');
});

test('evidence attachment locks the owned upload before locking the job and creating the reference', () => {
  const storage = read('src/repository/storage.js');
  const evidence = storage.slice(storage.indexOf('export async function insertEvidenceAndTouchJob'));
  const uploadLock = evidence.indexOf('FROM uploads WHERE storage_key=$1 AND uploaded_by=$2 FOR UPDATE');
  const jobLock = evidence.indexOf('FROM jobs WHERE id=$1 FOR UPDATE');
  const insert = evidence.indexOf('INSERT INTO evidence');
  assert.ok(uploadLock >= 0, 'evidence insertion must lock the upload row');
  assert.ok(jobLock > uploadLock, 'lock order must be upload then job to match deletion cleanup');
  assert.ok(insert > jobLock, 'evidence must only be inserted after both rows are validated and locked');
});

test('chat attachment association uses a locked upload row and inserts the reference in the same transaction', () => {
  const chat = read('src/repository/human_chat.js');
  const post = chat.slice(chat.indexOf('export async function postChatMessage'));
  const transaction = post.indexOf('return withSqlTransaction');
  const uploadLock = post.indexOf('FROM uploads WHERE storage_key=ANY($1::text[]) AND uploaded_by=$2 ORDER BY id FOR UPDATE');
  const attachmentInsert = post.indexOf('INSERT INTO chat_message_attachments');
  assert.ok(transaction >= 0 && uploadLock > transaction && attachmentInsert > uploadLock);
});

test('upload rows and intents serialize creation against account deletion', () => {
  const storage = read('src/repository/storage.js');
  assert.match(storage, /SELECT status FROM users WHERE id=\$1 FOR NO KEY UPDATE/);
  const insertUpload = storage.slice(storage.indexOf('export async function insertUpload'), storage.indexOf('export async function findUploadByKey'));
  assert.ok(insertUpload.indexOf('lockActiveUploader(client, upload.uploadedBy)') < insertUpload.indexOf('INSERT INTO uploads'));
  const intent = storage.slice(storage.indexOf('export async function createUploadIntent'), storage.indexOf('export async function findUploadIntentForUpdate'));
  assert.ok(intent.indexOf('lockActiveUploader(client, intent.uploadedBy)') < intent.indexOf('INSERT INTO upload_intents'));
  const completion = storage.slice(storage.indexOf('export async function completeUploadAtomic'), storage.indexOf('export async function insertAudit'));
  assert.ok(completion.indexOf('lockActiveUploader(client, userId)') < completion.indexOf('SELECT * FROM upload_intents'));
  assert.match(storage, /error.code = 'ACCOUNT_INACTIVE'/);
});

test('account deletion route cleans transaction-selected uploads and pending presigned keys once', async () => {
  const { createAccountRoutes } = await import('../src/routes/account_routes.js');
  const previousDatabaseUrl = process.env.DATABASE_URL;
  process.env.DATABASE_URL = 'postgresql://route-test.invalid/unused';
  const deleted = {
    deleted: true,
    deletableUploadKeys: ['unreferenced-user-upload.pdf'],
    pendingUploadIntentKeys: ['pending-upload.pdf', 'unreferenced-user-upload.pdf'],
  };
  const deletedObjects = [];
  const auditFailures = [];
  try {
    const route = createAccountRoutes({
      authUser: async () => ({ id: 'user-1' }),
      readBody: async () => ({ confirmation: 'DELETE' }),
      sendJson: (_res, status, body) => ({ status, body }),
      HttpError: class HttpError extends Error {
        constructor(status, code, message) { super(message); this.status = status; this.code = code; }
      },
      hashPassword: async (value) => `hashed:${value}`,
      privacyRepo: {
        deleteUserPrivacyBundle: async (userId, replacement) => {
          assert.equal(userId, 'user-1');
          assert.equal(replacement.email, 'deleted+user-1@invalid.local');
          return deleted;
        },
        listDeletableUserUploadKeys: async () => { throw new Error('stale pre-transaction snapshot must not be used'); },
      },
      legacyAccount: {
        listDeletableUserUploadKeys: async () => { throw new Error('PostgreSQL path must not use legacy adapter'); },
        deleteUserPrivacyBundle: async () => { throw new Error('PostgreSQL path must use the repository transaction'); },
      },
      storage: {
        delete: async ({ key }) => {
          deletedObjects.push(key);
          if (key === 'pending-upload.pdf') throw new Error('simulated transient storage failure');
        },
      },
      anonymizedEmail: (id) => `deleted+${id}@invalid.local`,
      deletionCredential: () => 'one-time-deletion-credential',
      buildDataExport: () => ({}),
      logEvent: (event) => auditFailures.push(event),
    });
    const response = await route({ method: 'POST' }, {}, ['delete']);
    assert.equal(response.status, 200);
    assert.deepEqual(response.body, { deleted: true, privacyVersion: '1.1' });
    assert.deepEqual(deletedObjects.sort(), ['pending-upload.pdf', 'unreferenced-user-upload.pdf']);
    assert.equal(auditFailures.length, 1);
    assert.equal(auditFailures[0].action, 'ACCOUNT_UPLOAD_CLEANUP_FAILED');
    assert.equal(auditFailures[0].key, 'pending-upload.pdf');
  } finally {
    if (previousDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = previousDatabaseUrl;
  }
});
