# V2hope Financial Invariant Matrix — Executable Contract

Date: 2026-09-15

This matrix is an executable contract over the current source. It is not PostgreSQL certification by itself.

| Operation | State / lifecycle | Wallet / Hold | Immutable wallet entry | Journal / Ledger | Financial operation | Outbox | Audit | Idempotency |
|---|---|---|---|---|---|---|---|---|
| TOP_UP | processing → succeeded / failed | wallet balance | required | required for financial posting | required | provider-dependent boundary | required for external/provider reconciliation | required |
| TRANSFER | processing → succeeded | source + destination wallets | debit + credit | balanced journal | required | not required for pure internal transfer | required | required |
| HOLD | payment hold lifecycle | available → locked + active hold | debit | HOLD journal: customer liability → escrow + fee | required | payment lifecycle dependent | required | required |
| RELEASE | held → released / recovery | release active hold + wallet transfer | debit/credit | RELEASE journal | required | durable release event | required | required |
| REFUND | refund pending → refunded / recovery | hold release / wallet restoration | compensating entry | REFUND journal | required | durable refund event | required | required |
| PAYOUT | requested/reserved/processing/unknown → succeeded/failed | available → locked → terminal | payout debit + terminal settlement entries | PAYOUT journal | required | PAYOUT_EXECUTE | required | required |

## Database hardening status

- Wallet non-negative balances: DB constraint present.
- Wallet identity immutability: DB trigger present.
- Wallet entry immutability: DB trigger present.
- Posted journal immutability: DB trigger present.
- Financial operation identity immutability: DB trigger present.
- Payment state transitions: DB trigger present.
- Job state transitions: DB trigger present.
- Payout state transitions: DB trigger added in migration 012.
- Payout identity immutability: DB trigger added in migration 012.
- Payout terminal `completed_at` consistency: DB check added in migration 012.
- Reconciliation active-case dedupe: partial unique index added in migration 011.

## Certification boundary

The contract tests validate source wiring and invariants represented in code. Real PostgreSQL concurrency, isolation, deadlock, transaction rollback, and trigger behavior remain uncertified until executed against an isolated PostgreSQL database.
