import http from 'node:http';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

const DEFAULT_TOKEN = 'hope-staging-mock-provider-test-token-32chars';

function json(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(data);
}

function timingSafeEqualString(a, b) {
  const left = Buffer.from(String(a || ''));
  const right = Buffer.from(String(b || ''));
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

async function readJson(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    let size = 0;
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 64 * 1024) {
        req.destroy();
        reject(new Error('BODY_TOO_LARGE'));
        return;
      }
      raw += chunk;
    });
    req.on('end', () => {
      try {
        resolve(JSON.parse(raw || '{}'));
      } catch {
        reject(new Error('INVALID_JSON'));
      }
    });
    req.on('error', reject);
  });
}

function providerRef(operation, paymentId, idempotencyKey) {
  const digest = crypto
    .createHash('sha256')
    .update(`${operation}:${paymentId}:${idempotencyKey}`)
    .digest('hex')
    .slice(0, 24);
  return `MOCK-${operation.toUpperCase()}-${digest}`;
}

function configuredOutcome(operation, outcomes) {
  const override = outcomes?.[operation];
  const specific = process.env[`MOCK_PAYMENT_${operation.toUpperCase()}_OUTCOME`];
  return String(override || specific || process.env.MOCK_PAYMENT_OUTCOME || 'SUCCESS').trim().toUpperCase();
}

function signatureFor(raw, secret, timestamp, eventId) {
  return `sha256=${crypto.createHmac('sha256', secret).update(`${timestamp}.${eventId}.${raw}`).digest('hex')}`;
}

