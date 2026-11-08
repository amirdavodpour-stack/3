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


## Terminal security-alert replay (primary administrator only)

Use the replay operation only after the receiver has been restored and its durable `Idempotency-Key` handling has been verified by a non-Production delivery/readback test. Do not replay while receiver delivery is ambiguous or its deduplication behavior is unknown.

Eligibility is intentionally narrow:
- The Outbox event must be `AUTH_REFRESH_REUSE_ALERT`, aggregate type `user`, and terminal `FAILED`.
- It must have no active worker lease.
- Payment, refund, payout, wallet, notification and every other event type are permanently ineligible for this operation.
- A verified primary administrator must have current-session WRITE step-up (including the configured MFA policy).
- Supply a reason between 3 and 1000 characters and exactly one `Idempotency-Key`.
- Before enqueueing, the API also requires a configured HTTPS receiver URL without embedded credentials and a webhook token of at least 32 UTF-8 bytes. A missing or invalid local configuration returns `503 SECURITY_ALERT_REPLAY_UNAVAILABLE` without consuming the one-replay allowance. This preflight does not establish receiver reachability or durable idempotency; a separate non-Production delivery/readback test is still mandatory.

Request:

```http
POST /api/v1/admin/security-alerts/{eventId}/replay
Authorization: Bearer <admin-access-token>
Idempotency-Key: hope-admin-replay-<eventId>
Content-Type: application/json

{"reason":"Receiver restored; non-Production delivery and durable idempotency readback verified."}
```

A successful response reports `status: PENDING`, `replayCount: 1`. The Outbox worker performs delivery asynchronously; the administrator request does not make an outbound webhook call. The original event ID, payload and receiver-facing `Idempotency-Key: hope-outbox:<eventId>` are preserved. The receiver must deduplicate that key durably.

The manual replay is capped at one per event:
- Retry an HTTP request after an ambiguous response using the exact same request `Idempotency-Key`. It returns the stored replay result and does not create a second audit row.
- A different request key for an event already replayed returns `409 OUTBOX_EVENT_ALREADY_REPLAYED`.
- An event outside the allowlist, not in terminal FAILED state, or with an active lease returns a conflict. Do not bypass this guard with direct SQL.
- The state requeue and `ADMIN_SECURITY_ALERT_OUTBOX_REPLAY` audit row commit in one transaction. If the audit write fails, the event remains FAILED and the replay counter is unchanged.
- Migration 053 retains the one-replay evidence and refuses rollback once a replay has been used. Do not attempt to remove that evidence.

After the request, correlate the event ID with the audit row and the subsequent worker delivery outcome. The API response confirms only that the replay was queued (or was an idempotent repeat); it does not prove receiver delivery. Record the downstream HTTP response and receiver-side dedupe/readback separately. Never include raw refresh tokens, token hashes, passwords, email addresses or webhook credentials in the reason, request or audit metadata.

## Delivery and privacy

The alert is delivered through the configured HTTPS `ALERT_WEBHOOK_URL` using the existing `ALERT_WEBHOOK_TOKEN`. Delivery is at-least-once; the receiver must honor the stable `Idempotency-Key` to suppress duplicate retries. The webhook payload contains only the account ID, token-family ID, event time and alert code. Never send, log or request a raw refresh token, password, email address or bearer credential.

If delivery is unconfigured or fails, the outbox retries with bounded backoff and records terminal failure after the configured attempt limit. Restore receiver configuration through the approved owner-operated procedure, then reconcile/replay any terminal failed alert under the normal operational controls. No Production configuration or secret is changed by this runbook.

## Terminal failure log signal and paging boundary

When an `AUTH_REFRESH_REUSE_ALERT` reaches terminal `FAILED` state, the Outbox worker emits a structured JSON log entry with:
- `level: error`
- `action: OUTBOX_SECURITY_ALERT_TERMINAL_FAILURE`
- `eventId`, `eventType`, `attempts`, and the runbook path

The event deliberately excludes the token-family ID, email address, refresh token, token hash, and webhook credentials. It is emitted only after `failOutboxEvent()` confirms the event is terminal; transient failed attempts remain the separate `OUTBOX_FAILED` warning and increment the general security failure counters.

This log entry is an operational signal, not proof of an independent page or receiver delivery. Route the exact action name through an independently managed log collector and paging monitor, then verify collector ingestion and alert delivery in a non-Production environment. Do not rely on `categoryFailures.security` alone for paging: it counts failed attempts, including retries that may later succeed. The independent log sink/pager and its end-to-end verification are not yet confirmed for this deployment.
