import dns from 'node:dns/promises';
import https from 'node:https';
import net from 'node:net';
import tls from 'node:tls';

const DEFAULT_TIMEOUT_MS = 3000;
const MAX_REQUEST_BYTES = 64 * 1024;
const MAX_RESPONSE_BYTES = 16 * 1024;
const IDEMPOTENCY_KEY_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,199}$/;

function withTimeout(operation, timeoutMs, errorCode, onTimeout) {
  let timer;
  const operationPromise = Promise.resolve().then(operation);
  const timeoutPromise = new Promise((resolve, reject) => {
    timer = setTimeout(() => {
      try { onTimeout?.(); } catch { /* Timeout outcome remains authoritative. */ }
      reject(new Error(errorCode));
    }, timeoutMs);
  });
  return Promise.race([operationPromise, timeoutPromise]).finally(() => clearTimeout(timer));
}

function parseIpv4(address) {
  if (net.isIP(address) !== 4) return null;
  return address.split('.').reduce((value, part) => (value << 8n) | BigInt(Number(part)), 0n);
}

function parseIpv6(address) {
  if (net.isIP(address) !== 6 || address.includes('%')) return null;
  const lower = address.toLowerCase();
  const halves = lower.split('::');
  if (halves.length > 2) return null;
  const parseSide = (side) => side ? side.split(':').filter(Boolean) : [];
  const left = parseSide(halves[0]);
  const right = halves.length === 2 ? parseSide(halves[1]) : [];
  if (halves.length === 1 && left.length !== 8) return null;
  if (halves.length === 2 && left.length + right.length >= 8) return null;
  const groups = halves.length === 2
    ? [...left, ...Array(8 - left.length - right.length).fill('0'), ...right]
    : left;
  if (groups.length !== 8 || groups.some((part) => !/^[0-9a-f]{1,4}$/.test(part))) return null;
  return groups.reduce((value, part) => (value << 16n) | BigInt(parseInt(part, 16)), 0n);
}

function inCidr(value, base, prefix, bits) {
  const shift = BigInt(bits - prefix);
  return (value >> shift) === (base >> shift);
}

const IPV4_DENY = [
  ['0.0.0.0', 8], ['10.0.0.0', 8], ['100.64.0.0', 10], ['127.0.0.0', 8],
  ['169.254.0.0', 16], ['172.16.0.0', 12], ['192.0.0.0', 24],
  ['192.0.2.0', 24], ['192.88.99.0', 24], ['192.168.0.0', 16],
  ['198.18.0.0', 15], ['198.51.100.0', 24], ['203.0.113.0', 24],
  ['224.0.0.0', 4], ['240.0.0.0', 4],
].map(([base, prefix]) => [parseIpv4(base), prefix]);

const IPV6_DENY = [
  ['2001::', 23],       // IETF protocol assignments, including Teredo/ORCHID space
  ['2001:db8::', 32],    // Documentation
  ['2002::', 16],        // 6to4
  ['3fff::', 20],        // Documentation
  ['64:ff9b::', 96],     // Well-known NAT64
  ['64:ff9b:1::', 48],   // Local-use NAT64
  ['2001:10::', 28],     // ORCHIDv1
].map(([base, prefix]) => [parseIpv6(base), prefix]);

function normalizeIp(address) {
  const family = net.isIP(address);
  if (family === 4) return { family, value: parseIpv4(address), text: address };
  if (family === 6) return { family, value: parseIpv6(address), text: address.toLowerCase() };
  return null;
}

export function isPublicAlertAddress(address) {
  const parsed = normalizeIp(String(address || ''));
  if (!parsed || parsed.value === null) return false;
  if (parsed.family === 4) {
    return !IPV4_DENY.some(([base, prefix]) => inCidr(parsed.value, base, prefix, 32));
  }
  // Permit only global-unicast 2000::/3, then exclude protocol and special-use ranges.
  if (!inCidr(parsed.value, parseIpv6('2000::'), 3, 128)) return false;
  return !IPV6_DENY.some(([base, prefix]) => inCidr(parsed.value, base, prefix, 128));
}

