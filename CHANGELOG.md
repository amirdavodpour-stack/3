## 2026-09-13 — V19 final regression/test-harness hardening

- Made `test:offline` process-isolated so per-test `process.env` and runtime state cannot bleed across test files.
- Fixed migration contract coverage for migration 003 (`RELEASE_FAILED`).
- Removed the non-boundary `providerRefMatches` helper export so repository boundary fail-closed coverage only targets SQL-backed methods.
- Fixed mobile marketplace creation to resolve the use case through `ApplicationRegistry` instead of constructing a Repository-backed use case in the widget.
- Updated stale mobile taxonomy/notification contracts to assert the current ApplicationRegistry boundary.
- Restored executable bits on packaged shell scripts and added a contract test for the isolation runner.

## 2026-09-13 — V18 Authorization / BOLA hardening

- Scoped employer-side application lifecycle mutations to both the authenticated owner and the route `jobId`.
- Prevented a same-owner cross-job application identifier from mutating an application belonging to another job.
- Applied the same protection to interview, offer, and hire transitions in both PostgreSQL and explicit test-mode runtime paths.
- Added `backend/tests/authorization-bola-v18.test.mjs` with an executable cross-job regression and repository contract coverage.
- Revalidated the backend contract suite at 74/74 passing and the focused security/storage/notification/payment suites used for this hardening.
- Updated repository-port contract coverage for `getAdminFinancialSummary()` so the payment capability slice matches the payment application use case.
- No production thresholds, tests, or runtime gates were weakened or removed.

## 2026-09-13 — V8 consistency hardening

- Fixed PostgreSQL refund idempotency retry semantics: a terminal `FAILED` refund can be safely reopened with the same idempotency key instead of being returned as a dead operation.
- Preserved the original refund record/operation identity and re-queues the existing payment refund outbox event.
- Added focused contract coverage for terminal-failure recovery and payment `HELD` restoration.
- Added the refund contract to the backend contract suite.
- No production thresholds, runtime gates, or existing tests were weakened or removed.

## 2026-09-13 — Architecture hardening

- Decoupled application/policy/service modules from the HTTP transport by centralizing the shared error contract in `backend/src/api/http_error.js`.
- Preserved the existing `HttpError` import surface from `backend/src/http.js` for compatibility.
- Added a transport-boundary architecture contract and maintenance evidence.

# Changelog

All notable project changes are documented here. This changelog focuses on
verified engineering changes and test-infrastructure hardening; historical
session evidence remains under `test-results/sessions/`.

## [Unreleased] — Pre-certification hardening

### Added
- Deterministic disposable PostgreSQL test runner at
  `backend/tools/run-postgres-isolated.mjs`, including forced teardown.
- Runtime qualification inventory at `tools/runtime-qualification-inventory.mjs`.
- Test-state integrity validation at `tools/validate-test-state.mjs`.
- Flutter behavior tests covering admin, create-job, home navigation,
  transaction and job-detail flows.
- Certification gap map and current test-state evidence under `test-results/`.

### Changed
- PostgreSQL production persistence boundaries were tightened so the
  PostgreSQL path does not fall back through the legacy collection adapter.
- Backend coverage gate parsing was hardened for modern Node TAP output.
- Coverage gate execution is explicitly pinned to `NODE_ENV=test`.
- Agent handoff contract inputs were restored and validated.
- Test/package handling was hardened to preserve executable permissions and
  exclude machine-local Android configuration.
- Test evidence and state files were synchronized around canonical sessions.

### Verification
- Latest verified Flutter suite: 414/414 passing; analyze reports 0 issues;
  line coverage gate 78.26%.
- Latest verified backend baseline: 217/217 fast tests; backend coverage
  81.21% line / 70.65% branch / 74.02% functions.
- PostgreSQL isolated runner: 3 clean repetitions, 4/4 each, with no
  leftover test databases.
- Final production build and deployment have not been performed.

## Historical sessions

Detailed historical results are retained in:
`test-results/sessions/`

The current canonical project status is maintained in:
- `README-TEST-STATUS.md`
- `TEST-COMPLETION-STATE.json`
- `test-results/TEST-SUMMARY.json`
## Architecture hardening V9 — 2026-09-13

- Hardened employer-side application lifecycle concurrency by locking the Job aggregate before the Application row.
- Prevented concurrent acceptance of different candidates for the same Job from racing into successive `provider_id` overwrites.
- Added `backend/tests/application-concurrency-contract.test.mjs` to preserve the canonical `job -> application` lock ordering.
- No thresholds, existing tests, or runtime gates were weakened or removed.

## V10 — Concurrency / Uniqueness Hardening

- Closed check-then-insert races for pending offers and candidate applications.
- PostgreSQL partial unique constraints remain the authoritative concurrency guard.
- Repository converts duplicate-constraint violations into stable domain errors (`OFFER_EXISTS`, `APPLICATION_EXISTS`).
- HTTP routes map those domain errors to deterministic `409 Conflict` responses.
- Added `backend/tests/race-constraint-contract.test.mjs`.
- Focused integrity/security suite: 36/36 passed.
- No production threshold, test, or runtime gate was weakened.

## Architecture Hardening — Release Recovery

- Added explicit `RELEASE_FAILED` payment state for terminal payment-release failures.
- Added migration `003_payment_release_recovery` so existing PostgreSQL deployments receive the expanded payment status constraint safely.
- Release retry reuses the existing outbox dedupe key and reopens `RELEASE_FAILED` to `RELEASE_PENDING` without creating duplicate ledger/settlement effects.

