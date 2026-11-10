import test from 'node:test';
import { assertAllowedAlertEndpoint, isPublicAlertAddress, resolvePublicAlertAddresses, createPinnedHttpsAgent, dispatchAlertWebhook } from '../src/alert_egress.js';
import assert from 'node:assert/strict';
import { traceContext, makeTraceparent } from '../src/tracing.js';
import { businessHealth } from '../src/business_metrics.js';
import { dispatchOperationalAlerts, dispatchSecurityAlert } from '../src/alerting.js';
import { config } from '../src/config.js';

test('traceparent is accepted and propagated with stable trace id', () => {
  const req = { headers: { traceparent: '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01' } };
  const ctx = traceContext(req);
  assert.equal(ctx.traceId, '4bf92f3577b34da6a3ce929d0e0e4736');
  assert.equal(ctx.parentId, '00f067aa0ba902b7');
  assert.match(makeTraceparent(ctx), /^00-4bf92f3577b34da6a3ce929d0e0e4736-[0-9a-f]{16}-01$/);
});

test('invalid traceparent gets a new trace context', () => {
  const ctx = traceContext({ headers: { traceparent: 'garbage' } });
  assert.match(ctx.traceId, /^[0-9a-f]{32}$/);
  assert.equal(ctx.parentId, null);
});

test('business health raises critical and warning alerts deterministically', () => {
  const critical = businessHealth({ requests: 100, errors5xx: 3, requestDurationBuckets: { lt50: 97, gte500: 3 } });
  assert.equal(critical.alerts[0].code, 'HTTP_5XX_RATE_HIGH');
  assert.equal(critical.alerts[0].severity, 'critical');
  const warning = businessHealth({ requests: 100, errors5xx: 1, requestDurationBuckets: { lt50: 80, gte500: 20 } });
  assert.equal(warning.alerts[0].code, 'HTTP_5XX_RATE_ELEVATED');
  assert.equal(warning.alerts[1].code, 'SLOW_REQUEST_RATE_HIGH');
});


test('disabled alert delivery is a no-op', async () => {
  const result = await dispatchOperationalAlerts({ health: { alerts: [] } });
  assert.equal(result.dispatched, false);
});

test('operational alerts use the exact allowlisted pinned HTTPS transport', async () => {
  const previousUrl = config.alertWebhookUrl;
  const previousToken = config.alertWebhookToken;
  const previousTimeout = config.alertWebhookTimeoutMs;
  let captured;
  const url = 'https://alerts.example.test/operations';
  config.alertWebhookUrl = url;
  config.alertWebhookToken = 'test-operational-alert-token';
  config.alertWebhookTimeoutMs = 500;
  try {
    const result = await dispatchOperationalAlerts({
      health: { alerts: [{ code: 'HTTP_5XX_RATE_HIGH', severity: 'critical' }] },
      recentHealth: { requests: 10, errors5xx: 2 },
      latency: { p95: 20, p99: 50 },
    }, {
      egressOptions: {
        allowedEndpoints: [url],
        egressMode: 'direct',
        directEgressAcknowledged: true,
        resolveHost: async () => [{ address: '8.8.8.8', family: 4 }],
        requestImpl: async (endpoint, options) => {
          captured = { url: endpoint.href, options };
          return { ok: true, statusCode: 202 };
        },
      },
    });
    assert.deepEqual(result, { dispatched: true });
    assert.equal(captured.url, url);
    assert.equal(captured.options.method, 'POST');
    assert.equal(captured.options.headers.authorization, 'Bearer test-operational-alert-token');
    assert.equal(captured.options.agent.options.keepAlive, false);
    assert.equal(captured.options.headers['idempotency-key'], 'hope-operational:HTTP_5XX_RATE_HIGH:critical');
  } finally {
    config.alertWebhookUrl = previousUrl;
    config.alertWebhookToken = previousToken;
    config.alertWebhookTimeoutMs = previousTimeout;
  }
});

