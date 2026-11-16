const MAX_BODY_BYTES = 32 * 1024;
const MAX_CLOCK_SKEW_SECONDS = 300;
const NONCE_TTL_SECONDS = 600;
const MAX_DAILY_READS = 4_000_000;
const MAX_DAILY_REQUEST_WRITES = 60_000;
const MAX_DAILY_CLEANUP_WRITES = 25_000;
const MAX_CLEANUP_BATCH = 5_000;
const SOURCE_ID = 'hope-api';
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EVENT_TYPE_PATTERN = /^[A-Z][A-Z0-9_]{1,63}$/;
const NONCE_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const SIGNATURE_PATTERN = /^v1=([0-9a-f]{64})$/i;
const D1_QUOTA_ERROR = /exceeded D1's free tier daily row (?:read|write) limit|exceeded D1's maximum account storage limit|exceeded maximum DB size/i;
const JSON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
  'x-content-type-options': 'nosniff',
};

function json(status, value) {
  return new Response(JSON.stringify(value), { status, headers: JSON_HEADERS });
}

function storageErrorResponse(error) {
  return D1_QUOTA_ERROR.test(String(error?.message || error))
    ? json(429, { error: 'QUOTA_BLOCKED' })
    : json(503, { error: 'STORAGE_UNAVAILABLE' });
}

function canonicalMessage({ timestamp, nonce, source, method, host, path, rawBody }) {
  return `${timestamp}\n${nonce}\n${source}\n${method}\n${host}\n${path}\n${rawBody}`;
}

function decodeHex(hex) {
  if (!/^(?:[0-9a-f]{2})+$/i.test(hex)) return null;
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i += 1) bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return bytes;
}

async function verifyRequest(request, env, { rawBody, nowSeconds, secretName = 'HOPE_INGEST_HMAC_SECRET' }) {
  const timestamp = request.headers.get('x-hope-timestamp') || '';
  const nonce = request.headers.get('x-hope-nonce') || '';
  const source = request.headers.get('x-hope-source') || '';
  const signatureHeader = request.headers.get('x-hope-signature') || '';
  const signatureMatch = SIGNATURE_PATTERN.exec(signatureHeader);

  if (!/^\d{10}$/.test(timestamp) || !Number.isSafeInteger(Number(timestamp))) {
    return { ok: false, response: json(401, { error: 'AUTH_INVALID' }) };
  }
  if (Math.abs(nowSeconds - Number(timestamp)) > MAX_CLOCK_SKEW_SECONDS) {
    return { ok: false, response: json(401, { error: 'AUTH_EXPIRED' }) };
  }
  if (!NONCE_PATTERN.test(nonce) || source !== SOURCE_ID || !signatureMatch) {
    return { ok: false, response: json(401, { error: 'AUTH_INVALID' }) };
  }
  if (typeof env[secretName] !== 'string' || new TextEncoder().encode(env[secretName]).byteLength < 32) {
    return { ok: false, response: json(503, { error: 'AUTH_NOT_CONFIGURED' }) };
  }

  try {
    // Verification-only key: the Worker must never sign on behalf of HOPE.
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(env[secretName]),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    const signature = decodeHex(signatureMatch[1]);
    const message = new TextEncoder().encode(canonicalMessage({
      timestamp,
      nonce,
      source,
      method: request.method.toUpperCase(),
      host: new URL(request.url).host,
      path: new URL(request.url).pathname,
      rawBody,
    }));
    const valid = signature && await crypto.subtle.verify('HMAC', key, signature, message);
    if (!valid) return { ok: false, response: json(401, { error: 'AUTH_INVALID' }) };
  } catch {
    return { ok: false, response: json(503, { error: 'AUTH_UNAVAILABLE' }) };
  }

  return { ok: true, source, nonce, timestamp: Number(timestamp) };
}

