import test from 'node:test';
import assert from 'node:assert/strict';
import { readPagerDutyIncident } from '../src/pagerduty_incident_readback.js';

const API_BASE = 'https://api.pagerduty.com/';
const TOKEN = 'read-only-test-token-never-used-for-live-requests-32';
const INCIDENT_ID = 'PABC123';
const dns = async (hostname) => {
  assert.equal(hostname, 'api.pagerduty.com');
  return [{ address: '8.8.8.8', family: 4 }];
};
const incident = (overrides = {}) => ({
  id: INCIDENT_ID,
  incident_number: 123,
  status: 'acknowledged',
  created_at: '2026-11-10T12:00:00Z',
  updated_at: '2026-11-10T12:02:00Z',
  resolved_at: null,
  acknowledgements: [{
    at: '2026-11-10T12:01:00Z',
    acknowledger: { id: 'PUSER123', type: 'user_reference' },
  }],
  ...overrides,
});
const fakeResponse = (statusCode, body, headers = {}) => ({
  statusCode, headers, body: JSON.stringify(body),
});
function invoke(overrides = {}) {
  const calls = [];
  const requestImpl = async (url, options) => {
    calls.push({ url: url.href, ...options });
    return fakeResponse(200, { incident: incident() });
  };
  const respond = (statusCode, body = {}) => async (url, options) => {
    calls.push({ url: url.href, ...options });
    return fakeResponse(statusCode, body);
  };
  return {
    calls,
    respond,
    run: (options = {}) => readPagerDutyIncident({
      incidentId: INCIDENT_ID,
      readOnlyToken: TOKEN,
      allowedApiBases: [API_BASE],
      resolveHost: dns,
      requestImpl,
      ...overrides,
      ...options,
    }),
  };
}

