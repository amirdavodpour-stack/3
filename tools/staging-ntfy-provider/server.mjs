import http from 'node:http';

const PORT = Number(process.env.PORT || 8080);
const PROVIDER_TOKEN = process.env.NOTIFICATION_PROVIDER_TOKEN || '';
const NTFY_TOPIC = process.env.NTFY_TOPIC || '';
const NTFY_BASE_URL = (process.env.NTFY_BASE_URL || 'https://ntfy.sh').replace(/\/+$/, '');

if (PROVIDER_TOKEN.length < 24) throw new Error('NOTIFICATION_PROVIDER_TOKEN must be at least 24 characters');
if (!/^[A-Za-z0-9_-]{16,128}$/.test(NTFY_TOPIC)) throw new Error('NTFY_TOPIC must be a high-entropy topic name');

function json(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {'content-type':'application/json','cache-control':'no-store'});
  res.end(data);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    let size = 0;
    req.on('data', chunk => {
      size += chunk.length;
      if (size > 64 * 1024) { reject(new Error('BODY_TOO_LARGE')); req.destroy(); return; }
      raw += chunk;
    });
    req.on('end', () => {
      try { resolve(JSON.parse(raw || '{}')); } catch { reject(new Error('INVALID_JSON')); }
    });
    req.on('error', reject);
  });
}

function constantTimeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i=0; i<a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function publish(payload, idempotencyKey) {
  const title = String(payload.title || 'HOPE staging notification').slice(0, 200);
  const message = String(payload.body || '').slice(0, 4000);
  const data = JSON.stringify(payload.data ?? {});
  const response = await fetch(NTFY_BASE_URL + '/' + NTFY_TOPIC, {
    method: 'POST',
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      'X-Title': title,
      'X-Tags': 'hope,staging',
      'X-Idempotency-Key': idempotencyKey,
      'X-Click': 'https://ntfy.sh',
    },
    body: message || data,
    signal: AbortSignal.timeout(10000),
  });
  const text = await response.text();
  if (!response.ok) throw new Error('NTFY_HTTP_' + response.status + ':' + text.slice(0, 200));
  return { status: response.status };
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/health') return json(res, 200, {ok:true, service:'hope-staging-ntfy-provider'});
    if (req.method !== 'POST' || req.url !== '/push') return json(res, 404, {error:'NOT_FOUND'});

    const auth = String(req.headers.authorization || '');
    const supplied = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    if (!supplied || !constantTimeEqual(supplied, PROVIDER_TOKEN)) return json(res, 401, {error:'UNAUTHORIZED'});

    const payload = await readBody(req);
    if (!payload.notificationId || !payload.userId || !payload.token || !payload.platform) {
      return json(res, 400, {error:'INVALID_NOTIFICATION_PAYLOAD'});
    }

    const idempotencyKey = String(req.headers['idempotency-key'] || '').slice(0, 200);
    if (!idempotencyKey) return json(res, 400, {error:'IDEMPOTENCY_KEY_REQUIRED'});

    const result = await publish(payload, idempotencyKey);
    return json(res, 202, {accepted:true, provider:'ntfy', ...result});
  } catch (error) {
    return json(res, 502, {error: error?.message || String(error)});
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('HOPE staging ntfy provider listening on ' + PORT);
});
