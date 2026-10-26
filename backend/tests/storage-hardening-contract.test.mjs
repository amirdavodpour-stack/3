import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const root = new URL('../', import.meta.url);
const read = (file) => fs.readFileSync(new URL(file, root), 'utf8');
const storageRoutes = read('src/routes/storage_routes.js');
const http = read('src/http.js');
const storageRepository = read('src/repository/storage.js');
const cleanupWorker = read('src/storage_cleanup_worker.js');
const server = read('src/server.js');
const config = read('src/config.js');
const envExample = read('.env.example');
const liveWorkflow = read('../.github/workflows/supabase-storage-live.yml');
const rlsIntegration = read('tests/supabase-storage-rls.test.mjs');

for (const name of ['application/pdf', 'image/png', 'image/jpeg', 'image/webp', 'text/plain', 'audio/mp4', 'audio/mpeg', 'audio/wav']) {
  test(`storage route allows declared MIME type: ${name}`, () => {
    assert.match(storageRoutes, new RegExp(name.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')));
  });
}

test('multipart parser validates audio signatures and infers MIME only from an allowlisted filename extension', () => {
  assert.match(http, /\['\.m4a', 'audio\/mp4'\]/);
  assert.match(http, /\['\.mp3', 'audio\/mpeg'\]/);
  assert.match(http, /\['\.wav', 'audio\/wav'\]/);
  assert.match(http, /incomingType === 'application\/octet-stream'/);
  assert.match(http, /content\.subarray\(4, 8\)\.toString\(\) === 'ftyp'/);
  assert.match(http, /content\.subarray\(0, 3\)\.toString\(\) === 'ID3'/);
  assert.match(http, /content\.subarray\(8, 12\)\.toString\(\) === 'WAVE'/);
});

test('storage routes enforce filename/content-type consistency and bounded presigned intents', () => {
  assert.match(storageRoutes, /validateFilenameForContentType/);
  assert.match(storageRoutes, /FILENAME_TYPE_MISMATCH/);
  assert.match(storageRoutes, /config\.uploadIntentTtlSeconds/);
  assert.match(storageRoutes, /FILE_TOO_LARGE/);
  assert.match(storageRoutes, /CONTENT_TYPE_MISMATCH/);
  assert.match(storageRoutes, /storage\.validateObject/);
});

test('S3 presigned uploads are single-write and expose the required conditional header', async () => {
  const names = [
    'STORAGE_BACKEND', 'S3_BUCKET', 'S3_REGION', 'S3_ENDPOINT', 'S3_PREFIX',
    'S3_FORCE_PATH_STYLE', 'S3_SERVER_SIDE_ENCRYPTION',
    'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN',
    'AWS_REGION', 'AWS_EC2_METADATA_DISABLED',
  ];
  const previous = Object.fromEntries(names.map((name) => [name, process.env[name]]));
  Object.assign(process.env, {
    STORAGE_BACKEND: 's3',
    S3_BUCKET: 'hope-presign-regression-test',
    S3_REGION: 'us-east-1',
    S3_ENDPOINT: '',
    S3_PREFIX: 'uploads',
    S3_FORCE_PATH_STYLE: 'false',
    AWS_ACCESS_KEY_ID: 'test-access-key',
    AWS_SECRET_ACCESS_KEY: 'test-secret-key',
    AWS_EC2_METADATA_DISABLED: 'true',
  });
  delete process.env.S3_SERVER_SIDE_ENCRYPTION;
  delete process.env.AWS_SESSION_TOKEN;
  delete process.env.AWS_REGION;

  try {
    const { storage } = await import(`../src/storage.js?presign-regression-${Date.now()}`);
    const presigned = await storage.presignPut({
      key: 'uploads/regression.pdf',
      contentType: 'application/pdf',
      expiresIn: 300,
    });
    const signedHeaders = new URL(presigned.url).searchParams
      .get('X-Amz-SignedHeaders')?.split(';') ?? [];
    assert.ok(
      signedHeaders.includes('if-none-match'),
      'the signed PUT must reject a second write to the same object key',
    );
    assert.deepEqual(presigned.requiredHeaders, {'If-None-Match': '*'});
  } finally {
    for (const name of names) {
      if (previous[name] === undefined) delete process.env[name];
      else process.env[name] = previous[name];
    }
  }
});

test('OpenAPI documents the single-write presigned PUT requirement', () => {
  assert.match(read('openapi/openapi.yaml'), /requiredHeaders/);
  assert.match(read('openapi/openapi.yaml'), /If-None-Match: \\*/);
  assert.match(read('openapi/openapi.yaml'), /single-write/);
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
    '# S3_BUCKET=v2hope-private',
  ]) {
    assert.match(envExample, new RegExp(`^${marker.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}$`, 'm'));
  }
});

test('application upload path remains private-by-default and not public-bucket directed', () => {
  assert.match(envExample, /Do not point S3_BUCKET at v2hope-public/);
  assert.match(envExample, /v2hope-private = private application uploads/);
});

test('Supabase live S3 certification stays isolated from the Railway application database', () => {
  assert.doesNotMatch(liveWorkflow, /STAGING_DATABASE_URL|SUPABASE_STORAGE_RLS_INTEGRATION|DATABASE_URL:/);
  assert.match(rlsIntegration, /SUPABASE_STORAGE_DATABASE_URL/);
  assert.doesNotMatch(rlsIntegration, /delete from storage\.objects/);
  assert.match(rlsIntegration, /v2hope_private_delete_own_objects/);
});
