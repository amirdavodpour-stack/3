---
name: finance-review
description: Review HOPE wallet, transaction, payment, payout, and finance surfaces for financial invariants, authorization, idempotency, auditability, and localized Toman presentation.
---
# HOPE finance review
Financial behavior is safety-critical.
## Required checks
1. Identify the exact state transition being changed.
2. Verify authorization and ownership boundaries.
3. Verify idempotency and race-condition handling.
4. Verify ledger balance invariants and transaction atomicity.
5. Verify immutable/audit fields and reconciliation implications.
6. Verify failure, retry, refund, hold, and recovery behavior.
7. Verify localized internal Toman presentation: 1 Toman = 1 internal unit.
8. Verify tests cover unknown/fallback states and stable semantic targets.
9. Never infer financial correctness from UI appearance alone.
## Release rule
Uncertainty involving money movement, ledger integrity, or authorization is blocking until exact evidence exists.
