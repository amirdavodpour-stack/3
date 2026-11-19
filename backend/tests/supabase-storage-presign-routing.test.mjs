import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const endpoint = 'https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/s3';
const moduleUrl = new URL('../src/storage.js', import.meta.url).href;

test('Supabase S3 storage backend routes presign through the native one-time signed upload API', () => {
  const source = `
    let captured;
    globalThis.fetch = async (url, options) => {
      captured = { url, options };
      return { ok: true, status: 200, json: async () => ({
        url: '/object/upload/sign/v2hope-private/uploads/test.png?token=one-time-token',
      }) };
    };
    const { storage } = await import(${JSON.stringify(moduleUrl)});
    const result = await storage.presignPut({ key: 'uploads/test.png', contentType: 'image/png', expiresIn: 300 });
    if (captured.url !== ${JSON.stringify('https://oumueyftltvakimtbemj.storage.supabase.co/storage/v1/object/upload/sign/v2hope-private/uploads/test.png')}) throw new Error('WRONG_SIGN_ENDPOINT');
    if (captured.options.method !== 'POST') throw new Error('WRONG_SIGN_METHOD');
    if (JSON.stringify(JSON.parse(captured.options.body)) !== JSON.stringify({})) throw new Error('UPSERT_NOT_DISABLED');
    if (result.mode !== 'supabase-signed' || result.intentExpiresIn !== 300 || result.expiresIn !== 7200) throw new Error('WRONG_UPLOAD_LIFETIME');
    if (result.requiredHeaders['x-upsert'] !== 'false') throw new Error('UPSERT_HEADER_MISSING');
    console.log('SUPABASE_PRESIGN_ROUTING_PASS');
  `;
  const result = spawnSync(process.execPath, ['--input-type=module', '-e', source], {
    env: {
      ...process.env,
      NODE_ENV: 'test',
      STORAGE_BACKEND: 's3',
      S3_BUCKET: 'v2hope-private',
      S3_REGION: 'eu-west-1',
      S3_ENDPOINT: endpoint,
      S3_FORCE_PATH_STYLE: 'true',
      AWS_ACCESS_KEY_ID: 'local-test-s3-access-key',
      AWS_SECRET_ACCESS_KEY: 'local-test-s3-secret-key',
      SUPABASE_SERVICE_ROLE_KEY: 'local-test-service-role-key-with-at-least-32-bytes',
    },
    encoding: 'utf8',
    timeout: 10000,
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /SUPABASE_PRESIGN_ROUTING_PASS/);
});
