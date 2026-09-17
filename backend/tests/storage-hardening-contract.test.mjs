import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../', import.meta.url);
const read = (file) => fs.readFileSync(new URL(file, root), 'utf8');
const storageRoutes = read('src/routes/storage_routes.js');
const storageRepository = read('src/repository/storage.js');
const cleanupWorker = read('src/storage_cleanup_worker.js');
const server = read('src/server.js');
const config = read('src/config.js');
const envExample = read('.env.example');

for (const name of ['application/pdf', 'image/png', 'image/jpeg', 'image/webp', 'text/plain']) {
  test(`storage route allows declared MIME type: ${name}`, () => {
    assert.match(storageRoutes, new RegExp(name.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')));
  });
}

test('storage routes enforce filename/content-type consistency and bounded presigned intents', () => {
  assert.match(storageRoutes, /validateFilenameForContentType/);
  assert.match(storageRoutes, /FILENAME_TYPE_MISMATCH/);
  assert.match(storageRoutes, /config\.uploadIntentTtlSeconds/);
  assert.match(storageRoutes, /FILE_TOO_LARGE/);
  assert.match(storageRoutes, /CONTENT_TYPE_MISMATCH/);
  assert.match(storageRoutes, /storage\.validateObject/);
});

test('storage repository exposes safe expired-intent cleanup primitives', () => {
  assert.match(storageRepository, /listExpiredUploadIntents/);
  assert.match(storageRepository, /deleteUploadIntents/);
  assert.match(storageRepository, /expires_at < \$1/);
  assert.match(storageRepository, /ANY\(\$1::uuid\[\]\)/);
});

test('storage cleanup worker deletes the object before deleting its DB intent', () => {
  assert.match(cleanupWorker, /listExpiredUploadIntents/);
  assert.match(cleanupWorker, /await storageBackend\.delete\(\{ key: intent\.storageKey \}\)/);
  assert.match(cleanupWorker, /cleanedIds\.push\(intent\.id\)/);
  assert.match(cleanupWorker, /deleteUploadIntents\(cleanedIds\)/);
});

test('storage cleanup worker is database-gated and bounded by configuration', () => {
  assert.match(cleanupWorker, /if \(!process\.env\.DATABASE_URL\) return/);
  assert.match(cleanupWorker, /graceSeconds = config\.uploadOrphanGraceSeconds/);
  assert.match(cleanupWorker, /limit = config\.uploadCleanupBatchSize/);
  assert.match(cleanupWorker, /config\.uploadCleanupIntervalMs/);
});

test('server starts and stops the storage cleanup worker', () => {
  assert.match(server, /startStorageCleanupWorker/);
  assert.match(server, /storageCleanupWorker\.stop\(\)/);
});

test('storage cleanup settings are bounded and documented', () => {
  assert.match(config, /uploadOrphanGraceSeconds/);
  assert.match(config, /uploadCleanupIntervalMs/);
  assert.match(config, /uploadCleanupBatchSize/);
  for (const marker of [
    'UPLOAD_ORPHAN_GRACE_SECONDS=3600',
    'UPLOAD_CLEANUP_INTERVAL_MS=900000',
    'UPLOAD_CLEANUP_BATCH_SIZE=100',
    'S3_BUCKET=v2hope-private',
  ]) {
    assert.match(envExample, new RegExp(`^${marker.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}$`, 'm'));
  }
});

test('application upload path remains private-by-default and not public-bucket directed', () => {
  assert.match(envExample, /Do not point S3_BUCKET at v2hope-public/);
  assert.match(envExample, /v2hope-private = private application uploads/);
});
