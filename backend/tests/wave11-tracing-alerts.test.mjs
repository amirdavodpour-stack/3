import test from 'node:test';
import assert from 'node:assert/strict';
import { traceContext, makeTraceparent } from '../src/tracing.js';
import { businessHealth } from '../src/business_metrics.js';
import { dispatchOperationalAlerts, dispatchSecurityAlert } from '../src/alerting.js';

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
  const event=refreshReuseAlertEvent();
  const result=await dispatchSecurityAlert(event,{
    url:'https://alerts.example.test/security',
    token:'test-alert-token',
    timeoutMs:500,
    fetchImpl:async (url,options) => {
      captured={url,options};
      return {ok:true,status:202};
    },
  });

  assert.deepEqual(result,{dispatched:true});
  assert.equal(captured.url,'https://alerts.example.test/security');
  assert.equal(captured.options.method,'POST');
  assert.equal(captured.options.headers.authorization,'Bearer test-alert-token');
  assert.equal(captured.options.headers['idempotency-key'],`hope-outbox:${event.id}`);
  const body=JSON.parse(captured.options.body);
  assert.deepEqual(body,{
    service:'hope-api',
    eventType:'SECURITY_ALERT',
    occurredAt:'2026-11-07T18:00:00.000Z',
    alert:{
      code:'AUTH_REFRESH_REUSE_DETECTED',
      severity:'page',
      actorUserId:event.aggregate_id,
      tokenFamilyId:event.payload.tokenFamilyId,
    },
  });
  assert.doesNotMatch(JSON.stringify(body),/must-not-be-forwarded|private@example\.test/);
});

test('refresh reuse security alert delivery fails on non-success responses for outbox retry', async () => {
  await assert.rejects(
    dispatchSecurityAlert(refreshReuseAlertEvent(),{
      url:'https://alerts.example.test/security',
      token:'test-alert-token',
      timeoutMs:500,
      fetchImpl:async () => ({ok:false,status:503}),
    }),
    /SECURITY_ALERT_WEBHOOK_HTTP_503/,
  );
});

test('refresh reuse security alert delivery fails closed when no configured receiver exists', async () => {
  await assert.rejects(
    dispatchSecurityAlert(refreshReuseAlertEvent(),{
      url:'',
      token:'',
      fetchImpl:async () => { throw new Error('fetch must not be called'); },
    }),
    /SECURITY_ALERT_WEBHOOK_NOT_CONFIGURED/,
  );
});
