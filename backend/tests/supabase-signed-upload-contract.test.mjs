import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { createSupabaseSignedUpload } from '../src/storage.js';

const serviceKey = 'test-only-supabase-server-side-key-with-more-than-32-bytes';
const endpoint = 'https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3';
const key = `uploads/${crypto.randomUUID()}-avatar.png`;

test('Supabase native signed upload creates an upsert=false URL and never permits overwrite', async () => {
  let captured;
  const result = await createSupabaseSignedUpload({
    endpoint,
    bucket: 'v2hope-private',
    key,
    contentType: 'image/png',
    serviceKey,
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return {
        ok: true,
        status: 200,
        json: async () => ({ url: `/object/upload/sign/v2hope-private/${key}?token=signed-once-token` }),
      };
    },
  });

  assert.equal(captured.url, `https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/object/upload/sign/v2hope-private/${key}`);
  assert.equal(captured.options.method, 'POST');
  assert.equal(captured.options.redirect, 'manual');
  assert.equal(captured.options.headers.apikey, serviceKey);
  assert.equal(captured.options.headers.authorization, `Bearer ${serviceKey}`);
  assert.deepEqual(JSON.parse(captured.options.body), {});
  assert.equal(captured.options.headers['x-upsert'], undefined);
  assert.equal(result.url, `https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/object/upload/sign/v2hope-private/${key}?token=signed-once-token`);
  assert.equal(result.mode, 'supabase-signed');
  assert.equal(result.expiresIn, 7200);
  assert.deepEqual(result.requiredHeaders, { 'x-upsert': 'false', 'Content-Type': 'image/png' });
});

test('Supabase native signed upload rejects cross-origin or malformed signed URLs', async () => {
  const invalidPayloads = [
    { url: 'https://evil.example/object/upload/sign/bucket/key?token=stolen', token: 'stolen' },
    { url: '/object/upload/sign/v2hope-private/key?token=wrong' },
    { url: '/object/upload/sign/v2hope-private/key' },
    { url: '/object/other/v2hope-private/key?token=valid', token: 'valid' },
    { url: '/object/upload/sign/v2hope-public/key?token=valid', token: 'valid' },
    { url: '/object/upload/sign/v2hope-private/key', token: 'valid' },
  ];
  for (const payload of invalidPayloads) {
    await assert.rejects(
      () => createSupabaseSignedUpload({ endpoint, bucket: 'v2hope-private', key, contentType: 'image/png', serviceKey, fetchImpl: async () => ({ ok: true, json: async () => payload }) }),
      /SUPABASE_SIGNED_UPLOAD_INVALID_RESPONSE/,
    );
  }
});

test('Supabase native signed upload fails closed on unsafe configuration and upstream errors', async () => {
  await assert.rejects(() => createSupabaseSignedUpload({ endpoint: 'http://example.com/storage/v1/s3', bucket: 'v2hope-private', key, contentType: 'image/png', serviceKey }), /SUPABASE_SIGNED_UPLOAD_CONFIG_INVALID/);
  await assert.rejects(() => createSupabaseSignedUpload({ endpoint, bucket: 'v2hope-public', key, contentType: 'image/png', serviceKey }), /SUPABASE_SIGNED_UPLOAD_CONFIG_INVALID/);
  await assert.rejects(() => createSupabaseSignedUpload({ endpoint, bucket: 'v2hope-private', key: '../other/key', contentType: 'image/png', serviceKey }), /SUPABASE_SIGNED_UPLOAD_CONFIG_INVALID/);
  await assert.rejects(() => createSupabaseSignedUpload({ endpoint, bucket: 'v2hope-private', key, contentType: 'image/png', serviceKey: 'short' }), /SUPABASE_SIGNED_UPLOAD_CONFIG_INVALID/);
  await assert.rejects(() => createSupabaseSignedUpload({ endpoint, bucket: 'v2hope-private', key, contentType: 'image/png', serviceKey, fetchImpl: async () => ({ ok: false, status: 403 }) }), /SUPABASE_SIGNED_UPLOAD_FAILED/);
});