test('operational alert failures do not leak endpoint, response or credential details', async () => {
  const previousUrl = config.alertWebhookUrl;
  const previousToken = config.alertWebhookToken;
  const previousTimeout = config.alertWebhookTimeoutMs;
  const failureMessage = 'redirect rejected https://redirect.example.test/target?token=redirect-secret';
  let callbackCount = 0;
  let callbackArguments = null;
  const url = 'https://alerts.example.test/operations';
  config.alertWebhookUrl = url;
  config.alertWebhookToken = 'test-operational-alert-token';
  config.alertWebhookTimeoutMs = 500;
  try {
    const result = await dispatchOperationalAlerts({
      health: { alerts: [{ code: 'OPERATIONAL_ALERT_FAILURE_TEST', severity: 'critical' }] },
      recentHealth: { requests: 10, errors5xx: 2 },
      latency: { p95: 20, p99: 50 },
    }, {
      onDeliveryFailure: (...args) => {
        callbackCount += 1;
        callbackArguments = args;
        throw new Error('test logger failure');
      },
      egressOptions: {
        allowedEndpoints: [url],
        egressMode: 'direct',
        directEgressAcknowledged: true,
        resolveHost: async () => [{ address: '8.8.8.8', family: 4 }],
        requestImpl: async () => { throw new Error(failureMessage); },
      },
    });
    assert.deepEqual(result, { dispatched: false, reason: 'delivery-failed' });
    assert.equal(callbackCount, 1);
    assert.deepEqual(callbackArguments, []);
    assert.doesNotMatch(JSON.stringify(result), /redirect-secret|redirect\.example\.test/);
  } finally {
    config.alertWebhookUrl = previousUrl;
    config.alertWebhookToken = previousToken;
    config.alertWebhookTimeoutMs = previousTimeout;
  }
});

function refreshReuseAlertEvent() {
  return {
    id:'5a2fd1d8-ae0e-4f53-ae67-4d7723db9db1',
    event_type:'AUTH_REFRESH_REUSE_ALERT',
    aggregate_type:'user',
    aggregate_id:'a2f91b32-4d92-4f3f-9bc6-2bb3efaa9b91',
    created_at:'2026-11-07T18:00:00.000Z',
    payload:{
      alertCode:'AUTH_REFRESH_REUSE_DETECTED',
      tokenFamilyId:'f4cc39f3-12c8-4d17-89e8-4b1aefe4b22d',
      refreshToken:'must-not-be-forwarded',
      email:'private@example.test',
    },
  };
}

test('refresh reuse security alerts use stable outbox idempotency and allowlisted metadata only', async () => {
  let captured;
  const event = refreshReuseAlertEvent();
  const url = 'https://alerts.example.test/security';
  const result = await dispatchSecurityAlert(event, {
    url,
    token: 'test-alert-token',
    timeoutMs: 500,
    egressOptions: {
      allowedEndpoints: [url],
      egressMode: 'direct',
      directEgressAcknowledged: true,
      resolveHost: async () => [{ address: '8.8.8.8', family: 4 }],
      requestImpl: async (endpoint, options) => {
        captured = { url: endpoint.href, options };
        return { ok: true, statusCode: 202 };
      },
    },
  });

  assert.deepEqual(result, { dispatched: true });
  assert.equal(captured.url, url);
  assert.equal(captured.options.method, 'POST');
  assert.equal(captured.options.headers.authorization, 'Bearer test-alert-token');
  assert.equal(captured.options.headers['idempotency-key'], 'hope-outbox:' + event.id);
  const body = JSON.parse(captured.options.body);
  assert.deepEqual(body, {
    service: 'hope-api',
    eventType: 'SECURITY_ALERT',
    occurredAt: '2026-11-07T18:00:00.000Z',
    alert: {
      code: 'AUTH_REFRESH_REUSE_DETECTED',
      severity: 'page',
      actorUserId: event.aggregate_id,
      tokenFamilyId: event.payload.tokenFamilyId,
      runbook: 'docs/runbooks/auth-refresh-token-reuse.md',
    },
  });
  assert.doesNotMatch(JSON.stringify(body), /must-not-be-forwarded|private@example\.test/);
  captured.options.agent.destroy();
});

test('refresh reuse security alert delivery fails on non-success responses for outbox retry', async () => {
  const url = 'https://alerts.example.test/security';
  await assert.rejects(
    dispatchSecurityAlert(refreshReuseAlertEvent(), {
      url,
      token: 'test-alert-token',
      timeoutMs: 500,
      egressOptions: {
        allowedEndpoints: [url],
        egressMode: 'direct',
        directEgressAcknowledged: true,
        resolveHost: async () => [{ address: '8.8.8.8', family: 4 }],
        requestImpl: async () => ({ ok: false, statusCode: 503 }),
      },
    }),
    /SECURITY_ALERT_WEBHOOK_HTTP_503/,
  );
});

test('refresh reuse security alert delivery fails closed when no configured receiver exists', async () => {
  await assert.rejects(
    dispatchSecurityAlert(refreshReuseAlertEvent(), {
      url: '',
      token: '',
      egressOptions: {
        requestImpl: async () => { throw new Error('request must not be called'); },
      },
    }),
    /SECURITY_ALERT_WEBHOOK_NOT_CONFIGURED/,
  );
});


