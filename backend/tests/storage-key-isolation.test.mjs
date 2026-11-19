import test from 'node:test';
import assert from 'node:assert/strict';
import { createUploadObjectKey } from '../src/storage_key.js';

const id = '5d7e98e6-7c53-4f34-9330-532fd0435ee9';

test('S3 multipart and presigned uploads share the same isolated prefix', () => {
  assert.equal(createUploadObjectKey({ storageBackend: 's3', prefix: 'hope-staging', fileId: id, safeName: 'avatar.png' }), `hope-staging/${id}-avatar.png`);
});

test('local filesystem uploads keep flat keys and do not inherit the S3 prefix', () => {
  assert.equal(createUploadObjectKey({ storageBackend: 'local', prefix: 'hope-staging', fileId: id, safeName: 'avatar.png' }), `${id}-avatar.png`);
});

test('object key builder rejects path traversal and unsafe filename or prefix segments', () => {
  for (const patch of [
    { prefix: '../outside' },
    { prefix: 'hope-staging/../shared' },
    { prefix: '/hope-staging' },
    { safeName: '../avatar.png' },
    { safeName: 'avatar.png/../../other' },
    { fileId: '../fixed' },
  ]) {
    assert.throws(() => createUploadObjectKey({ storageBackend: 's3', prefix: 'hope-staging', fileId: id, safeName: 'avatar.png', ...patch }), /STORAGE_KEY_INVALID/);
  }
});


test('Multipart and presigned routes both use the shared object-key builder', async () => {
  const fs = await import('node:fs');
  const http = fs.readFileSync(new URL('../src/http.js', import.meta.url), 'utf8');
  const routes = fs.readFileSync(new URL('../src/routes/storage_routes.js', import.meta.url), 'utf8');
  assert.match(http, /createUploadObjectKey\(\{ storageBackend: config\.storageBackend, prefix: config\.s3Prefix/);
  assert.match(routes, /createUploadObjectKey\(\{ storageBackend: config\.storageBackend, prefix: config\.s3Prefix/);
});
