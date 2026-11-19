const MAINTENANCE_PATH = '/api/v1/internal/maintenance';
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function validateEndpoint(value) {
  let endpoint;
  try {
    endpoint = new URL(String(value || ''));
  } catch {
    throw new Error('MAINTENANCE_ENDPOINT_INVALID');
  }
  if (
    endpoint.protocol !== 'https:'
    || !endpoint.hostname.endsWith('.vercel.app')
    || endpoint.username
    || endpoint.password
    || endpoint.pathname !== MAINTENANCE_PATH
    || endpoint.search
    || endpoint.hash
  ) {
    throw new Error('MAINTENANCE_ENDPOINT_INVALID');
  }
  return endpoint;
}

async function sign(secret, canonical) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(canonical)));
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function triggerMaintenance(env, {
  fetchImpl = fetch,
  now = () => Date.now(),
  newRequestId = () => crypto.randomUUID(),
} = {}) {
  const endpoint = validateEndpoint(env?.HOPE_MAINTENANCE_URL);
  const secret = String(env?.HOPE_MAINTENANCE_HMAC_SECRET || '');
  if (new TextEncoder().encode(secret).byteLength < 32) throw new Error('MAINTENANCE_SECRET_INVALID');

  const timestamp = String(Math.floor(now() / 1000));
  const requestId = newRequestId();
  if (!UUID_V4.test(requestId)) throw new Error('MAINTENANCE_REQUEST_ID_INVALID');
  const canonical = `${timestamp}.${requestId}.POST.${MAINTENANCE_PATH}`;
  const signature = await sign(secret, canonical);
  const response = await fetchImpl(endpoint.toString(), {
    method: 'POST',
    redirect: 'manual',
    signal: AbortSignal.timeout(25000),
    headers: {
      'x-hope-timestamp': timestamp,
      'x-hope-request-id': requestId,
      'x-hope-signature': signature,
    },
  });
  if (!response.ok) throw new Error(`MAINTENANCE_HTTP_${response.status}`);
  return { ok: true, status: response.status, requestId };
}

export default {
  async scheduled(_controller, env, context) {
    context.waitUntil(triggerMaintenance(env).catch((error) => {
      const code = /^[A-Z0-9_]{1,80}$/.test(String(error?.message || ''))
        ? String(error.message)
        : 'MAINTENANCE_TRIGGER_FAILED';
      console.error(JSON.stringify({ level: 'error', action: 'HOPE_MAINTENANCE_TRIGGER_FAILED', code }));
    }));
  },
};
