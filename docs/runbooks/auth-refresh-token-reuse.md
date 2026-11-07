# Auth refresh-token reuse response

## Signal

`AUTH_REFRESH_REUSE_DETECTED` means a refresh token already marked as revoked was presented again. The API revokes the entire refresh-token family, advances the account session generation, clears administrator panel step-up state, records a durable audit row, and enqueues one operational security alert per account per five-minute bucket.

## Triage

1. Correlate the alert's `actorUserId` and `tokenFamilyId` with the audit record.
2. Confirm the account's refresh family remains revoked and review other recent authentication/security events.
3. Escalate suspected account compromise through the established account-security response process. Do not re-enable the affected refresh family.

Read-only audit query:

```sql
SELECT created_at, actor_id, meta->>'tokenFamilyId' AS token_family_id
  FROM audit_logs
 WHERE action='AUTH_REFRESH_REUSE_DETECTED'
 ORDER BY created_at DESC
 LIMIT 20;
```

## Delivery and privacy

The alert is delivered through the configured HTTPS `ALERT_WEBHOOK_URL` using the existing `ALERT_WEBHOOK_TOKEN`. Delivery is at-least-once; the receiver must honor the stable `Idempotency-Key` to suppress duplicate retries. The webhook payload contains only the account ID, token-family ID, event time and alert code. Never send, log or request a raw refresh token, password, email address or bearer credential.

If delivery is unconfigured or fails, the outbox retries with bounded backoff and records terminal failure after the configured attempt limit. Restore receiver configuration through the approved owner-operated procedure, then reconcile/replay any terminal failed alert under the normal operational controls. No Production configuration or secret is changed by this runbook.