export function createMockPaymentServer({
  token = process.env.PAYMENT_PROVIDER_TOKEN || DEFAULT_TOKEN,
  webhookSecret = process.env.PAYMENT_WEBHOOK_SECRET || '',
  webhookTargetUrl = process.env.MOCK_PAYMENT_WEBHOOK_TARGET_URL || '',
  outcomes = {},
} = {}) {
  const state = new Map();

  async function operation(req, res, name) {
    const auth = String(req.headers.authorization || '');
    const supplied = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    if (!timingSafeEqualString(supplied, token)) {
      return json(res, 401, { error: 'UNAUTHORIZED' });
    }

    const payload = await readJson(req);
    const paymentId = String(payload.paymentId || '').trim();
    const currency = String(payload.currency || 'TOMAN').trim().toUpperCase();
    const idempotencyKey = String(req.headers['idempotency-key'] || '').trim();
    const rawAmount = payload.amount == null ? '' : String(payload.amount).trim();
    const requestedProviderRef = String(payload.providerRef || '').trim();

    if (!paymentId || paymentId.length > 100) return json(res, 400, { error: 'INVALID_PAYMENT_ID' });
    if (!idempotencyKey || idempotencyKey.length > 200 || !/^[A-Za-z0-9._~:-]+$/.test(idempotencyKey)) {
      return json(res, 400, { error: 'INVALID_IDEMPOTENCY_KEY' });
    }
    if (currency !== 'TOMAN') return json(res, 400, { error: 'CURRENCY_MUST_BE_TOMAN' });
    if (['release', 'refund'].includes(name) && (!requestedProviderRef || requestedProviderRef.length > 200)) {
      return json(res, 400, { error: 'PROVIDER_REF_REQUIRED' });
    }
    if (name === 'create' && (!/^\d+$/.test(rawAmount) || BigInt(rawAmount) <= 0n)) {
      return json(res, 400, { error: 'INVALID_AMOUNT' });
    }
    if (name !== 'create' && rawAmount && !/^\d+$/.test(rawAmount)) {
      return json(res, 400, { error: 'INVALID_AMOUNT' });
    }
    let amount = rawAmount;
    if (rawAmount) {
      try {
        const integer = BigInt(rawAmount);
        if (integer > 9_000_000_000_000_000n) return json(res, 400, { error: 'AMOUNT_OUT_OF_RANGE' });
        amount = integer.toString();
      } catch {
        return json(res, 400, { error: 'INVALID_AMOUNT' });
      }
    } else if (name !== 'create') {
      amount = '0';
    }

    const key = `${name}:${idempotencyKey}`;
    const requestFingerprint = crypto.createHash('sha256').update(JSON.stringify({
      operation: name,
      paymentId,
      amount,
      currency,
      providerRef: requestedProviderRef,
    })).digest('hex');
    const existing = state.get(key);
    if (existing) {
      if (existing.requestFingerprint !== requestFingerprint) {
        return json(res, 409, { error: 'IDEMPOTENCY_CONFLICT' });
      }
      return json(res, 200, { ...existing.response, idempotent: true });
    }

    const outcome = configuredOutcome(name, outcomes);
    if (!['SUCCESS', 'FAILED', 'UNKNOWN'].includes(outcome)) {
      return json(res, 500, { error: 'INVALID_MOCK_OUTCOME' });
    }
    if (outcome === 'FAILED') return json(res, 502, { error: `MOCK_${name.toUpperCase()}_FAILED` });
    if (outcome === 'UNKNOWN') return json(res, 504, { error: `MOCK_${name.toUpperCase()}_UNKNOWN` });

    const response = name === 'create'
      ? {
          provider: 'MOCK',
          providerRef: providerRef('hold', paymentId, idempotencyKey),
          status: 'HELD',
          amount,
          currency,
        }
      : name === 'release'
        ? {
            provider: 'MOCK',
            providerRef: requestedProviderRef,
            releaseRef: providerRef('release', paymentId, idempotencyKey),
            status: 'RELEASED',
            amount,
            currency,
          }
        : {
            provider: 'MOCK',
            providerRef: requestedProviderRef,
            refundRef: providerRef('refund', paymentId, idempotencyKey),
            status: 'REFUNDED',
            amount,
            currency,
          };

    state.set(key, { requestFingerprint, response });
    return json(res, 200, { ...response, idempotent: false });
  }

  const server = http.createServer(async (req, res) => {
    try {
      if (req.method === 'GET' && req.url === '/health') {
        return json(res, 200, {
          ok: true,
          service: 'hope-staging-payment-provider',
          provider: 'MOCK',
        });
      }
      if (req.method === 'POST' && req.url === '/create') return operation(req, res, 'create');
      if (req.method === 'POST' && req.url === '/release') return operation(req, res, 'release');
      if (req.method === 'POST' && req.url === '/refund') return operation(req, res, 'refund');

      if (req.method === 'POST' && req.url === '/emit-webhook') {
        const auth = String(req.headers.authorization || '');
        const supplied = auth.startsWith('Bearer ') ? auth.slice(7) : '';
        if (!timingSafeEqualString(supplied, token)) return json(res, 401, { error: 'UNAUTHORIZED' });
        if (!webhookSecret || !webhookTargetUrl) return json(res, 503, { error: 'WEBHOOK_EMITTER_NOT_CONFIGURED' });

        const payload = await readJson(req);
        const paymentId = String(payload.paymentId || '').trim();
        const eventType = String(payload.eventType || '').trim().toUpperCase();
        const requestedProviderRef = String(payload.providerRef || '').trim();
        if (!paymentId || !['PAYMENT_HELD', 'PAYMENT_RELEASED', 'PAYMENT_REFUNDED'].includes(eventType)) {
          return json(res, 400, { error: 'INVALID_WEBHOOK_EVENT' });
        }
        if (!requestedProviderRef || requestedProviderRef.length > 200) {
          return json(res, 400, { error: 'PROVIDER_REF_REQUIRED' });
        }
        if (['PAYMENT_HELD', 'PAYMENT_RELEASED'].includes(eventType) && !requestedProviderRef) {
          return json(res, 400, { error: 'PROVIDER_REF_REQUIRED' });
        }
        try {
          const target = new URL(webhookTargetUrl);
          if (target.protocol !== 'https:') return json(res, 500, { error: 'WEBHOOK_TARGET_MUST_USE_HTTPS' });
        } catch {
          return json(res, 500, { error: 'WEBHOOK_TARGET_INVALID' });
        }
        const eventId = String(payload.eventId || crypto.randomUUID()).trim();
        const body = JSON.stringify({ eventId, eventType, paymentId, providerRef: requestedProviderRef });
        const timestamp = String(Math.floor(Date.now() / 1000));
        const signature = signatureFor(body, webhookSecret, timestamp, eventId);
        const response = await fetch(webhookTargetUrl, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            'x-hope-signature': signature,
            'x-hope-timestamp': timestamp,
            'x-hope-event-id': eventId,
          },
          body,
          signal: AbortSignal.timeout(10000),
        });
        const responseText = await response.text();
        return json(res, response.ok ? 200 : 502, {
          delivered: response.ok,
          status: response.status,
          response: responseText.slice(0, 4000),
          eventId,
        });
      }

      return json(res, 404, { error: 'NOT_FOUND' });
    } catch (error) {
      return json(res, 500, { error: error?.message || String(error) });
    }
  });

  return server;
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  const port = Number(process.env.PORT || 8080);
  const token = String(process.env.PAYMENT_PROVIDER_TOKEN || '').trim();
  if (token.length < 24) throw new Error('PAYMENT_PROVIDER_TOKEN must be at least 24 characters');
  const server = createMockPaymentServer({ token });
  server.listen(port, '0.0.0.0', () => {
    console.log(`HOPE staging mock payment provider listening on ${port}`);
  });
}
