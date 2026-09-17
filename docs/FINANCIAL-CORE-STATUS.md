# V2hope Financial Core — Staging Implementation Status

## Scope

This change set is isolated to the internal-ledger sandbox/staging tree. It does not modify `main/production`, Railway production variables, or the production database.

## Implemented in this slice

1. Added migration `006_financial_core`.
2. Migrated sandbox wallet currency from `HOPE` to `TOMAN`.
3. Converted wallet available/locked balances to integer `BIGINT` units.
4. Enforced one wallet per user with a unique `user_id` index.
5. Added `financial_operations` as the correlation root for material money operations.
6. Added generic request idempotency with request-hash conflict detection.
7. Added `wallet_holds` for explicit escrow/hold state.
8. Added immutable canonical `wallet_entries` for user-facing wallet history.
9. Added `journals` as the accounting journal root.
10. Added `payouts`, `provider_events`, and `reconciliation_cases` as first-class financial primitives.
11. Registration now creates the user's TOMAN wallet in the same PostgreSQL transaction as user/provider creation.
12. Internal wallet operations now use deterministic wallet locking and canonical wallet entries/journals.
13. Internal top-up, transfer, hold, release, and refund paths now correlate through `financial_operations`.
14. Production configuration keeps the external `webhook` rail separate; the internal rail requires `PAYMENT_CURRENCY=TOMAN`.
15. Migration syntax/check coverage was updated for migration 006.

## Important compatibility boundary

The legacy `wallet_transactions` table is intentionally retained as a migration/backfill source in this slice. New canonical writes use `wallet_entries`. Legacy payment/accounting tables are not destructively replaced here.

## Current continuation status

The items above have since been implemented in the recovered V2/Wallet workstream. The current remaining work is certification rather than invention of the missing Financial Core primitives.

### Current hardened boundaries
- TOMAN is integer-only with a shared 9e15 ceiling.
- Wallet balances, wallet entries, payout amounts and financial operation paths use exact BigInt/string-backed handling.
- Job budget/salary inputs now remain exact TOMAN strings from Flutter through the backend mapper.
- Wallet transfer/top-up/payout idempotency has deterministic conflict/in-progress contracts.
- Canonical wallet history is cursor-paginated and sourced from immutable `wallet_entries`.
- Payout reservation/UNKNOWN/reconciliation controls are present behind durable outbox transitions.

### Remaining certification gates
- Flutter 3.47.2 analyze/test on the pinned environment.
- Android build/install/device Wallet E2E against HTTPS staging.
- Real multi-connection PostgreSQL concurrency certification.
- Real S3/provider runtime certification where credentials are available.
- CI-traceable evidence promotion for release scorecard gates.
