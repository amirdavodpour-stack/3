const REQUEST_TIMEOUT_MS = 8000;

export async function pingRenderStaging({ healthUrl, fetchImpl = fetch } = {}) {
  let target;
  try { target = new URL(String(healthUrl || '')); } catch { throw new Error('RENDER_HEALTH_URL_INVALID'); }
  if (
    target.protocol !== 'https:'
    || !target.hostname.endsWith('.onrender.com')
    || target.username
    || target.password
    || target.port
    || target.pathname !== '/live'
    || target.search
    || target.hash
  ) {
    throw new Error('RENDER_HEALTH_URL_INVALID');
  }
  let response;
  try {
    response = await fetchImpl(target.toString(), {
      method: 'GET',
      redirect: 'manual',
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      headers: { accept: 'application/json', 'user-agent': 'HOPE-Staging-Keepalive/1.0' },
    });
  } catch {
    throw new Error('RENDER_HEALTH_CHECK_FAILED');
  }
  try { await response?.body?.cancel(); } catch {}
  if (!response || response.status !== 200 || response.ok !== true) {
    throw new Error('RENDER_HEALTH_CHECK_FAILED');
  }
  return { ok: true, status: response.status };
}

export default {
  async fetch() {
    return new Response('Not found', { status: 404 });
  },
  scheduled(_event, env, context) {
    context.waitUntil(pingRenderStaging({ healthUrl: env.RENDER_STAGING_HEALTH_URL }));
  },
};