test('alert egress allowlist requires an exact canonical HTTPS FQDN, port, and path', () => {
  const allowed = ['https://alerts.example.test/security'];
  assert.equal(
    assertAllowedAlertEndpoint('https://alerts.example.test/security', allowed).href,
    'https://alerts.example.test/security',
  );
  for (const rejected of [
    'https://other.example.test/security',
    'https://alerts.example.test/operations',
    'https://alerts.example.test:8443/security',
    'http://alerts.example.test/security',
    'https://user:pass@alerts.example.test/security',
    'https://127.0.0.1/security',
    'https://alerts.example.test/security?token=secret',
    'https://alerts.example.test/security#fragment',
    'https://alerts.example.test/a/../security',
  ]) {
    assert.throws(() => assertAllowedAlertEndpoint(rejected, allowed));
  }
  assert.throws(() => assertAllowedAlertEndpoint('https://alerts.example.test/security', []));
  assert.throws(() => assertAllowedAlertEndpoint('https://alerts.example.test/security', ['https://*.example.test/security']));
});

test('alert egress accepts only globally routable unicast IP addresses', () => {
  for (const address of ['8.8.8.8', '1.1.1.1', '2606:4700:4700::1111']) {
    assert.equal(isPublicAlertAddress(address), true, address);
  }
  for (const address of [
    '0.0.0.0', '10.1.2.3', '100.64.0.1', '127.0.0.1', '169.254.1.1',
    '172.16.0.1', '192.168.1.1', '192.0.2.1', '198.18.0.1',
    '198.51.100.2', '203.0.113.2', '224.0.0.1', '240.0.0.1',
    '::', '::1', '::ffff:8.8.8.8', '64:ff9b::808:808', 'fc00::1',
    'fe80::1', 'ff02::1', '2001:db8::1', '2002::1',
  ]) {
    assert.equal(isPublicAlertAddress(address), false, address);
  }
});

test('alert egress rejects DNS answers containing any private or special-use address', async () => {
  await assert.rejects(
    resolvePublicAlertAddresses('alerts.example.test', async () => [
      { address: '8.8.8.8', family: 4 },
      { address: '10.0.0.9', family: 4 },
    ]),
  );
  await assert.rejects(
    resolvePublicAlertAddresses('alerts.example.test', async () => [
      { address: '2606:4700:4700::1111', family: 6 },
      { address: '::ffff:8.8.8.8', family: 6 },
    ]),
  );
  await assert.rejects(resolvePublicAlertAddresses('alerts.example.test', async () => []));
});

test('pinned HTTPS agent preserves the original TLS hostname and verifies the actual peer address', async () => {
  const { EventEmitter } = await import('node:events');
  const socket = new EventEmitter();
  socket.remoteAddress = '8.8.8.8';
  socket.authorized = true;
  socket.destroy = () => { socket.destroyed = true; };
  let tlsOptions;
  const agent = createPinnedHttpsAgent({
    hostname: 'alerts.example.test',
    port: 443,
    address: { address: '8.8.8.8', family: 4 },
    tlsConnect: (options) => { tlsOptions = options; return socket; },
  });
  const connected = new Promise((resolve, reject) => {
    agent.createConnection({}, (error, connectedSocket) => error ? reject(error) : resolve(connectedSocket));
    socket.emit('secureConnect');
  });
  assert.equal(await connected, socket);
  assert.equal(tlsOptions.host, '8.8.8.8');
  assert.equal(tlsOptions.servername, 'alerts.example.test');
  assert.equal(tlsOptions.rejectUnauthorized, true);
  agent.destroy();
});

test('pinned HTTPS agent refuses a socket whose peer differs from the validated DNS address', async () => {
  const { EventEmitter } = await import('node:events');
  const socket = new EventEmitter();
  socket.remoteAddress = '1.1.1.1';
  socket.authorized = true;
  socket.destroy = () => { socket.destroyed = true; };
  const agent = createPinnedHttpsAgent({
    hostname: 'alerts.example.test',
    port: 443,
    address: { address: '8.8.8.8', family: 4 },
    tlsConnect: () => socket,
  });
  const result = new Promise((resolve) => {
    agent.createConnection({}, (error) => resolve(error));
    socket.emit('secureConnect');
  });
  const error = await result;
  assert.match(error.message, /peer address/i);
  assert.equal(socket.destroyed, true);
  agent.destroy();
});

