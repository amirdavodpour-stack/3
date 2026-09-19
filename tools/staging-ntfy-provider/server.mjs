import http from 'node:http';
import https from 'node:https';
import dns from 'node:dns';

const PORT = Number(process.env.PORT || 8080);
const PROVIDER_TOKEN = process.env.NOTIFICATION_PROVIDER_TOKEN || '';
const NTFY_TOPIC = process.env.NTFY_TOPIC || '';
const NTFY_BASE_URL = (process.env.NTFY_BASE_URL || 'https://ntfy.sh').replace(/\/+$/, '');
const NTFY_BASE_URLS = [...new Set((process.env.NTFY_BASE_URLS || NTFY_BASE_URL).split(',').map((value) => value.trim().replace(/\/+$/, '')).filter(Boolean))];
const NTFY_REQUEST_TIMEOUT_MS = Math.max(3_000, Math.min(15_000, Number(process.env.NTFY_REQUEST_TIMEOUT_MS || 6_000)));
const NTFY_DNS_TIMEOUT_MS = 3_000;

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

async function resolveIpv4(hostname) {
  return await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('NTFY_DNS_TIMEOUT')), NTFY_DNS_TIMEOUT_MS);
    dns.lookup(hostname, { all: true, family: 4 }, (error, addresses) => {
      clearTimeout(timer);
      if (error) return reject(error);
      const ipv4s = [...new Set(addresses.map((entry) => entry.address).filter(Boolean))];
      if (ipv4s.length === 0) return reject(new Error('NTFY_NO_IPV4'));
      resolve(ipv4s);
    });
  });
}

function publishToIpv4(target, ipv4, payload, idempotencyKey) {
  const title = String(payload.title || 'HOPE staging notification').slice(0, 200);
  const message = String(payload.body || '').slice(0, 4000);
  const data = JSON.stringify(payload.data ?? {});
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(new Error('NTFY_REQUEST_TIMEOUT')), NTFY_REQUEST_TIMEOUT_MS);

  return new Promise((resolve, reject) => {
    const req = https.request(target, {
      method: 'POST',
      hostname: ipv4,
      family: 4,
      servername: target.hostname,
      agent: false,
      path: target.pathname + target.search,
      signal: controller.signal,
      headers: {
        host: target.hostname,
        'content-type': 'text/plain; charset=utf-8',
        'X-Title': title,
        'X-Tags': 'hope,staging',
        'X-Idempotency-Key': idempotencyKey,
        'X-Click': 'https://ntfy.sh',
      },
    }, (res) => {
      let raw = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { raw += chunk; });
      res.on('end', () => resolve({ status: res.statusCode || 0, text: raw }));
    });
    req.on('error', reject);
    req.end(message || data);
  }).finally(() => clearTimeout(timer));
}

async function publish(payload, idempotencyKey) {
  let lastError = null;
  for (const baseUrl of NTFY_BASE_URLS) {
    const target = new URL(baseUrl + '/' + NTFY_TOPIC);
    if (target.protocol !== 'https:') {
      lastError = new Error('NTFY_BASE_URL_MUST_USE_HTTPS');
      continue;
    }
    try {
      const ipv4s = await resolveIpv4(target.hostname);
      for (const ipv4 of ipv4s) {
        try {
          const response = await publishToIpv4(target, ipv4, payload, idempotencyKey);
          if (response.status >= 200 && response.status < 300) {
            return { status: response.status, ipv4, upstream: target.origin };
          }
          lastError = new Error('NTFY_HTTP_' + response.status + ':' + response.text.slice(0, 200));
        } catch (error) {
          lastError = error;
          console.error('ntfy upstream attempt failed', {
            upstream: target.origin,
            ipv4,
            error: error?.message || String(error),
          });
        }
      }
    } catch (error) {
      lastError = error;
      console.error('ntfy upstream DNS failed', { upstream: target.origin, error: error?.message || String(error) });
    }
  }
  throw lastError || new Error('NTFY_UPSTREAM_UNAVAILABLE');
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