function validCanonicalEndpoint(value) {
  if (typeof value !== 'string' || !value || value.includes('\\')) return null;
  let endpoint;
  try {
    endpoint = new URL(value);
  } catch {
    return null;
  }
  if (
    endpoint.protocol !== 'https:' ||
    !endpoint.hostname ||
    endpoint.username ||
    endpoint.password ||
    (endpoint.port && endpoint.port !== '443') ||
    endpoint.search ||
    endpoint.hash ||
    net.isIP(endpoint.hostname.replace(/^\[|\]$/g, '')) ||
    endpoint.href !== value ||
    /%(?:2f|5c)/i.test(endpoint.pathname)
  ) return null;
  const decodedSegments = endpoint.pathname.split('/').map((segment) => {
    try { return decodeURIComponent(segment); } catch { return null; }
  });
  if (decodedSegments.some((segment) => segment === null || segment === '.' || segment === '..')) return null;
  if (!endpoint.hostname.includes('.') || endpoint.hostname.startsWith('.') || endpoint.hostname.endsWith('.')) return null;
  if (endpoint.hostname.includes('*')) return null;
  return endpoint;
}

export function assertAllowedAlertEndpoint(value, allowedEndpoints) {
  if (!Array.isArray(allowedEndpoints) || allowedEndpoints.length === 0) {
    throw new Error('ALERT_EGRESS_ALLOWLIST_REQUIRED');
  }
  const endpoint = validCanonicalEndpoint(value);
  if (!endpoint) throw new Error('ALERT_EGRESS_ENDPOINT_INVALID');
  const allowed = allowedEndpoints.map(validCanonicalEndpoint);
  if (allowed.some((candidate) => !candidate)) throw new Error('ALERT_EGRESS_ALLOWLIST_INVALID');
  if (!allowed.some((candidate) => candidate.href === endpoint.href)) {
    throw new Error('ALERT_EGRESS_ENDPOINT_NOT_ALLOWLISTED');
  }
  return endpoint;
}

export async function resolvePublicAlertAddresses(hostname, resolver = (host) => dns.lookup(host, { all: true, verbatim: true })) {
  if (typeof hostname !== 'string' || !hostname || net.isIP(hostname)) {
    throw new Error('ALERT_EGRESS_HOST_INVALID');
  }
  let records;
  try {
    records = await resolver(hostname);
  } catch {
    throw new Error('ALERT_EGRESS_DNS_RESOLUTION_FAILED');
  }
  if (!Array.isArray(records) || records.length === 0) throw new Error('ALERT_EGRESS_DNS_EMPTY');
  const normalized = records.map((record) => {
    const address = typeof record === 'string' ? record : record?.address;
    const family = net.isIP(String(address || ''));
    return { address: String(address || ''), family };
  });
  if (normalized.some((record) => !record.family || !isPublicAlertAddress(record.address))) {
    throw new Error('ALERT_EGRESS_DNS_ADDRESS_REJECTED');
  }
  const unique = new Map();
  for (const record of normalized) unique.set(record.family + ':' + record.address.toLowerCase(), record);
  return [...unique.values()];
}

function sameIp(left, right) {
  const a = normalizeIp(String(left || ''));
  const b = normalizeIp(String(right || ''));
  return Boolean(a && b && a.family === b.family && a.value === b.value);
}

export function createPinnedHttpsAgent({
  hostname,
  port = 443,
  address,
  tlsConnect = tls.connect,
} = {}) {
  if (!hostname || net.isIP(hostname) || Number(port) !== 443 || !address?.address || !isPublicAlertAddress(address.address)) {
    throw new Error('ALERT_EGRESS_PIN_CONFIGURATION_INVALID');
  }
  const agent = new https.Agent({ keepAlive: false, maxSockets: 1, maxFreeSockets: 0 });
  agent.createConnection = (_options, callback) => {
    let socket;
    try {
      socket = tlsConnect({
        host: address.address,
        port: 443,
        family: address.family,
        servername: hostname,
        rejectUnauthorized: true,
        checkServerIdentity: (_ignoredHost, certificate) => tls.checkServerIdentity(hostname, certificate),
      });
    } catch {
      const error = new Error('ALERT_EGRESS_TLS_CONNECTION_FAILED');
      if (callback) callback(error);
      else throw error;
      return undefined;
    }
    let settled = false;
    const fail = (code) => {
      if (settled) return;
      settled = true;
      socket.destroy?.();
      callback?.(new Error(code));
    };
    socket.once('error', () => fail('ALERT_EGRESS_TLS_CONNECTION_FAILED'));
    socket.once('secureConnect', () => {
      if (socket.authorized !== true) return fail('ALERT_EGRESS_TLS_CERTIFICATE_REJECTED');
      if (!sameIp(socket.remoteAddress, address.address)) return fail('ALERT_EGRESS_PEER_ADDRESS_MISMATCH: peer address mismatch');
      if (settled) return;
      settled = true;
      callback?.(null, socket);
    });
    return socket;
  };
  return agent;
}

