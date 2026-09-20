import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const storage = fs.readFileSync(new URL('../src/storage.js', import.meta.url), 'utf8');
const envExample = fs.readFileSync(new URL('../.env.example', import.meta.url), 'utf8');

test('Supabase S3 integration does not send unsupported PutObject SSE headers', () => {
  assert.match(storage, /function isSupabaseS3Endpoint\(/);
  assert.match(storage, /url\.hostname\.toLowerCase\(\)\.endsWith\('\.supabase\.co'\)/);
  assert.match(storage, /if \(isSupabaseS3Endpoint\(config\.s3Endpoint\)\) return undefined;/);
  assert.match(storage, /ServerSideEncryption:s3ServerSideEncryption\(\)/);
  assert.match(storage, /Supabase Storage's S3 PutObject API does not support x-amz-server-side-encryption/i);
});

test('Supabase S3 staging configuration is documented without credentials', () => {
  for (const marker of [
    'STORAGE_BACKEND=s3',
    'S3_BUCKET=v2hope-private',
    'S3_REGION=eu-west-1',
    'S3_ENDPOINT=https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3',
    'S3_FORCE_PATH_STYLE=true',
    'S3_SERVER_SIDE_ENCRYPTION=',
  ]) {
    assert.match(envExample, new RegExp(`^# ${marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'm'), marker);
  }
  assert.doesNotMatch(envExample, /^AWS_SECRET_ACCESS_KEY=[^\s#]+$/m);
});