function validateEvent(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return 'EVENT_INVALID';
  const allowed = new Set(['schemaVersion', 'eventId', 'source', 'severity', 'eventType', 'occurredAt', 'pagerDutyIncidentId']);
  if (Object.keys(value).some((key) => !allowed.has(key))) return 'EVENT_UNKNOWN_FIELD';
  if (value.schemaVersion !== 1 || !UUID_PATTERN.test(String(value.eventId || '')) || value.source !== SOURCE_ID) return 'EVENT_INVALID';
  if (!['info', 'warning', 'critical', 'page'].includes(value.severity)) return 'EVENT_INVALID';
  if (!EVENT_TYPE_PATTERN.test(String(value.eventType || ''))) return 'EVENT_INVALID';
  if (typeof value.occurredAt !== 'string') return 'EVENT_INVALID';
  const occurred = new Date(value.occurredAt);
  if (!Number.isFinite(occurred.getTime()) || occurred.toISOString() !== value.occurredAt) return 'EVENT_INVALID';
  if (value.pagerDutyIncidentId !== undefined &&
      (typeof value.pagerDutyIncidentId !== 'string' || !/^[A-Za-z0-9._-]{1,128}$/.test(value.pagerDutyIncidentId))) {
    return 'EVENT_INVALID';
  }
  return null;
}

async function sha256Hex(bytes) {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return [...digest].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function prepareBudget(db, nowSeconds, reads, writes, cleanupWrites = 0) {
  const day = new Date(nowSeconds * 1000).toISOString().slice(0, 10);
  return db.prepare(`
    INSERT INTO collector_daily_budget (budget_date, reads_used, writes_used, cleanup_writes_used)
    VALUES (?, ?, ?, ?)
    ON CONFLICT(budget_date) DO UPDATE SET
      reads_used = collector_daily_budget.reads_used + excluded.reads_used,
      writes_used = collector_daily_budget.writes_used + excluded.writes_used,
      cleanup_writes_used = collector_daily_budget.cleanup_writes_used + excluded.cleanup_writes_used
    WHERE collector_daily_budget.reads_used + excluded.reads_used <= ${MAX_DAILY_READS}
      AND collector_daily_budget.writes_used + excluded.writes_used <= ${MAX_DAILY_REQUEST_WRITES}
      AND collector_daily_budget.cleanup_writes_used + excluded.cleanup_writes_used <= ${MAX_DAILY_CLEANUP_WRITES}
  `).bind(day, reads, writes, cleanupWrites);
}

async function reserveBudget(db, nowSeconds, reads, writes, cleanupWrites = 0) {
  const result = await prepareBudget(db, nowSeconds, reads, writes, cleanupWrites).run();
  return Number(result?.meta?.changes || 0) > 0;
}

function handleHealth() {
  // Public liveness must not consume D1 rows or the ingestion write budget.
  return json(200, { status: 'alive' });
}

async function readBoundedBody(stream) {
  if (!stream) return new Uint8Array();
  const reader = stream.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const chunk = value instanceof Uint8Array ? value : new Uint8Array(value);
      total += chunk.byteLength;
      if (total > MAX_BODY_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(chunk);
    }
  } finally {
    reader.releaseLock();
  }
  const output = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return output;
}