function performHttpsRequest(endpoint, options) {
  return new Promise((resolve, reject) => {
    const request = https.request(endpoint, {
      method: options.method,
      headers: options.headers,
      agent: options.agent,
      signal: options.signal,
    }, (response) => {
      const chunks = [];
      let size = 0;
      response.on('data', (chunk) => {
        size += chunk.length;
        if (size > MAX_RESPONSE_BYTES) {
          request.destroy(new Error('ALERT_EGRESS_RESPONSE_TOO_LARGE'));
          return;
        }
        chunks.push(chunk);
      });
      response.on('end', () => {
        const statusCode = Number(response.statusCode) || 0;
        resolve({
          statusCode,
          ok: statusCode >= 200 && statusCode < 300,
          headers: response.headers,
          body: Buffer.concat(chunks).toString('utf8'),
        });
      });
      response.on('error', () => reject(new Error('ALERT_EGRESS_RESPONSE_FAILED')));
    });
    request.setTimeout(options.timeoutMs, () => request.destroy(new Error('ALERT_EGRESS_TIMEOUT')));
    request.on('error', () => reject(new Error('ALERT_EGRESS_REQUEST_FAILED')));
    request.end(options.body);
  });
}

export async function dispatchAlertWebhook({
  url,
  token,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  body,
  idempotencyKey,
  allowedEndpoints = [],
  egressMode = '',
  directEgressAcknowledged = false,
  resolveHost,
  requestImpl = performHttpsRequest,
} = {}) {
  // All policy gates run before DNS, socket creation, or any outbound request.
  const endpoint = assertAllowedAlertEndpoint(url, allowedEndpoints);
  if (egressMode !== 'direct') throw new Error('ALERT_EGRESS_MODE_NOT_APPROVED: egress mode not approved');
  if (directEgressAcknowledged !== true) throw new Error('ALERT_DIRECT_EGRESS_NOT_AUTHORIZED: direct egress not authorized');
  if (typeof token !== 'string' || !token) throw new Error('ALERT_EGRESS_TOKEN_REQUIRED');
  if (typeof body !== 'string' && !Buffer.isBuffer(body)) throw new Error('ALERT_EGRESS_BODY_INVALID');
  if (Buffer.byteLength(body) > MAX_REQUEST_BYTES) throw new Error('ALERT_EGRESS_BODY_TOO_LARGE');
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 500 || timeoutMs > 30000) {
    throw new Error('ALERT_EGRESS_TIMEOUT_INVALID');
  }
  if (typeof requestImpl !== 'function') throw new Error('ALERT_EGRESS_TRANSPORT_UNAVAILABLE');
  if (typeof idempotencyKey !== 'string' || !IDEMPOTENCY_KEY_PATTERN.test(idempotencyKey)) {
    throw new Error('ALERT_EGRESS_IDEMPOTENCY_KEY_INVALID');
  }

  // The configured budget covers DNS plus the HTTPS request, not just socket activity.
  const deliveryStartedAt = Date.now();
  const records = await withTimeout(
    () => resolvePublicAlertAddresses(endpoint.hostname, resolveHost),
    timeoutMs,
    'ALERT_EGRESS_DNS_TIMEOUT',
  );
  const remainingTimeoutMs = timeoutMs - (Date.now() - deliveryStartedAt);
  if (remainingTimeoutMs <= 0) throw new Error('ALERT_EGRESS_TIMEOUT');

  // Pin one member of the already-validated answer set. Never re-resolve at connect time.
  const pinnedAddress = records[0];
  const agent = createPinnedHttpsAgent({ hostname: endpoint.hostname, port: 443, address: pinnedAddress });
  const controller = new AbortController();
  const headers = {
    'content-type': 'application/json',
    authorization: 'Bearer ' + token,
    'idempotency-key': idempotencyKey,
  };
  try {
    return await withTimeout(
      () => requestImpl(endpoint, {
        method: 'POST',
        headers,
        body,
        agent,
        signal: controller.signal,
        timeoutMs: remainingTimeoutMs,
      }),
      remainingTimeoutMs,
      'ALERT_EGRESS_TIMEOUT',
      () => controller.abort(),
    );
  } catch (error) {
    if (error?.message === 'ALERT_EGRESS_TIMEOUT') throw error;
    throw new Error('ALERT_EGRESS_DELIVERY_FAILED');
  } finally {
    agent.destroy();
  }
}
