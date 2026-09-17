# HOPE V7 — Session 15 Engineering Checkpoint

Date: 2026-09-15
Scope: Financial precision continuity + Wallet/API contract hardening
Source of Truth: HOPE-V8-FINAL-COMPLETE-HANDOFF-2026-09-15-SESSION10.zip

## Executive result

This checkpoint closed a previously remaining precision gap between the mobile Job creation surface and the Financial Core. TOMAN amounts are now preserved as integer decimal strings through the Job input boundary, repository row mapping, payment amount selection, and ledger serialization.

No `main/production` source or deployment configuration was touched. No synthetic runtime evidence was created.

## Changes completed

### 1. Exact TOMAN Job input boundary
- Added `tomanField()` with the Financial Core maximum of 9,000,000,000,000,000 units.
- Job `budgetMin`, `budgetMax`, and `monthlySalary` now use the TOMAN-specific validator instead of the generic decimal `moneyField()`.
- Backend stores/propagates these values as exact strings rather than JavaScript floating-point numbers.

### 2. Exact PostgreSQL → domain mapping
- `jobFromRow()` now keeps Job monetary fields string-backed.
- `fromDbRow('jobs', ...)` also preserves the PostgreSQL numeric values as strings.
- `paymentAmountForJob()` now validates integer TOMAN input and returns the canonical exact string; payment fee calculation then performs BigInt arithmetic in the Financial Core.

### 3. Exact Flutter → HTTP payload
- `create_job_payload.dart` no longer uses `double.parse()` for TOMAN budget/salary fields.
- Client validation now requires integer TOMAN input and applies the same 9e15 ceiling as the backend Financial Core.

### 4. Wallet API error contract hardening
- Transfer, withdrawal, and top-up paths now explicitly map invalid amount and idempotency-conflict/in-progress conditions to deterministic HTTP errors.
- Wallet-unavailable and wallet-not-found conditions remain explicit instead of falling through to generic 500 behavior.

### 5. Ledger serialization correction
- TOMAN ledger debit/credit values no longer pass through `Number()` during legacy/domain row serialization.
- Non-TOMAN legacy monetary serialization remains numeric where required by the compatibility boundary.

## Fresh verification

- `backend npm run test:fast`: **259/259 PASS**
- `backend npm run test:contract`: **90/90 PASS**
- `backend npm run test:product`: **9/9 PASS**
- `backend npm run test:backup`: **11/11 PASS**
- targeted financial/client contract suite: **35/35 PASS**
- `backend npm run test:payment-e2e`: **6/6 PASS**
- `npm run check`: PASS
- `npm run check:migrations`: PASS
- `npm run check:toolchain-contract`: PASS

The score engine still reports `overallReadiness=92` because its release score is evidence-derived and several gates cannot be promoted from this sandbox without their required runtime/CI evidence. This is not treated as a code failure and was not bypassed.

## Environment blockers

The resource guard is still fail-closed:
`RAM=4096 MiB`, required floor `6144 MiB`, exit code `2`.

Flutter/Dart SDK, Android device tooling, and the target Node/JDK toolchain are not available in this environment, so Flutter analyze/test, APK build/install/runtime certification, and target-toolchain certification remain unverified.

Real external provider/S3 runtime credentials and multi-connection PostgreSQL concurrency certification are also unverified.

## Completion assessment

The important architectural target achieved in this checkpoint is continuity of TOMAN exactness across the primary money path:

`Flutter text → JSON string → backend TOMAN validation → PostgreSQL NUMERIC/BIGINT representation → exact string mapper → BigInt Financial Core → string API boundary`

This closes a substantive correctness gap rather than merely increasing a contract score.

## Next gate

The next highest-value gate is runtime qualification on the pinned environment: Flutter 3.47.2 + Android toolchain, followed by HTTPS staging Wallet E2E and real PostgreSQL concurrency. Until those execute with attributable evidence, release certification remains incomplete.