async function handleEvents(request, env, nowSeconds) {
  if (!env.DB) return json(503, { error: 'STORAGE_UNAVAILABLE' });
  if (new URL(request.url).search || request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json') {
    return json(415, { error: 'CONTENT_TYPE_INVALID' });
  }
  const contentEncoding = request.headers.get('content-encoding');
  if (contentEncoding && contentEncoding.toLowerCase() !== 'identity') {
    return json(415, { error: 'CONTENT_ENCODING_INVALID' });
  }
  const declaredLength = request.headers.get('content-length');
  if (declaredLength && (!/^\d+$/.test(declaredLength) || Number(declaredLength) > MAX_BODY_BYTES)) {
    return json(413, { error: 'BODY_TOO_LARGE' });
  }

  let rawBytes;
  try { rawBytes = await readBoundedBody(request.body); }
  catch { return json(400, { error: 'BODY_INVALID' }); }
  if (rawBytes === null) return json(413, { error: 'BODY_TOO_LARGE' });
  if (rawBytes.byteLength === 0) return json(400, { error: 'BODY_EMPTY' });
  let rawBody;
  try { rawBody = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(rawBytes); }
  catch { return json(400, { error: 'BODY_ENCODING_INVALID' }); }

  const auth = await verifyRequest(request, env, { rawBody, nowSeconds });
  if (!auth.ok) return auth.response;

  let event;
  try { event = JSON.parse(rawBody); }
  catch { return json(400, { error: 'JSON_INVALID' }); }
  const validationError = validateEvent(event);
  if (validationError) return json(400, { error: validationError });
  if (request.headers.get('idempotency-key') !== `hope-outbox:${event.eventId}`) {
    return json(400, { error: 'IDEMPOTENCY_KEY_INVALID' });
  }

  const payloadDigest = await sha256Hex(rawBytes);
  try {
    // D1 batch is one SQL transaction: the daily budget, nonce reservation and
    // receipt insert either commit together or roll back together. changes()
    // gates each dependent insert on the immediately preceding reservation.
    const results = await env.DB.batch([
      prepareBudget(env.DB, nowSeconds, 4, 4),
      env.DB.prepare(`
        INSERT OR IGNORE INTO collector_nonces (source, nonce, issued_at, expires_at)
        SELECT ?, ?, ?, ? WHERE changes() = 1
      `).bind(auth.source, auth.nonce, auth.timestamp, nowSeconds + NONCE_TTL_SECONDS),
      env.DB.prepare(`
        INSERT OR IGNORE INTO collector_receipts (
          event_id, source, severity, event_type, occurred_at, received_at,
          payload_sha256, pagerduty_incident_id, receipt_status
        )
        SELECT ?, ?, ?, ?, ?, ?, ?, ?, ? WHERE changes() = 1
      `).bind(
        event.eventId, event.source, event.severity, event.eventType,
        event.occurredAt, new Date(nowSeconds * 1000).toISOString(),
        payloadDigest, event.pagerDutyIncidentId || null, 'received',
      ),
    ]);
    const budgetChanges = Number(results?.[0]?.meta?.changes || 0);
    const nonceChanges = Number(results?.[1]?.meta?.changes || 0);
    const receiptChanges = Number(results?.[2]?.meta?.changes || 0);
    if (budgetChanges !== 1) return json(429, { error: 'QUOTA_BLOCKED' });
    if (nonceChanges !== 1) return json(409, { error: 'REPLAY_DETECTED' });
    if (receiptChanges !== 1) {
      const existing = await env.DB.prepare(`
        SELECT payload_sha256 FROM collector_receipts
        WHERE source = ? AND event_id = ? LIMIT 1
      `).bind(event.source, event.eventId).first();
      if (!existing || existing.payload_sha256 !== payloadDigest) return json(409, { error: 'EVENT_ID_CONFLICT' });
      return json(200, { status: 'duplicate', eventId: event.eventId });
    }
    return json(202, {
      status: 'received',
      eventId: event.eventId,
      receivedAt: new Date(nowSeconds * 1000).toISOString(),
    });
  } catch (error) { return storageErrorResponse(error); }
}

