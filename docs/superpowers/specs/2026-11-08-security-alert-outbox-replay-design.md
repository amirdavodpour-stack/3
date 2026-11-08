# Security-alert Outbox Replay — Design

Date: 2026-11-08
Status: Draft for owner approval
Repository: `amirdavodpour-stack/3`
Target branch: `fix/hopev2-refresh-reuse-alerting-20261107`
Design baseline: PR #49 HEAD `db69e01ffa38a5cca4eacf4d7b85baea869bcf13`

## Intent

Provide a narrow, auditable recovery operation for a terminally failed refresh-token-reuse security alert, without creating a generic Outbox retry mechanism and without changing any financial event semantics. A primary administrator can authorize at most one manual replay for a specific eligible event. Repeating the same request with the same idempotency key returns the original replay outcome; a different key cannot replay the same event again.

## Goals

- Recover only `AUTH_REFRESH_REUSE_ALERT` events in terminal `FAILED` state.
- Require the verified primary administrator, active account, current authenticated session and WRITE step-up verification (MFA policy remains enforced by the existing admin route).
- Require a meaningful operator reason and an explicit `Idempotency-Key`.
- Commit event requeue state and audit evidence atomically.
- Preserve immutable event identity, payload, creation time and the receiver-facing stable key `hope-outbox:<event-id>`.
- Enforce one manual replay per event, including under concurrent requests and lost HTTP responses.
- Preserve worker lease safety: stale callbacks must not overwrite a newly claimed replay attempt.
- Keep financial processing, provider operations and Production deployment/configuration outside scope.

## Non-goals

- No generic retry/replay endpoint for arbitrary Outbox event types.
- No replay for payments, refunds, payouts, wallet operations, notifications or other event classes.
- No automatic or bulk replay, no operator-admin delegation, no replay scheduler and no attempt to make delivery exactly-once.
- No alteration of the alert payload or of the receiver idempotency key.
- No receiver URL, token, secret or Production configuration changes.

## Approaches considered

1. **Dedicated primary-admin API (recommended).** Add one explicit route and one transactional repository operation restricted to the security-alert event type. Persist the single-replay guard and request key on the event row. This offers a controlled recovery path, durable audit, concurrency protection and retry-safe HTTP semantics.
2. **Owner-run manual SQL/operations procedure.** Avoids an API surface, but is difficult to make repeatable, consistently authenticated and audit-atomic. It is unsuitable as the durable operator workflow.
3. **Generic Outbox retry endpoint.** Rejected: the same queue handles financial hold/release/refund/payout operations; broad retries could violate payment state-machine and provider/idempotency assumptions.

## Proposed behavior

### API and authorization

- Route: `POST /admin/security-alerts/:eventId/replay`.
- Route validates `eventId` as UUID, reason as trimmed text between 3 and 1000 characters, and requires one bounded `Idempotency-Key` value (1–200 characters; reject whitespace/control characters).
- Route requires `ADMIN_PERMISSIONS.REPLAY_SECURITY_ALERTS` and `assertPrimaryAdmin(me)`. The permission is intentionally absent from the operational-admin permission subset.
- Existing admin routing must require current-session WRITE step-up. The repository must independently revalidate the active actor, primary-owner identity and WRITE step-up while holding the actor row lock in the same SQL transaction as the event mutation. Do not trust the route's earlier user object as the transactional authorization decision.
- No fallback to the legacy in-memory repository; this capability is PostgreSQL-only and returns unavailable when the database repository is not active.

### Persistent one-replay guard

Add migration `053_security_alert_outbox_manual_replay` with:
- `manual_replay_count SMALLINT NOT NULL DEFAULT 0 CHECK (manual_replay_count IN (0,1))`.
- `manual_replay_idempotency_key TEXT NULL`.
- A consistency constraint: count zero requires a null key; count one requires a non-empty key.

The migration must not rewrite event identity or payload. Its down migration may remove the new columns/constraint only when no event has `manual_replay_count = 1`; otherwise it must refuse rollback because doing so would erase evidence and re-enable replay.

### Transaction and state transition

Repository operation (illustrative contract): `replayFailedSecurityAlert({eventId, actorId, sessionJti, verificationMinutes, reason, idempotencyKey})`.

