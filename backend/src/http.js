import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { toErrorEnvelope } from './api/error_envelope.js';
export { HttpError } from './api/http_error.js';
import { HttpError } from './api/http_error.js';
import { config } from './config.js';
import { db } from './db.js';

let activeUploadParsers = 0;
const uploadWaiters = [];
async function acquireUploadParser() {
  if (activeUploadParsers < config.maxConcurrentUploads && uploadWaiters.length === 0) {
    activeUploadParsers += 1;
    return;
  }
  // A queued waiter inherits the released slot; it must not increment the
  // counter a second time when it resumes.
  await new Promise((resolve) => uploadWaiters.push(resolve));
}
function releaseUploadParser() {
  const next = uploadWaiters.shift();
  if (next) {
    next();
    return;
  }
  activeUploadParsers = Math.max(0, activeUploadParsers - 1);
}
function setSecurityHeaders(res) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('X-Permitted-Cross-Domain-Policies', 'none');
  if (process.env.NODE_ENV === 'production') res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
}

export async function sendJson(res, status, data) {
  await db.flush();
  setSecurityHeaders(res);
  const body = JSON.stringify({ data });
  if (!res.getHeader('X-Request-Id')) res.setHeader('X-Request-Id', crypto.randomUUID());
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

export function sendRateLimited(res, code, message, retryAfterSeconds) {
  setSecurityHeaders(res);
  const body = JSON.stringify({ error: { code, message } });
  if (!res.getHeader('X-Request-Id')) res.setHeader('X-Request-Id', crypto.randomUUID());
  res.writeHead(429, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body), 'Retry-After': String(retryAfterSeconds), 'Cache-Control': 'no-store' });
  res.end(body);
}

export function sendError(res, error) {
  setSecurityHeaders(res);
  const intentionalStatus = Number.isInteger(error?.status) && error.status >= 400 && error.status <= 599;
  const status = error instanceof HttpError ? error.status : intentionalStatus ? error.status : 500;
  const code = error instanceof HttpError ? error.code : intentionalStatus && error?.code ? String(error.code) : 'INTERNAL_ERROR';
  const message = error instanceof HttpError ? error.message : intentionalStatus && error?.code ? String(error.message || error.code) : 'Internal server error';
  if (!res.getHeader('X-Request-Id')) res.setHeader('X-Request-Id', crypto.randomUUID());
  const body = JSON.stringify(toErrorEnvelope(
    { code, message, details: error?.details },
    { requestId: res.getHeader('X-Request-Id') },
  ));
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Content-Length': Buffer.byteLength(body), 'Cache-Control': 'no-store' });
  res.end(body);
}

export function setCors(res, req) {
  const origin = String(req.headers.origin || '');
  if (origin && (config.allowedCorsOrigins.includes('*') || config.allowedCorsOrigins.includes(origin) || process.env.NODE_ENV !== 'production' && config.allowedCorsOrigins.length === 0)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  res.setHeader('Vary', 'Origin');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('X-Permitted-Cross-Domain-Policies', 'none');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Idempotency-Key');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Max-Age', '86400');
}

export async function readRawBody(req, maxBytes = config.maxRequestBytes) {
  const chunks = []; let size = 0;
  const declaredLength = Number(req.headers['content-length']);
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) throw new HttpError(413, 'BODY_TOO_LARGE', 'Request body is too large');
  for await (const chunk of req) { size += chunk.length; if (size > maxBytes) throw new HttpError(413, 'BODY_TOO_LARGE', 'Request body is too large'); chunks.push(chunk); }
  return Buffer.concat(chunks);
}

export async function readBody(req, maxBytes = config.maxRequestBytes) {
  const chunks = [];
  let size = 0;
  const declaredLength = Number(req.headers['content-length']);
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) throw new HttpError(413, 'BODY_TOO_LARGE', 'Request body is too large');
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw new HttpError(413, 'BODY_TOO_LARGE', 'Request body is too large');
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks);
  if (!raw.length) return null;
  const type = String(req.headers['content-type'] || '');
  if (type.includes('application/json')) {
    try { return JSON.parse(raw.toString('utf8')); } catch { throw new HttpError(400, 'INVALID_JSON', 'Invalid JSON body'); }
  }
  // Every readBody caller is a JSON API route; multipart goes through
  // readMultipartSingleFile and webhooks through readRawBody. Rejecting
  // anything else closes a content-type smuggling / parser-confusion surface.
  throw new HttpError(415, 'UNSUPPORTED_MEDIA_TYPE', 'Content-Type must be application/json');
}

