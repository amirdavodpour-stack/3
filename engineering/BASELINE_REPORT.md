# HOPE V8 Baseline Report — Execution Block 02

Date: 2026-09-16

This block is based on actual repository inspection and executed Node test commands.

## Verified baseline
- Backend package: hope-api 4.0.20
- Node engine: >=24 <25
- PostgreSQL-backed persistence
- Canonical wallet/ledger implementation exists
- 22 migrations existed before this block
- 34 shell/Gradle launcher files required executable bits in the extracted workspace

## Findings acted on
1. Migration 006 updates wallet_accounts currency from HOPE to TOMAN before selecting legacy wallet_transactions WHERE currency='HOPE'. Therefore the intended legacy canonical backfill can be skipped.
2. The extracted artifact had lost executable bits, causing the existing executable-permissions tests to fail.

## Actions
- Added migration 023 as a forward-only repair for legacy wallet_transactions.
- The repair creates canonical financial_operations, wallet_entries and balanced LEGACY_BACKFILL journals.
- Added a contract test for migration 023.
- Updated migration syntax checking to include migration 023.
- Restored executable bits on all shell scripts and android/gradlew.

## Verification
- Backend syntax check: PASS
- Migration syntax check: PASS
- Financial targeted suite: 43/43 PASS
- Fast suite: 267/267 PASS
- Contract suite: 90/90 PASS
- Product suite: 9/9 PASS
- check:all: PASS
- 90plus score gate: NOT PASS; project evidence score remains below 90 in several domains.
- Coverage gate: NOT PASS; measured 60.20% line / 70.43% branch / 66.48% function against required 70/60/65.
- npm audit could not be used as a verified security result because external registry access is unavailable in this environment.

## Important limitation
No live PostgreSQL/Flutter/Android production runtime certification was claimed in this block.
