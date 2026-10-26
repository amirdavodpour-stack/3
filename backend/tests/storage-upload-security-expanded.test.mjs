import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { makeTempEnv, startApiServer, register, closeApi } from './support/hope-test-harness.mjs';

const tmp = makeTempEnv('hope-storage-delta-');
process.env.MAX_CONCURRENT_UPLOADS = '1';
const api = await startApiServer();

function auth(token) { return {Authorization: `Bearer ${token}`}; }

async function multipartUpload(token, {filename, contentType, content}) {
  const boundary = '----hope-test-boundary';
  const payload = Buffer.concat([
    Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${filename}"\r\nContent-Type: ${contentType}\r\n\r\n`),
    Buffer.from(content),
    Buffer.from(`\r\n--${boundary}--\r\n`),
  ]);
  const response = await fetch(api.base + '/storage/upload', {
    method: 'POST',
    headers: {...auth(token), 'content-type': `multipart/form-data; boundary=${boundary}`},
    body: payload,
  });
  return {response, body: await response.json().catch(() => null)};
}

test('valid PDF upload is content-sniffed, stored, and associated with the uploader', async () => {
  const user = await register(api.json, 'storage-pdf@example.com');
  const {response, body} = await multipartUpload(user.accessToken, {
    filename: '../../resume.pdf',
    contentType: 'application/pdf',
    content: '%PDF-1.7\nhello world',
  });
  assert.equal(response.status, 201);
  assert.equal(body.data.contentType, 'application/pdf');
  assert.ok(body.data.key.endsWith('-resume.pdf'));
  assert.equal(body.data.uploadedBy, user.user.id);
  const storedPath = path.join(process.env.STORAGE_DIR, body.data.key);
  assert.equal(fs.existsSync(storedPath), true);
  assert.equal(api.db.collection.uploads.some((x) => x.storageKey === body.data.key && x.uploadedBy === user.user.id), true);
});

test('multipart upload bounds long sanitized filenames while preserving the content extension', async () => {
  const user = await register(api.json, 'storage-long-name@example.com');
  const filename = `${'transcript'.repeat(45)}.pdf`;
  const {response, body} = await multipartUpload(user.accessToken, {
    filename,
    contentType: 'application/pdf',
    content: '%PDF-1.7\\nsmall valid test document',
  });
  assert.equal(response.status, 201);
  assert.ok(body.data.filename.length <= 180);
  assert.ok(body.data.filename.endsWith('.pdf'));
  assert.ok(body.data.key.length <= 217);
});

test('spoofed image MIME with non-image bytes is rejected by signature validation', async () => {
  const user = await register(api.json, 'storage-spoof@example.com');
  const {response, body} = await multipartUpload(user.accessToken, {
    filename: 'picture.png',
    contentType: 'image/png',
    content: 'definitely-not-a-png',
  });
  assert.equal(response.status, 415);
  assert.equal(body.error.code, 'UNSUPPORTED_FILE');
});

test('empty multipart file is rejected and leaves no upload record', async () => {
  const user = await register(api.json, 'storage-empty@example.com');
  const {response, body} = await multipartUpload(user.accessToken, {
    filename: 'empty.txt',
    contentType: 'text/plain',
    content: '',
  });
  assert.equal(response.status, 400);
  assert.equal(body.error.code, 'EMPTY_FILE');
  assert.equal(api.db.collection.uploads.some((x) => x.uploadedBy === user.user.id), false);
});

test('presign never silently falls back to local storage', async () => {
  const user = await register(api.json, 'storage-presign@example.com');
  const r = await api.json('/storage/presign', {
    method: 'POST',
    headers: auth(user.accessToken),
    body: JSON.stringify({filename: 'x.pdf', contentType: 'application/pdf'}),
  });
  assert.equal(r.status, 409);
  assert.equal(r.body.error.code, 'DIRECT_UPLOAD_UNSUPPORTED');
});

test('upload endpoint requires authentication before touching the multipart body', async () => {
  const {response, body} = await multipartUpload('', {
    filename: 'unauth.pdf',
    contentType: 'application/pdf',
    content: '%PDF-1.7',
  });
  assert.equal(response.status, 401);
  assert.equal(body.error.code, 'UNAUTHORIZED');
});

