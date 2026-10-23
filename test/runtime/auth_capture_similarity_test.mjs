import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const validator = join(root, 'tools/validate-auth-capture-pair.mjs');
const temp = mkdtempSync(join(tmpdir(), 'hope-auth-capture-test-'));

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const typeBytes = Buffer.from(type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([typeBytes, data])));
  return Buffer.concat([length, typeBytes, data, checksum]);
}

function paeth(left, above, upperLeft) {
  const p = left + above - upperLeft;
  const dl = Math.abs(p - left);
  const da = Math.abs(p - above);
  const du = Math.abs(p - upperLeft);
  if (dl <= da && dl <= du) return left;
  if (da <= du) return above;
  return upperLeft;
}

function createPng(width, height, pixelAt) {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 6; // Match Android PixelCopy PNGs: 8-bit RGBA.
  header[10] = 0;
  header[11] = 0;
  header[12] = 0;
  const rows = [];
  const channels = 4;
  const stride = width * channels;
  let previous = Buffer.alloc(stride);

  for (let y = 0; y < height; y += 1) {
    const raw = Buffer.alloc(stride);
    for (let x = 0; x < width; x += 1) {
      const rgb = pixelAt(x, y);
      const i = x * channels;
      raw[i] = rgb[0];
      raw[i + 1] = rgb[1];
      raw[i + 2] = rgb[2];
      raw[i + 3] = 255;
    }

    // Exercise all PNG scanline filters used by real screenshot encoders.
    const filter = y % 5;
    const row = Buffer.alloc(1 + stride);
    row[0] = filter;
    for (let i = 0; i < stride; i += 1) {
      const left = i >= channels ? raw[i - channels] : 0;
      const above = previous[i];
      const upperLeft = i >= channels ? previous[i - channels] : 0;
      let predictor = 0;
      if (filter === 1) predictor = left;
      else if (filter === 2) predictor = above;
      else if (filter === 3) predictor = Math.floor((left + above) / 2);
      else if (filter === 4) predictor = paeth(left, above, upperLeft);
      row[i + 1] = (raw[i] - predictor + 256) & 0xff;
    }
    rows.push(row);
    previous = raw;
  }
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(Buffer.concat(rows))),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function runPair(registerPath, resetPath) {
  return spawnSync(process.execPath, [validator, registerPath, resetPath], {
    encoding: 'utf8',
    timeout: 5000,
  });
}

try {
  mkdirSync(temp, { recursive: true });
  const width = 64;
  const height = 48;
  const base = (x, y) => ((x < 32 && y < 24) ? [28, 45, 62] : [244, 242, 236]);
  const registerPath = join(temp, 'register.png');
  const nearResetPath = join(temp, 'password-reset-near-duplicate.png');
  const distinctResetPath = join(temp, 'password-reset-distinct.png');
  const wrongSizePath = join(temp, 'password-reset-wrong-size.png');

  writeFileSync(registerPath, createPng(width, height, base));
  writeFileSync(nearResetPath, createPng(width, height, (x, y) => {
    if (x >= 10 && x < 12 && y >= 10 && y < 12) return [250, 10, 10];
    return base(x, y);
  }));
  writeFileSync(distinctResetPath, createPng(width, height, () => [18, 132, 76]));
  writeFileSync(wrongSizePath, createPng(width + 1, height, () => [18, 132, 76]));

  const near = runPair(registerPath, nearResetPath);
  assert.notEqual(near.status, 0, 'near-duplicate Register/Password Reset images must fail validation');
  assert.match(near.stdout + '\n' + near.stderr, /near[- ]duplicate/i,
    'failure must clearly identify a near-duplicate auth-capture pair');

  const distinct = runPair(registerPath, distinctResetPath);
  assert.equal(distinct.status, 0,
    'visually distinct auth captures should pass: ' + distinct.stdout + '\n' + distinct.stderr);
  assert.match(distinct.stdout, /PASS/i, 'successful validation must print a PASS receipt');

  const wrongSize = runPair(registerPath, wrongSizePath);
  assert.notEqual(wrongSize.status, 0, 'auth image dimensions must match before pair comparison');

  console.log('PASS: auth capture similarity regression (near-duplicate rejected; distinct pair accepted; mismatched dimensions rejected)');
} finally {
  rmSync(temp, { recursive: true, force: true });
}

[executed on device: localhost (ad4940fb-3108-4ab5-af41-ee34669dd70c)]