async function handleReceipt(request, env, nowSeconds, eventId) {
  if (!env.DB) return json(503, { error: 'STORAGE_UNAVAILABLE' });
  if (!UUID_PATTERN.test(eventId)) return json(404, { error: 'NOT_FOUND' });
  const auth = await verifyRequest(request, env, {
    rawBody: '',
    nowSeconds,
    secretName: 'HOPE_READBACK_HMAC_SECRET',
  });
  if (!auth.ok) return auth.response;
  try {
    const results = await env.DB.batch([
      prepareBudget(env.DB, nowSeconds, 2, 3),
      env.DB.prepare(`
        INSERT OR IGNORE INTO collector_nonces (source, nonce, issued_at, expires_at)
        SELECT ?, ?, ?, ? WHERE changes() = 1
      `).bind(auth.source, auth.nonce, auth.timestamp, nowSeconds + NONCE_TTL_SECONDS),
      env.DB.prepare(`
        SELECT event_id, source, severity, event_type, occurred_at, received_at,
               payload_sha256, pagerduty_incident_id, receipt_status
        FROM collector_receipts
        WHERE changes() = 1 AND source = ? AND event_id = ? LIMIT 1
      `).bind(auth.source, eventId),
    ]);
    if (Number(results?.[0]?.meta?.changes || 0) !== 1) return json(429, { error: 'QUOTA_BLOCKED' });
    if (Number(results?.[1]?.meta?.changes || 0) !== 1) return json(409, { error: 'REPLAY_DETECTED' });
    const receipt = results?.[2]?.results?.[0] || null;
    if (!receipt) return json(404, { error: 'NOT_FOUND' });
    return json(200, { receipt });
  } catch (error) { return storageErrorResponse(error); }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const nowSeconds = Math.floor(Date.now() / 1000);
    if (url.pathname === '/v1/healthz' && !url.search) {
      return request.method === 'GET'
        ? handleHealth()
        : json(405, { error: 'METHOD_NOT_ALLOWED' });
    }
    if (url.pathname === '/v1/events') {
      return request.method === 'POST'
        ? handleEvents(request, env, nowSeconds)
        : json(405, { error: 'METHOD_NOT_ALLOWED' });
    }
    const receiptMatch = /^\/v1\/receipts\/([0-9a-f-]{36})$/i.exec(url.pathname);
    if (receiptMatch && !url.search) {
      return request.method === 'GET'
        ? handleReceipt(request, env, nowSeconds, receiptMatch[1])
        : json(405, { error: 'METHOD_NOT_ALLOWED' });
    }
    if (url.pathname.startsWith('/v1/')) return json(404, { error: 'NOT_FOUND' });
    return json(404, { error: 'NOT_FOUND' });
  },

  async scheduled(_controller, env) {
    if (!env.DB) return;
    const nowSeconds = Math.floor(Date.now() / 1000);
    try {
      // Reserve worst-case bounded scan and delete-subquery reads before selection.
      // The exact delete count and its own budget-row write are reserved afterwards.
      if (!await reserveBudget(env.DB, nowSeconds, (MAX_CLEANUP_BATCH * 2) + 1, 0, 1)) {
        console.warn('collector_nonce_cleanup_quota_blocked');
        return;
      }
      const candidates = await env.DB.prepare(`
        SELECT 1 AS pending FROM collector_nonces
        WHERE expires_at < ? ORDER BY expires_at LIMIT ${MAX_CLEANUP_BATCH}
      `).bind(nowSeconds).all();
      const count = Array.isArray(candidates?.results) ? candidates.results.length : 0;
      if (count === 0) return;
      if (!await reserveBudget(env.DB, nowSeconds, 0, 0, (count * 2) + 1)) {
        console.warn('collector_nonce_cleanup_quota_blocked');
        return;
      }
      await env.DB.prepare(`
        DELETE FROM collector_nonces
        WHERE (source, nonce) IN (
          SELECT source, nonce FROM collector_nonces
          WHERE expires_at < ? ORDER BY expires_at LIMIT ${MAX_CLEANUP_BATCH}
        )
      `).bind(nowSeconds).run();
    } catch (error) {
      console.warn(D1_QUOTA_ERROR.test(String(error?.message || error))
        ? 'collector_nonce_cleanup_quota_blocked'
        : 'collector_nonce_cleanup_failed');
    }
  },
};