test('PagerDuty readback is a single GET to the fixed API host with dedicated read-only token', async () => {
  const h = invoke();
  const result = await h.run();
  assert.equal(h.calls.length, 1);
  assert.equal(h.calls[0].url, 'https://api.pagerduty.com/incidents/PABC123');
  assert.equal(h.calls[0].method, 'GET');
  assert.equal(h.calls[0].headers.authorization, 'Token token=' + TOKEN);
  assert.equal(h.calls[0].headers.accept, 'application/vnd.pagerduty+json;version=2');
  assert.equal(h.calls[0].body, undefined);
  assert.deepEqual(result, {
    readbackStatus: 'verified',
    incidentExists: true,
    incident: {
      id: 'PABC123',
      incidentNumber: 123,
      status: 'acknowledged',
      createdAt: '2026-11-10T12:00:00Z',
      updatedAt: '2026-11-10T12:02:00Z',
      resolvedAt: null,
      userAcknowledged: true,
      humanAcknowledged: false,
      acknowledgements: [{ at: '2026-11-10T12:01:00Z', userId: 'PUSER123' }],
      resolved: false,
    },
  });
});
test('incident existence, human ACK and resolution remain separate independent states', async () => {
  const noAck = invoke();
  const pending = await noAck.run({ requestImpl: noAck.respond(200, { incident: incident({ status: 'triggered', acknowledgements: [] }) }) });
  assert.equal(pending.incidentExists, true);
  assert.equal(pending.incident.userAcknowledged, false);
  assert.equal(pending.incident.humanAcknowledged, false);
  assert.equal(pending.incident.resolved, false);

  const human = invoke();
  const acknowledged = await human.run({ humanAcknowledgerIds: ['PUSER123'] });
  assert.equal(acknowledged.incident.userAcknowledged, true);
  assert.equal(acknowledged.incident.humanAcknowledged, true);

  const resolved = invoke();
  const done = await resolved.run({ requestImpl: resolved.respond(200, { incident: incident({
    status: 'resolved', resolved_at: '2026-11-10T12:10:00Z', acknowledgements: [],
  }) }) });
  assert.equal(done.incidentExists, true);
  assert.equal(done.incident.userAcknowledged, false);
  assert.equal(done.incident.humanAcknowledged, false);
  assert.equal(done.incident.resolved, true);
  assert.equal(done.incident.resolvedAt, '2026-11-10T12:10:00Z');
});
test('automated or malformed acknowledgers do not count as human ACK', async () => {
  const h = invoke();
  const result = await h.run({ requestImpl: async () => fakeResponse(200, { incident: incident({
    acknowledgements: [
      { at: '2026-11-10T12:01:00Z', acknowledger: { id: 'AUTOMATION', type: 'automation_reference' } },
      { at: 'invalid', acknowledger: { id: '', type: 'user_reference' } },
    ],
  }) }) });
  assert.equal(result.incident.userAcknowledged, false);
  assert.equal(result.incident.humanAcknowledged, false);
  assert.deepEqual(result.incident.acknowledgements, []);
});
test('missing credentials, empty base allowlist and malformed incident ID fail before DNS/request', async () => {
  let dnsCalls = 0, requestCalls = 0;
  const noNetwork = { resolveHost: async () => { dnsCalls++; return [{ address: '8.8.8.8', family: 4 }]; },
    requestImpl: async () => { requestCalls++; return fakeResponse(200, { incident: incident() }); } };
  await assert.rejects(readPagerDutyIncident({ incidentId: INCIDENT_ID, allowedApiBases: [API_BASE], ...noNetwork }), /PAGERDUTY_READONLY_CREDENTIAL_REQUIRED/);
  await assert.rejects(readPagerDutyIncident({ incidentId: INCIDENT_ID, readOnlyToken: TOKEN, allowedApiBases: [], ...noNetwork }), /ALERT_EGRESS_ALLOWLIST_REQUIRED/);
  await assert.rejects(readPagerDutyIncident({ incidentId: '../PABC123', readOnlyToken: TOKEN, allowedApiBases: [API_BASE], ...noNetwork }), /PAGERDUTY_INCIDENT_ID_INVALID/);
  assert.equal(dnsCalls, 0);
  assert.equal(requestCalls, 0);
});
test('only the canonical PagerDuty API base is accepted and every DNS answer must be public', async () => {
  const wrongBase = invoke({ allowedApiBases: ['https://evil.example.test/'] });
  await assert.rejects(wrongBase.run(), /ALERT_EGRESS_ALLOWLIST_REQUIRED|ALERT_EGRESS_ENDPOINT_NOT_ALLOWLISTED/);
  const privateDns = invoke({ resolveHost: async () => [
    { address: '8.8.8.8', family: 4 }, { address: '127.0.0.1', family: 4 },
  ] });
  await assert.rejects(privateDns.run(), /ALERT_EGRESS_DNS_ADDRESS_REJECTED/);
  assert.equal(privateDns.calls.length, 0);
});
test('404 does not claim an incident was created and does not retry', async () => {
  const h = invoke();
  await assert.rejects(h.run({ requestImpl: h.respond(404, { error: 'not found' }) }), /PAGERDUTY_INCIDENT_NOT_FOUND/);
  assert.equal(h.calls.length, 1);
});
test('401, 403 and 429 are surfaced as readback errors without write fallback or retry', async () => {
  for (const [status, code] of [[401, 'PAGERDUTY_READONLY_AUTH_FAILED'], [403, 'PAGERDUTY_READONLY_FORBIDDEN'], [429, 'PAGERDUTY_READONLY_RATE_LIMITED']]) {
    const h = invoke();
    await assert.rejects(h.run({ requestImpl: h.respond(status, {}) }), new RegExp(code));
    assert.equal(h.calls.length, 1);
    assert.equal(h.calls[0].method, 'GET');
  }
});
test('unexpected response shape, mismatched incident ID and malformed JSON fail closed', async () => {
  const missing = invoke();
  await assert.rejects(missing.run({ requestImpl: async () => fakeResponse(200, {}) }), /PAGERDUTY_INCIDENT_RESPONSE_INVALID/);
  const mismatch = invoke();
  await assert.rejects(mismatch.run({ requestImpl: async () => fakeResponse(200, { incident: incident({ id: 'POTHER1' }) }) }), /PAGERDUTY_INCIDENT_ID_MISMATCH/);
  const malformed = invoke();
  await assert.rejects(malformed.run({ requestImpl: async () => ({ statusCode: 200, body: '{bad-json' }) }), /PAGERDUTY_INCIDENT_RESPONSE_INVALID/);
});
test('Collector receipt and HOPE Outbox are not mutated by PagerDuty readback', async () => {
  const h = invoke();
  const result = await h.run();
  assert.equal(result.readbackStatus, 'verified');
  assert.equal(h.calls[0].method, 'GET');
  assert.equal('event_action' in h.calls[0], false);
  assert.equal('acknowledge' in h.calls[0], false);
  assert.equal('resolve' in h.calls[0], false);
});
