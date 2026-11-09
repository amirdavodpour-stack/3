# Security-alert Outbox Replay Implementation Plan

Status: IN PROGRESS — approved design; implementation and regression verification underway on PR #49.

> **For agentic workers:** Use superpowers:executing-plans inline. This project has no available local worktree executor at this time; use the existing authorized PR #49 branch and commit isolated TDD steps through GitHub. Preserve the PR stack.

**Goal:** Enable one durable, retry-safe manual replay for terminally FAILED refresh-token-reuse alerts, limited to the verified primary administrator, with reason-required transactional audit.

**Architecture:** Add a PostgreSQL repository operation to the existing Outbox repository, guarded by the existing transactional admin-actor authorization helper. Add an admin-only route and permission; keep delivery asynchronous through the existing worker. Add migration 053 for a one-replay counter and persisted request idempotency key. All non-security Outbox types fail closed.

**Tech Stack:** Node.js ESM, PostgreSQL, node:test, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-08-security-alert-outbox-replay-design.md`

## Global Constraints
- Work only on `fix/hopev2-refresh-reuse-alerting-20261107`, PR #49.
- Preserve PR #38 → #47 → #48 → #49 OPEN / DRAFT / UNMERGED.
- No main/Production writes, Production secrets, deployments, merge, rebase, force-push, retarget or destructive actions.
- No generic Outbox retry. Only `AUTH_REFRESH_REUSE_ALERT` with `aggregate_type='user'`.
- Preserve immutable Outbox identity/payload and receiver key `hope-outbox:<event-id>`.
- Require active primary admin, current-session WRITE step-up, mandatory reason and idempotency key.
- Atomically commit Outbox requeue and audit; preserve one-replay cap under concurrency.
- Never execute migration 053 against persistent environments during this task.

## Review Focus
- Duplicate initial request after lost response must not replay twice.
- Concurrent distinct idempotency keys must serialize to one replay only.
- Stale worker callbacks from the old lease must not overwrite a new attempt.
- Non-security financial events must never become eligible, even if FAILED.
- A failed audit insert must roll back the Outbox state transition.

---

### Task 1: PostgreSQL replay state and repository transaction

**Files:**
- Create: `backend/src/db/migrations/053_security_alert_outbox_manual_replay.js`
- Modify: `backend/src/repository/outbox.js`
- Modify: `backend/src/repository/admin_authorization.js`
- Create: `backend/tests/postgres-security-alert-outbox-replay.test.mjs`
- Modify: `backend/tools/run-chat-postgres-isolated.mjs`
- Modify: `backend/package.json` (migration check and PostgreSQL test script)

**Interfaces:**
- `replaySecurityAlert({eventId, actorId, sessionJti, verificationMinutes, reason, idempotencyKey})`
- `lockAuthorizedAdminActor(client, {actorId, sessionJti, verificationMinutes, requiredScope:'WRITE', requirePrimaryAdmin:true})`
- Migration adds `manual_replay_count SMALLINT NOT NULL DEFAULT 0 CHECK (manual_replay_count IN (0,1))`, `manual_replay_idempotency_key TEXT NULL`, and consistency constraint. Down refuses once count is 1.

- [x] Write PostgreSQL tests for first replay, immutable identity preservation, same-key idempotent repeat, different-key conflict, non-security rejection, wrong aggregate rejection, invalid states, active lease, role/identity/session/scope denial, concurrent requests, audit failure rollback, migration count guard and rollback refusal. RED was observed on the test-only cursor: run 42456459566 had the expected missing migration/repository API failures.
- [x] Run only the new PostgreSQL test file and confirm expected failures due to missing migration/repository API.
- [x] Implement migration 053 and repository transaction. Lock/revalidate active primary actor first, then Outbox row. Validate all arguments in repository as well as Route. Commit the event update and audit insert in one transaction. Never touch financial aggregate rows. Migration uses a table-level exclusive lock before rollback evidence checks; additional suspended-actor and stale-completion tests are included.
- [x] Run the new PostgreSQL test file through the real isolated PostgreSQL workflow and run migration/Outbox contracts. Baseline implementation passed 128/128 on run 42456644944; subsequent strict key/constraint tests passed on run 42456978425. Latest race-guard additions are being revalidated in run 42457210916.
- [x] Update package scripts so `check:migrations` validates 053 and `test:postgres` includes the new integration test; the isolated runner also includes the new test file.
- [x] Commit the focused migration, authorization helper and repository changes on the existing PR #49 branch (separate commits retained for auditability).

### Task 2: Admin permission and API route

**Files:**
- Modify: `backend/src/application/admin_panel_access.js`
- Modify: `backend/src/routes/admin_routes.js`
- Modify: `backend/src/application/use_cases/admin_use_cases.js`
- Modify: `backend/src/application/ports/repository_ports.js`
- Create: `backend/tests/security-alert-outbox-replay-route.test.mjs`
- Modify: `backend/tests/primary-admin-policy.test.mjs`

**Interfaces:**
- New permission: `ADMIN_PERMISSIONS.REPLAY_SECURITY_ALERTS = 'admin.replay_security_alerts'`.
- Application use case: `adminUseCases.replaySecurityAlert(options)`.
- Route: `POST /admin/security-alerts/:eventId/replay`.
- Headers: exactly one `Idempotency-Key`; body: `{reason}`.

- [x] Write route and permission tests before implementation and observe RED: run 42456701852 failed four new route scenarios with `Admin route not found`, while the remaining Backend Fast tests ran. Coverage includes primary admin, operational-admin denial, current WRITE step-up, malformed inputs and PostgreSQL-only behavior.
- [x] Confirm route RED was caused by the missing endpoint, not test setup.
- [x] Implement the permission, use-case, repository port and route. Reuse existing route-level WRITE step-up. Revalidate primary owner and step-up again inside the repository transaction. Reject any fallback to legacy storage.
- [x] Run route tests, primary-admin policy tests and admin transaction authorization in Backend Fast; the route suite and security audit passed on run 42456823282. Additional OpenAPI contract assertions are being revalidated on the current run.
- [x] Commit permission, use-case, port and route changes to PR #49 in focused commits.

### Task 3: Workflow wiring, runbook, full regression and review

**Files:**
- Modify: `backend/tests/outbox-contract.test.mjs`
- Modify: `docs/runbooks/auth-refresh-token-reuse.md`
- Modify CI workflow only if current workflow omits the migration/test scripts.

- [x] Add contract assertions that replay is narrow, transactional, and does not dispatch the provider synchronously; preserve the existing receiver key and exclude financial event types.
- [x] Document the supported replay operation, preconditions, required evidence, idempotency behavior, safe verification and incident response in the runbook and OpenAPI contract; do not document manual SQL as an operator workaround.
- [x] Inspect workflow coverage and include the new PostgreSQL tests in the isolated PostgreSQL runner, route tests in Backend Fast, and migration 053 in `check:migrations`.
- [ ] Finish the latest PostgreSQL/Superwave runs, then run remaining relevant Admin MFA, financial invariants and full backend/offline regressions. Do not repeat already-green suites without a code change.
- [ ] Complete the exact diff review and record terminal CI evidence. Strix review is blocked by missing GitHub SCM installation; keep independent review WAITING. Do not merge.
- [ ] Commit: `test(security): cover alert replay operations and runbook` (or a docs-specific commit if the changes separate cleanly).

## Execution and acceptance

- TDD is mandatory for each behavior change: tests first, observed RED, minimal implementation, observed GREEN, then relevant regressions.
- A test skipped because its required PostgreSQL environment is missing is NOT PASS; record it as SKIPPED/BLOCKED and use the CI PostgreSQL job for authoritative evidence.
- After every commit, reconcile branch HEAD and PR state. Do not start work on a stale SHA.
- Completion requires all new tests to pass, required regressions to pass, migration contract/checks to pass, diff review to be clean, and evidence to be synchronized into Notion. Receiver-side durable idempotency, real non-production delivery, Runtime/TalkBack, independent Strix review and overall release certification remain separate gates.
