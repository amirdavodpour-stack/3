import https from 'node:https';
import {
  assertAllowedAlertEndpoint,
  createPinnedHttpsAgent,
  resolvePublicAlertAddresses,
} from './alert_egress.js';

const PAGERDUTY_API_BASE = 'https://api.pagerduty.com/';
const PAGERDUTY_ACCEPT = 'application/vnd.pagerduty+json;version=2';
const INCIDENT_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/;
const MAX_RESPONSE_BYTES = 64 * 1024;
const DEFAULT_TIMEOUT_MS = 3000;

function validTimestamp(value) {
  return typeof value === 'string' && Number.isFinite(Date.parse(value));
}

function normalizeIncident(incident, requestedId) {
  if (!incident || typeof incident !== 'object' || Array.isArray(incident)) {
    throw new Error('PAGERDUTY_INCIDENT_RESPONSE_INVALID');
  }
  const id = typeof incident.id === 'string' ? incident.id : '';
  const incidentNumber = Number.isSafeInteger(incident.incident_number) ? incident.incident_number : null;
  if (!id || (typeof incident.status !== 'string') || !validTimestamp(incident.created_at)) {
    throw new Error('PAGERDUTY_INCIDENT_RESPONSE_INVALID');
  }
  const numericLookup = /^\d+$/.test(requestedId);
  const matches = numericLookup
    ? String(incidentNumber) === requestedId
    : id === requestedId;
  if (!matches) throw new Error('PAGERDUTY_INCIDENT_ID_MISMATCH');
  if (!['triggered', 'acknowledged', 'resolved'].includes(incident.status)) {
    throw new Error('PAGERDUTY_INCIDENT_RESPONSE_INVALID');
  }

  const acknowledgements = Array.isArray(incident.acknowledgements)
    ? incident.acknowledgements.flatMap((entry) => {
      const user = entry?.acknowledger;
      if (
        user?.type !== 'user_reference' ||
        typeof user.id !== 'string' ||
        !user.id ||
        !validTimestamp(entry?.at)
      ) return [];
      return [{ at: entry.at, userId: user.id }];
    })
    : [];
  const resolvedAt = validTimestamp(incident.resolved_at) ? incident.resolved_at : null;

  return {
    id,
    incidentNumber,
    status: incident.status,
    createdAt: incident.created_at,
    updatedAt: validTimestamp(incident.updated_at) ? incident.updated_at : null,
    resolvedAt,
    humanAcknowledged: acknowledgements.length > 0,
    acknowledgements,
    resolved: incident.status === 'resolved' && resolvedAt !== null,
  };
}

function performPinnedGet(url, { headers, agent, signal, timeoutMs }) {
  return new Promise((resolve, reject) => {
    const request = https.request(url, {
      method: 'GET',
      headers,
      agent,
      signal,
    }, (response) => {
      const chunks = [];
      let size = 0;
      response.on('data', (chunk) => {
        size += chunk.length;
        if (size > MAX_RESPONSE_BYTES) {
          request.destroy(new Error('PAGERDUTY_READBACK_RESPONSE_TOO_LARGE'));
          return;
        }
        chunks.push(chunk);
      });
      response.on('end', () => {
        resolve({
          statusCode: Number(response.statusCode) || 0,
          headers: response.headers,
          body: Buffer.concat(chunks).toString('utf8'),
        });
      });
      response.on('error', () => reject(new Error('PAGERDUTY_READBACK_RESPONSE_FAILED')));
    });
    request.setTimeout(timeoutMs, () => request.destroy(new Error('PAGERDUTY_READBACK_TIMEOUT')));
    request.on('error', () => reject(new Error('PAGERDUTY_READBACK_NETWORK_FAILED')));
    request.end();
  });
}

/**
 * Read one PagerDuty incident through GET only.
 *
 * The caller must supply a dedicated PagerDuty account API token explicitly
 * configured read-only, plus an explicit allowlist containing exactly the
 * canonical API base URL. This function cannot create, acknowledge, resolve,
 * or otherwise mutate an incident. Tests must inject requestImpl; no test
 * sends a real PagerDuty request.
 */
export async function readPagerDutyIncident({
  incidentId,
  readOnlyToken,
  allowedApiBases = [],
  timeoutMs = DEFAULT_TIMEOUT_MS,
  resolveHost,
  requestImpl = performPinnedGet,
} = {}) {
  const lookupId = String(incidentId ?? '');
  if (!INCIDENT_ID_PATTERN.test(lookupId)) {
    throw new Error('PAGERDUTY_INCIDENT_ID_INVALID');
  }
  if (typeof readOnlyToken !== 'string' || readOnlyToken.length === 0) {
    throw new Error('PAGERDUTY_READONLY_CREDENTIAL_REQUIRED');
  }
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 500 || timeoutMs > 30000) {
    throw new Error('PAGERDUTY_READBACK_TIMEOUT_INVALID');
  }
  if (typeof requestImpl !== 'function') {
    throw new Error('PAGERDUTY_READBACK_TRANSPORT_UNAVAILABLE');
  }

  // Never accept a caller-controlled origin. The explicit allowlist stays
  // empty until the PagerDuty destination is separately approved.
  const apiBase = assertAllowedAlertEndpoint(PAGERDUTY_API_BASE, allowedApiBases);
  const records = await resolvePublicAlertAddresses(apiBase.hostname, resolveHost);
  const pinnedAddress = records[0];
  const endpoint = new URL('incidents/' + encodeURIComponent(lookupId), apiBase);
  const agent = createPinnedHttpsAgent({
    hostname: apiBase.hostname,
    port: 443,
    address: pinnedAddress,
  });
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  timer.unref?.();

  try {
    let response;
    try {
      response = await requestImpl(endpoint, {
        method: 'GET',
        headers: {
          authorization: 'Token token=' + readOnlyToken,
          accept: PAGERDUTY_ACCEPT,
        },
        agent,
        signal: controller.signal,
        timeoutMs,
      });
    } catch {
      throw new Error('PAGERDUTY_READBACK_NETWORK_FAILED');
    }

    const statusCode = Number(response?.statusCode) || 0;
    if (statusCode === 401) throw new Error('PAGERDUTY_READONLY_AUTH_FAILED');
    if (statusCode === 403) throw new Error('PAGERDUTY_READONLY_FORBIDDEN');
    if (statusCode === 404) throw new Error('PAGERDUTY_INCIDENT_NOT_FOUND');
    if (statusCode === 429) throw new Error('PAGERDUTY_READONLY_RATE_LIMITED');
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error('PAGERDUTY_READONLY_HTTP_' + statusCode);
    }

    let payload;
    try {
      const body = Buffer.isBuffer(response.body)
        ? response.body.toString('utf8')
        : String(response.body ?? '');
      payload = JSON.parse(body);
    } catch {
      throw new Error('PAGERDUTY_INCIDENT_RESPONSE_INVALID');
    }
    const normalized = normalizeIncident(payload?.incident, lookupId);
    return {
      readbackStatus: 'verified',
      incidentExists: true,
      incident: normalized,
    };
  } finally {
    clearTimeout(timer);
    agent.destroy();
  }
}