## Unreleased — Security/Consistency Hardening
- Bound signed payment webhook event IDs to payload event IDs.
- Hardened payment webhook aggregate/provider-reference validation.
- Added RELEASE_FAILED reconciliation coverage and fail-closed migration rollback semantics.

## V16 — Notification Device Ownership Hardening
- Prevented notification-device token rebinding across user accounts in both PostgreSQL and explicit legacy test runtime.
- PostgreSQL registration now locks the existing token row before deciding whether it may be updated, eliminating a cross-user takeover edge and preserving token uniqueness.
- Added focused ownership contract coverage.

## 2026-09-13 — V17 security/financial hardening
- Routed admin financial summary through the payment application boundary instead of direct repository access.
- Prevented deletion of jobs that already have financial records in both PostgreSQL and explicit test/local runtime.
- Included `RELEASE_FAILED` in financial pending summaries.
- Added/updated admin security architecture contracts for the deletion and financial-summary boundaries.
- Validation: focused security/admin suite 19/19 PASS; contract suite 74/74 PASS; modified-file syntax checks PASS.

- 2026-09-13: hardened service/composition persistence boundaries with explicit app/session legacy adapters; fast, contract, and architecture suites remain green.


## Post-Phase-50 Backend ↔ UI Hardening — 2026-09-15

- **FIXED (P1):** Aligned the application lifecycle on canonical `SHORTLISTED` state. Legacy `SELECTED` persistence is normalized by migration 022; duplicate-application protection now covers `PENDING`/`SHORTLISTED`.
- **VERIFIED:** Job completion still uses an atomic job/payment transition and the Flutter transaction workspace refreshes the full aggregate.
- **VERIFIED:** Wallet top-up remains hidden by default and backend-disabled in production.
- **RISK/DEFERRED:** `backend/src/workflow.js` remains a legacy, unreferenced parallel state machine with differing transitions; deletion/consolidation requires a dedicated compatibility review.
- **FIXED:** Rewired Home's existing `buildResponsiveHomeFeed` contract into the flagship Home tab so the responsive V2 feed helper is actually used.


## 2026-09-15 — Post-Phase-50 contract hardening continuation
- Fixed PostgreSQL payment mapper dropping fee breakdown/currency fields consumed by the transaction UI.
- Deepened OpenAPI Job/Offer/Payment schemas to match actual backend response shapes and lifecycle enums.
- Restored executable permissions for release shell scripts and `android/gradlew` before final packaging.
- Re-ran backend fast suite: 267/267 passing.


## Final reconstruction and archive preparation — 2026-09-15T20:50:46Z

- Reconstructed the canonical application shortlist schema predicate (`PENDING`/`SHORTLISTED`) in the base schema.
- Restored the documented responsive Home helper import.
- Reconciled stale source-contract assertions with the reconstructed TOMAN, migration, Flutter static, and Wallet UX implementations without lowering security or coverage thresholds.
- Restored executable permissions for all committed shell scripts and `android/gradlew`.
- Generated and retained `backend/sbom.json` as the release supply-chain artifact.
- Removed generated/cache artifacts from the final source tree.
- Added `RECONSTRUCTED-CHANGES.md` and `FINAL-RECONSTRUCTION-AUDIT.md`.
- Git provenance remains unknown because `.git` is absent.

## 2026-09-15 — Reconstruction/finalization reconciliation

- `/mnt/data/hope_full` was absent; the available current-state evidence tree was copied to the working path before final verification.
- Restored 42 non-generated reference evidence/documentation files that had no reliable deletion evidence.
- Excluded one identified raw DR evidence log as temporary/generated evidence.
- Reconciled 43 reference/current modifications already present in the supplied current-state tree; no additional production business-logic rewrite was introduced during this reconciliation.
- Preserved executable mode on all 34 shell/launcher files.
- Verified 299/299 backend syntax, 267/267 fast tests, 90/90 contract tests, 9/9 product tests, 11/11 backup tests, 2/2 failure-injection tests, 1/1 performance smoke, 500-request load smoke, and `npm run check:all` exit 0.
- Full coverage measurement is 73.93% lines / 70.65% branches / 70.00% functions; the coverage command still reports one existing Flutter architecture assertion failure and four skipped tests.
- No historical Session 7 filesystem revision was available; provenance remains UNKNOWN.



## 2026-09-16 — Final reconstruction hardening

- Extracted Jobs result rendering into `_JobsResultsSliver`; `jobs_page.dart` is now 337 lines.
- Extracted Create Opportunity form into `_CreateJobForm`; `create_job_page.dart` is now 207 lines.
- Extracted Transaction rendering helpers into `transaction_widgets.part.dart`; `transaction_page.dart` is now 224 lines.
- Updated source-location contracts to follow the extracted widgets without deleting or weakening functional assertions.
- Restored executable permissions for all 34 shell/launcher files.
- Updated the UX gate to validate the actual Jobs widget implementation location.
- Verified 267/267 fast tests, 90/90 contract tests, 9/9 product tests, 11/11 backup tests, 2/2 failure-injection tests, 6/6 payment E2E tests, and `check:all`.
- Verified full coverage command: 638 tests, 634 PASS, 0 FAIL, 4 SKIP; 73.93% lines / 70.61% branches / 70.00% functions.
- External runtime certification and exact Session 7 historical reconstruction remain blocked/unverified and are not represented as PASS.