export async function readMultipartSingleFile(req) {
  const type = String(req.headers['content-type'] || '');
  const match = type.match(/boundary=(?:"([^"]+)"|([^;]+))/i);
  if (!match) throw new HttpError(400, 'INVALID_MULTIPART', 'Multipart boundary is missing');
  const boundary = Buffer.from(`--${match[1] || match[2]}`);
  const declaredLength = Number(req.headers['content-length']);
  if (Number.isFinite(declaredLength) && declaredLength > config.maxUploadBytes + 1024 * 1024) throw new HttpError(413, 'FILE_TOO_LARGE', 'File is too large');

  // Reserve capacity before creating the temporary file or consuming request
  // bytes. The slot travels with the result and is released by the route only
  // after storage persistence and cleanup have completed.
  await acquireUploadParser();
  let tempPath = null;
  let stream = null;
  let ownershipTransferred = false;
  let slotReleased = false;
  const release = () => {
    if (slotReleased) return;
    slotReleased = true;
    releaseUploadParser();
  };

  try {
    const tempName = `${crypto.randomUUID()}.upload`;
    await fs.promises.mkdir(config.storageDir, { recursive: true });
    tempPath = path.join(config.storageDir, `.incoming-${tempName}`);
    stream = fs.createWriteStream(tempPath, { flags: 'wx' });
    let size = 0;
    for await (const chunk of req) {
      size += chunk.length;
      if (size > config.maxUploadBytes + 1024 * 1024) {
        stream.destroy();
        throw new HttpError(413, 'FILE_TOO_LARGE', 'File is too large');
      }
      if (!stream.write(chunk)) {
        await new Promise((resolve, reject) => {
          stream.once('drain', resolve);
          stream.once('error', reject);
        });
      }
    }
    await new Promise((resolve, reject) => {
      stream.once('error', reject);
      stream.end(resolve);
    });

    const body = await fs.promises.readFile(tempPath);
    const start = body.indexOf(boundary);
    if (start < 0) throw new HttpError(400, 'INVALID_MULTIPART', 'Multipart payload is invalid');
    const headerStart = start + boundary.length + 2;
    const headerEnd = body.indexOf(Buffer.from('\r\n\r\n'), headerStart);
    if (headerEnd < 0) throw new HttpError(400, 'INVALID_MULTIPART', 'Multipart headers are invalid');
    const headersText = body.subarray(headerStart, headerEnd).toString('utf8');
    const disposition = headersText.match(/content-disposition:\s*form-data;\s*name="([^"]+)"(?:;\s*filename="([^"]*)")?/i);
    if (!disposition || disposition[1] !== 'file' || !disposition[2]) throw new HttpError(400, 'FILE_REQUIRED', 'A file field is required');
    const contentType = headersText.match(/content-type:\s*([^\r\n]+)/i)?.[1]?.trim() || 'application/octet-stream';
    const nextBoundary = body.indexOf(Buffer.from(`\r\n${boundary.toString('binary')}`), headerEnd + 4);
    if (nextBoundary < 0) throw new HttpError(400, 'INVALID_MULTIPART', 'Multipart terminator is missing');
    const content = body.subarray(headerEnd + 4, nextBoundary);
    if (!content.length) throw new HttpError(400, 'EMPTY_FILE', 'Uploaded file is empty');
    if (content.length > config.maxUploadBytes) throw new HttpError(413, 'FILE_TOO_LARGE', 'File is too large');
    const rawSafeName = path.basename(disposition[2]).replace(/[^a-zA-Z0-9._-]/g, '_');
    const rawExtension = path.extname(rawSafeName);
    // Bound the filename/key length while preserving the extension needed for
    // allowlist inference and route-level MIME/extension consistency checks.
    const safeName = rawSafeName.length <= 180
      ? rawSafeName
      : `${path.basename(rawSafeName, rawExtension).slice(0, 180 - rawExtension.length)}${rawExtension}`;
    const extension = path.extname(safeName).toLowerCase();
    const inferredType = new Map([
      ['.pdf', 'application/pdf'],
      ['.png', 'image/png'],
      ['.jpg', 'image/jpeg'],
      ['.jpeg', 'image/jpeg'],
      ['.webp', 'image/webp'],
      ['.txt', 'text/plain'],
      ['.text', 'text/plain'],
      ['.log', 'text/plain'],
      ['.m4a', 'audio/mp4'],
      ['.mp4', 'audio/mp4'],
      ['.mp3', 'audio/mpeg'],
      ['.wav', 'audio/wav'],
      ['.wave', 'audio/wav'],
    ]).get(extension);
    const incomingType = contentType.trim().toLowerCase();
    // Some multipart clients report application/octet-stream even when the
    // file extension identifies a supported upload. Infer only from this
    // fixed allowlist; content signatures below still have to match.
    const declaredType = (incomingType === '' || incomingType === 'application/octet-stream')
      ? (inferredType || incomingType)
      : incomingType;
    const mp3Frame = content.length >= 2 && content[0] === 0xff &&
      (content[1] & 0xe0) === 0xe0 && (content[1] & 0x18) !== 0x08;
    const signatureOk = (declaredType === 'application/pdf' && content.subarray(0, 4).toString() === '%PDF') ||
      (declaredType === 'image/png' && content.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) ||
      (declaredType === 'image/jpeg' && content.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) ||
      (declaredType === 'image/webp' && content.subarray(0, 4).toString() === 'RIFF' && content.subarray(8, 12).toString() === 'WEBP') ||
      (declaredType === 'text/plain' && !content.subarray(0, 4096).includes(0)) ||
      (declaredType === 'audio/mp4' && content.length >= 12 && content.subarray(4, 8).toString() === 'ftyp') ||
      (declaredType === 'audio/mpeg' && (content.subarray(0, 3).toString() === 'ID3' || mp3Frame)) ||
      (declaredType === 'audio/wav' && content.length >= 12 &&
        content.subarray(0, 4).toString() === 'RIFF' && content.subarray(8, 12).toString() === 'WAVE');
    if (!['application/pdf', 'image/png', 'image/jpeg', 'image/webp', 'text/plain', 'audio/mp4', 'audio/mpeg', 'audio/wav'].includes(declaredType) || !signatureOk) {
      throw new HttpError(415, 'UNSUPPORTED_FILE', 'Unsupported or invalid file content');
    }
    const key = `${crypto.randomUUID()}-${safeName}`;
    // Reuse the already-created temp file for the extracted payload. This is
    // important: the object storage layer must receive the file bytes, not the
    // surrounding multipart envelope.
    await fs.promises.writeFile(tempPath, content);
    ownershipTransferred = true;
    return { key, filename: safeName, contentType: declaredType, size: content.length, path: tempPath, release };
  } catch (error) {
    if (stream) stream.destroy();
    if (tempPath) {
      try { await fs.promises.unlink(tempPath); } catch {}
    }
    throw error;
  } finally {
    if (!ownershipTransferred) release();
  }
}