Within one SQL transaction:
1. Lock and revalidate the acting admin using the existing canonical admin-actor lock helper, with an explicit primary-admin requirement and `requiredScope: 'WRITE'`.
2. Lock the target Outbox row with `SELECT ... FOR UPDATE`.
3. Require exact `event_type='AUTH_REFRESH_REUSE_ALERT'`, `aggregate_type='user'`, non-null `aggregate_id`, and a valid event identifier. Any other event type is rejected, regardless of status.
4. If count is one and the stored key equals the request key, return an idempotent already-replayed result without mutation. If count is one with a different key, return conflict.
5. Otherwise require `status='FAILED'`, no active lease (`lease_token IS NULL` and `locked_at IS NULL`), and count zero.
6. Update only mutable delivery fields: set `status='PENDING'`, `attempts=0`, `available_at=NOW()`, clear `locked_at`, `lease_token`, `last_error`, and `processed_at`; set count to one and persist the request key. Keep event ID, event type, aggregate, dedupe key, payload and created_at unchanged.
7. Insert `ADMIN_SECURITY_ALERT_OUTBOX_REPLAY` into `audit_logs` in the same transaction. Audit metadata includes reason, event ID, actor ID, prior attempts, replay count and idempotency key; it must not include raw tokens, token hashes, alert receiver credentials, or the full event payload.
8. Commit and return the event status, replay count and whether this was the initial or idempotent repeat request.

A failure of the audit insert must roll back the requeue. Concurrent requests serialize on the event row; only one different-key request may perform the transition. The same-key request is safe to repeat even if the worker has already progressed the event to PROCESSING, DONE or FAILED.

### Worker and receiver safety

- The worker remains the only delivery mechanism. No synchronous HTTP call is added to the admin route.
- The original event ID is retained, so receiver deduplication continues to use the existing `hope-outbox:<event-id>` key.
- The sender remains at-least-once. Receiver durable idempotency/readback is a separate release gate and is not made true by this feature.
- Clearing the old lease is allowed only after proving the event is FAILED and has no active lease; the next claim generates a fresh lease token. Stale completion/failure callbacks with the old token must be rejected by existing lease checks.
- Requeue only delivery state. Do not change financial aggregate state or call payment/payout completion helpers.

## TDD acceptance criteria

RED tests must be added and observed failing before implementation. At minimum:

1. Only primary admin with current-session WRITE step-up can replay; operational admin, inactive admin, unverified primary identity and missing/expired/wrong-session step-up are denied.
2. Missing/malformed event UUID, missing/short/oversized/control-character idempotency key, and missing/short/oversized reason are rejected.
3. Only `AUTH_REFRESH_REUSE_ALERT` / `user` aggregate events are eligible; payment/payout/refund/other event types always fail closed.
4. PENDING, PROCESSING, DONE, and FAILED-with-active-lease events cannot be newly replayed.
5. One FAILED eligible event transitions once to PENDING; immutable event identity/payload and receiver idempotency key remain unchanged.
6. A duplicate request with the same key returns an idempotent result without a second state change; a different key returns conflict.
7. Concurrent different-key requests result in exactly one successful initial replay and one conflict.
8. Audit is inserted atomically with the transition; injected audit failure leaves the event FAILED and count zero.
9. The new migration enforces a maximum count of one and refuses down migration after any replay evidence exists.
10. A stale worker lease callback cannot regress or overwrite the replayed event after it is reclaimed.
11. Existing financial Outbox completion/failure and payment state-machine contract tests remain green.

## Security and operational review

- Threat model: compromised/over-privileged admin session; repeated replay attempts; concurrent requests; stale worker callbacks; malicious event ID/key/reason; accidental replay of financial events; audit-write failure; receiver duplicate delivery.
- Controls: primary-admin-only authorization, transactional actor revalidation, current-session WRITE step-up, strict event allowlist, row lock, database CHECK constraint, persisted per-event idempotency key, atomic audit, immutable identity trigger, worker lease token checks, bounded reason/key lengths.
- Residual risk: receiver must implement durable idempotency. A replay may cause a duplicate HTTP delivery; it must not create a duplicate notification side effect at the receiver. The real receiver test remains blocked until a verified non-Production instance and owner-authorized credentials exist.

## Implementation boundaries and sequencing

- Implement only on the existing PR #49 branch. Reconcile exact HEAD immediately before each GitHub write.
- Use TDD: failing route/permission/repository/PG tests first; then minimal implementation and migration; then targeted tests and the full backend suite required by project policy.
- Inspect every diff and run relevant static/financial regression suites. Do not rerun previously green suites without the code change requiring them.
- No merge, rebase, force-push, branch retarget, Main/Production write, Production secret access, deployment or live database mutation.
- Release remains NOT CERTIFIED until all documented certification and runtime evidence gates pass.

## Approval requested

Approve this exact design before implementation. In particular, confirm the dedicated route, PostgreSQL-only behavior, new migration 053, persisted per-event idempotency key, and fail-closed exclusion of every non-security Outbox event.