test('voice-note and audio uploads pass the multipart signature gate', async () => {
  const user = await register(api.json, 'storage-chat-audio@example.com');
  const examples = [
    {
      filename: 'voice.m4a',
      contentType: 'audio/mp4',
      expectedType: 'audio/mp4',
      content: Buffer.from([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x4d, 0x34, 0x41, 0x20, 0, 0, 2, 0, 0x4d, 0x34, 0x41, 0x20, 0x69, 0x73, 0x6f, 0x6d]),
    },
    {
      filename: 'voice-multipart-default.m4a',
      contentType: 'application/octet-stream',
      expectedType: 'audio/mp4',
      content: Buffer.from([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x4d, 0x34, 0x41, 0x20, 0, 0, 2, 0, 0x4d, 0x34, 0x41, 0x20, 0x69, 0x73, 0x6f, 0x6d]),
    },
    {
      filename: 'voice.mp3',
      contentType: 'audio/mpeg',
      expectedType: 'audio/mpeg',
      content: Buffer.from([0x49, 0x44, 0x33, 0x04, 0, 0, 0, 0, 0, 0, 0x61, 0x75, 0x64, 0x69, 0x6f]),
    },
    {
      filename: 'voice.wav',
      contentType: 'audio/wav',
      expectedType: 'audio/wav',
      content: Buffer.from([0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20]),
    },
  ];

  for (const example of examples) {
    const {response, body} = await multipartUpload(user.accessToken, example);
    assert.equal(response.status, 201, example.filename);
    assert.equal(body.data.contentType, example.expectedType, example.filename);
    assert.equal(body.data.uploadedBy, user.user.id, example.filename);
  }
});

test('audio upload rejects bytes that do not match the declared audio container', async () => {
  const user = await register(api.json, 'storage-chat-audio-spoof@example.com');
  const {response, body} = await multipartUpload(user.accessToken, {
    filename: 'voice.m4a',
    contentType: 'audio/mp4',
    content: 'not-an-mp4-container',
  });
  assert.equal(response.status, 415);
  assert.equal(body.error.code, 'UNSUPPORTED_FILE');
  assert.equal(api.db.collection.uploads.some((x) => x.uploadedBy === user.user.id), false);
});


test('concurrent multipart body ingestion respects MAX_CONCURRENT_UPLOADS before spooling to disk', async () => {
  const user = await register(api.json, 'storage-concurrency@example.com');
  let receivedUploads = 0;
  const observeRequest = (req) => {
    if (req.url?.endsWith('/storage/upload')) receivedUploads += 1;
  };
  api.server.on('request', observeRequest);

  const incomingCount = () => fs.readdirSync(process.env.STORAGE_DIR)
    .filter((name) => name.startsWith('.incoming-')).length;
  const waitUntil = async (predicate, timeoutMs = 2500) => {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
      if (predicate()) return true;
      await new Promise((resolve) => setTimeout(resolve, 10));
    }
    return predicate();
  };
  const beginPartialUpload = (filename) => {
    const boundary = '----hope-concurrent-upload';
    const prefix = Buffer.from(
      `--${boundary}\\r\\nContent-Disposition: form-data; name="file"; filename="${filename}"\\r\\nContent-Type: application/pdf\\r\\n\\r\\n%PDF-1.7\\nconcurrency test`,
    );
    const ending = Buffer.from(`\\r\\n--${boundary}--\\r\\n`);
    let ended = false;
    let resolveResponse;
    let rejectResponse;
    const response = new Promise((resolve, reject) => {
      resolveResponse = resolve;
      rejectResponse = reject;
    });
    const request = http.request(`${api.base}/storage/upload`, {
      method: 'POST',
      headers: {
        ...auth(user.accessToken),
        'content-type': `multipart/form-data; boundary=${boundary}`,
        'content-length': prefix.length + ending.length,
      },
    });
    request.on('error', rejectResponse);
    request.on('response', (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolveResponse({
        status: res.statusCode,
        body: Buffer.concat(chunks).toString('utf8'),
      }));
    });
    request.write(prefix);
    return {
      request,
      response,
      finish() {
        if (ended) return;
        ended = true;
        request.end(ending);
      },
    };
  };

  let first;
  let second;
  try {
    first = beginPartialUpload('first.pdf');
    assert.equal(await waitUntil(() => receivedUploads >= 1 && incomingCount() === 1), true,
      'first incomplete request should have one incoming file');
    second = beginPartialUpload('second.pdf');
    assert.equal(await waitUntil(() => receivedUploads >= 2), true,
      'server should have received the second incomplete request');
    await new Promise((resolve) => setTimeout(resolve, 150));

    assert.equal(
      incomingCount(),
      1,
      'only one request may spool a multipart body when MAX_CONCURRENT_UPLOADS=1',
    );

    first.finish();
    const firstResult = await first.response;
    assert.equal(firstResult.status, 201, firstResult.body);
    second.finish();
    const secondResult = await second.response;
    assert.equal(secondResult.status, 201, secondResult.body);
  } finally {
    first?.finish();
    second?.finish();
    await first?.response.catch(() => {});
    await second?.response.catch(() => {});
    api.server.off('request', observeRequest);
  }
});

after(async () => closeApi({...api, tmp}));