test('alert egress fails closed until allowlist and an explicitly authorized direct route exist', async () => {
  let resolutionCount = 0;
  let requestCount = 0;
  const base = {
    url: 'https://alerts.example.test/security',
    token: 'test-alert-token',
    timeoutMs: 500,
    body: '{}',
    allowedEndpoints: [],
    egressMode: '',
    directEgressAcknowledged: false,
    resolveHost: async () => { resolutionCount += 1; return [{ address: '8.8.8.8', family: 4 }]; },
    requestImpl: async () => { requestCount += 1; return { statusCode: 202 }; },
  };
  await assert.rejects(dispatchAlertWebhook(base), /allowlist/i);
  await assert.rejects(dispatchAlertWebhook({ ...base, allowedEndpoints: [base.url] }), /egress mode/i);
  await assert.rejects(dispatchAlertWebhook({ ...base, allowedEndpoints: [base.url], egressMode: 'direct' }), /direct egress.*authorized/i);
  assert.equal(resolutionCount, 0);
  assert.equal(requestCount, 0);
});

test('alert egress validates every DNS answer and passes a pinned agent to the HTTPS transport', async () => {
  let captured;
  const url = 'https://alerts.example.test/security';
  const result = await dispatchAlertWebhook({
    url,
    token: 'test-alert-token',
    timeoutMs: 500,
    body: '{"event":"test"}',
    idempotencyKey: 'hope-outbox:test-id',
    allowedEndpoints: [url],
    egressMode: 'direct',
    directEgressAcknowledged: true,
    resolveHost: async (hostname) => {
      assert.equal(hostname, 'alerts.example.test');
      return [
        { address: '8.8.8.8', family: 4 },
        { address: '1.1.1.1', family: 4 },
      ];
    },
    requestImpl: async (endpoint, options) => {
      captured = { endpoint: endpoint.href, options };
      return { statusCode: 202, ok: true };
    },
  });
  assert.deepEqual(result, { statusCode: 202, ok: true });
  assert.equal(captured.endpoint, url);
  assert.equal(captured.options.method, 'POST');
  assert.equal(captured.options.headers.authorization, 'Bearer test-alert-token');
  assert.equal(captured.options.headers['idempotency-key'], 'hope-outbox:test-id');
  assert.equal(captured.options.agent.options.keepAlive, false);
  captured.options.agent.destroy();
});


test('alert egress requires a bounded printable idempotency key before DNS or transport', async () => {
  let resolutionCount = 0;
  let requestCount = 0;
  const url = 'https://alerts.example.test/security';
  const base = {
    url,
    token: 'test-alert-token',
    timeoutMs: 500,
    body: '{}',
    allowedEndpoints: [url],
    egressMode: 'direct',
    directEgressAcknowledged: true,
    resolveHost: async () => {
      resolutionCount += 1;
      return [{ address: '8.8.8.8', family: 4 }];
    },
    requestImpl: async () => {
      requestCount += 1;
      return { ok: true, statusCode: 202 };
    },
  };

  for (const idempotencyKey of [undefined, '', 123, 'contains whitespace', 'contains\\nnewline', 'x'.repeat(201)]) {
    await assert.rejects(
      dispatchAlertWebhook({ ...base, idempotencyKey }),
      /ALERT_EGRESS_IDEMPOTENCY_KEY_INVALID/,
    );
  }
  assert.equal(resolutionCount, 0, 'invalid idempotency must fail before DNS');
  assert.equal(requestCount, 0, 'invalid idempotency must fail before transport');
});

test('alert egress bounds DNS resolution by the configured delivery timeout', async () => {
  let requestCount = 0;
  let finishDns;
  const pendingDns = new Promise((resolve) => { finishDns = resolve; });
  const url = 'https://alerts.example.test/security';

  const delivery = dispatchAlertWebhook({
    url,
    token: 'test-alert-token',
    timeoutMs: 500,
    body: '{}',
    idempotencyKey: 'hope-outbox:bounded-dns-test',
    allowedEndpoints: [url],
    egressMode: 'direct',
    directEgressAcknowledged: true,
    resolveHost: () => pendingDns,
    requestImpl: async () => {
      requestCount += 1;
      return { ok: true, statusCode: 202 };
    },
  });

  await assert.rejects(delivery, /ALERT_EGRESS_DNS_TIMEOUT/);
  assert.equal(requestCount, 0, 'transport must not start after DNS exhausts the delivery budget');
  finishDns([{ address: '8.8.8.8', family: 4 }]);
});

test('alert egress bounds transport time after DNS resolution', async () => {
  const url = 'https://alerts.example.test/security';
  const delivery = dispatchAlertWebhook({
    url,
    token: 'test-alert-token',
    timeoutMs: 500,
    body: '{}',
    idempotencyKey: 'hope-outbox:bounded-transport-test',
    allowedEndpoints: [url],
    egressMode: 'direct',
    directEgressAcknowledged: true,
    resolveHost: async () => [{ address: '8.8.8.8', family: 4 }],
    requestImpl: () => new Promise(() => {}),
  });

  await assert.rejects(delivery, /ALERT_EGRESS_TIMEOUT/);
});
