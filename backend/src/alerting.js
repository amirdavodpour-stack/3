import { config } from './config.js';

let lastFingerprint = '';
let lastSentAt = 0;
const COOLDOWN_MS = 5 * 60 * 1000;

function fingerprint(alerts) {
  return alerts.map((a) => `${a.code}:${a.severity}`).sort().join('|');
}

export async function dispatchOperationalAlerts(snapshot) {
  if (!config.alertWebhookUrl) return { dispatched: false, reason: 'disabled' };
  const alerts = Array.isArray(snapshot?.health?.alerts) ? snapshot.health.alerts.filter(Boolean) : [];
  if (!alerts.length) { lastFingerprint = ''; return { dispatched: false, reason: 'no-alerts' }; }
  const fp = fingerprint(alerts);
  const now = Date.now();
  if (fp === lastFingerprint && now - lastSentAt < COOLDOWN_MS) return { dispatched: false, reason: 'cooldown' };
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.alertWebhookTimeoutMs);
  timer.unref?.();
  try {
    const response = await fetch(config.alertWebhookUrl, {
      method: 'POST',
      redirect: 'error',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${config.alertWebhookToken}` },
      body: JSON.stringify({ service: 'hope-api', version: process.env.HOPE_VERSION || '4.0.2', occurredAt: new Date().toISOString(), alerts, recentHealth: snapshot.recentHealth, latency: snapshot.latency }),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`alert webhook returned ${response.status}`);
    lastFingerprint = fp;
    lastSentAt = now;
    return { dispatched: true };
  } catch (error) {
    return { dispatched: false, reason: 'delivery-failed', error: error.message };
  } finally { clearTimeout(timer); }
}


const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Dispatch one refresh-token reuse security event. The outbox owns retries;
 * this function sends exactly one attempt using a stable idempotency key.
 * Only explicitly allowlisted identifiers leave the service.
 */
export async function dispatchSecurityAlert(event, {
  url = config.alertWebhookUrl,
  token = config.alertWebhookToken,
  timeoutMs = config.alertWebhookTimeoutMs,
  fetchImpl = fetch,
} = {}) {
  const payload = event?.payload || {};
  const eventId = String(event?.id || '');
  const actorUserId = String(event?.aggregate_id || '');
  const tokenFamilyId = String(payload.tokenFamilyId || '');
  const occurredAtDate = new Date(event?.created_at);

  if (
    event?.event_type !== 'AUTH_REFRESH_REUSE_ALERT' ||
    event?.aggregate_type !== 'user' ||
    payload.alertCode !== 'AUTH_REFRESH_REUSE_DETECTED' ||
    !UUID_PATTERN.test(eventId) ||
    !UUID_PATTERN.test(actorUserId) ||
    !UUID_PATTERN.test(tokenFamilyId) ||
    !Number.isFinite(occurredAtDate.getTime())
  ) {
    throw new Error('SECURITY_ALERT_EVENT_INVALID');
  }

  if (!url || !token) throw new Error('SECURITY_ALERT_WEBHOOK_NOT_CONFIGURED');
  if (typeof fetchImpl !== 'function') throw new Error('SECURITY_ALERT_FETCH_UNAVAILABLE');

  let endpoint;
  try {
    endpoint = new URL(url);
    if (endpoint.protocol !== 'https:' || endpoint.username || endpoint.password || !endpoint.hostname) {
      throw new Error('invalid endpoint');
    }
  } catch {
    throw new Error('SECURITY_ALERT_WEBHOOK_URL_INVALID');
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  timer.unref?.();

  try {
    let response;
    try {
      response = await fetchImpl(endpoint.toString(), {
        method: 'POST',
        redirect: 'error',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${token}`,
          'idempotency-key': `hope-outbox:${eventId}`,
        },
        body: JSON.stringify({
          service: 'hope-api',
          eventType: 'SECURITY_ALERT',
          occurredAt: occurredAtDate.toISOString(),
          alert: {
            code: 'AUTH_REFRESH_REUSE_DETECTED',
            severity: 'page',
            actorUserId,
            tokenFamilyId,
            runbook: 'docs/runbooks/auth-refresh-token-reuse.md',
          },
        }),
        signal: controller.signal,
      });
    } catch {
      throw new Error('SECURITY_ALERT_WEBHOOK_DELIVERY_FAILED');
    }

    if (!response?.ok) {
      const status = Number(response?.status) || 0;
      throw new Error(`SECURITY_ALERT_WEBHOOK_HTTP_${status}`);
    }
    return { dispatched: true };
  } finally {
    clearTimeout(timer);
  }
}
