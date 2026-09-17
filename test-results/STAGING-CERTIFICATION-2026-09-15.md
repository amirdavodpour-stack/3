# HOPE V8 — Financial Core / Staging Certification Report

**Date:** 2026-09-15  
**Scope:** extracted V8 handoff working tree; production/main excluded  
**Staging DB:** Neon `HOPE-V8-staging` / branch `financial-core-cert` / PostgreSQL 17.11

## Executive status

| Gate | Result | Evidence |
|---|---|---|
| JavaScript syntax / source integrity | PASS | `npm run check` |
| Migration syntax / sequence | PASS | `npm run check:migrations` through migration 013 |
| Fast regression suite | PASS | 258/258, 0 skipped |
| Contract suite | PASS | 89/89, 0 skipped |
| Idempotency race hardening contract | PASS | dedicated 3-test contract + fast/contract inclusion |
| Financial DB-guard contract | PASS | dedicated migration-013 contract + fast/contract inclusion |
| Neon payout transition guard | PASS | real PostgreSQL rejection probe |
| Neon payout identity immutability | PASS | real PostgreSQL rejection probe |
| Neon payout lifecycle | PASS | REQUESTED → RESERVED → PROCESSING → UNKNOWN → SUCCEEDED |
| Neon reconciliation dedupe | PASS | unique active-case index verified |
| Neon lock inspection | CLEAN | 0 active locks at inspection time |
| Neon schema baseline completeness | BLOCKED | staging branch is only partially provisioned; core journal/ledger/outbox tables are absent |
| PostgreSQL multi-transaction adversarial certification | NOT CERTIFIED | local runtime lacks executable `pg` client/runtime harness |
| Flutter analyzer/build | NOT CERTIFIED | Flutter SDK unavailable in current runtime |
| OneGate/Neo N3 integration | NOT APPLICABLE | HOPE source contains no OneGate/Neo DApp boundary |

## High-risk finding fixed

`beginIdempotency()` previously used `INSERT ... ON CONFLICT ... DO UPDATE`, which could allow two transactions racing on a previously unseen idempotency key to turn a completed record back into `PROCESSING`. That pattern was replaced with:

1. insert-only reservation using `ON CONFLICT DO NOTHING RETURNING *`;
2. explicit `SELECT ... FOR UPDATE` after conflict;
3. conflict/hash validation before mutation;
4. `SUCCEEDED` replay without re-execution;
5. explicit `IDEMPOTENCY_IN_PROGRESS` for active concurrent work;
6. controlled reopening only for `FAILED` records.

This removes the identified overwrite path without relying on application timing.

## Database guard hardening added

Migration `013_financial_amount_and_journal_guards` adds database-level enforcement for the internal TOMAN safety ceiling and journal balance invariant:

- wallet available/locked balances are capped at `9_000_000_000_000_000`;
- wallet holds, wallet entries, payout amounts, and journal debit/credit amounts are capped at the same ceiling;
- a journal cannot become `POSTED` unless it is non-empty and `SUM(debit) = SUM(credit)`;
- the journal check is a deferred constraint trigger so the application can insert the journal and its entries within one transaction before commit validation.

## Database guard evidence

Real Neon PostgreSQL inspection confirmed both previously installed payout triggers:

- `payout_state_transition_guard`
- `payout_identity_immutable_trigger`

A transaction-scoped probe demonstrated that an invalid `REQUESTED → PROCESSING` mutation is rejected with `invalid PAYOUT state transition`.

A second probe demonstrated that changing payout identity (`amount`) is rejected with `PAYOUT identity is immutable`.

The probe uses nested exception blocks so the temporary test rows are rolled back and no certification fixture remains as persistent data.

## Financial model validated in source

The current source maintains:

- internal currency `TOMAN` with integer amounts;
- immutable wallet ledger entries;
- balanced accounting journal entries;
- financial operation records;
- wallet holds for escrow/payout reservation;
- idempotency records;
- outbox-based provider execution;
- payout states including `UNKNOWN`;
- reconciliation cases for delayed/unknown provider outcomes.

The payout reconciliation worker does not blindly replay `createPayout`; it queries provider status and resolves only terminal provider outcomes.

## Mobile surface

The Wallet feature contains a dedicated user-facing screen with:

- available and locked balances;
- TOMAN formatting;
- wallet history with cursor pagination;
- internal wallet-to-wallet transfer;
- staging-only top-up;
- withdrawal request;
- guest/authenticated handling;
- RTL/localized Persian + English copy.

The repository contract is aligned with backend endpoints:

- `GET /wallet/me`
- `GET /wallet/transactions`
- `GET /wallet/payouts`
- `POST /wallet/transfer`
- `POST /wallet/top-up`
- `POST /wallet/withdraw`

## Neon staging baseline finding

The current Neon branch is **not a complete mirror of migrations 006–013**. Read-only schema inspection found these financial tables present:

- `financial_operations`
- `payouts`
- `reconciliation_cases`
- `wallet_accounts`
- `wallet_holds`

The following source-defined core tables were absent on the inspected branch:

- `wallet_entries`
- `journals`
- `ledger_entries`
- `provider_events`
- `outbox_events`
- `idempotency_keys`
- `audit_logs`
- `schema_migrations`

Because of this drift, migration 013 was **not** applied to the staging parent merely to manufacture a green probe. The correct next action is to provision/apply the full source migration chain on an isolated staging branch, run the complete end-to-end certification there, and only then promote the validated schema change.

A real `EXPLAIN ANALYZE` of user payout history previously used the payout user index and completed in sub-millisecond execution in the observed tiny dataset; this remains a smoke-level performance observation, not a production load claim.

## Explicit non-claims

This report does not claim that application-level concurrent transfers, simultaneous opposite-direction transfers, concurrent payout reservations, webhook races, or crash-between-commit-and-provider-outcome scenarios have passed on a real multi-connection PostgreSQL harness. The current local runtime cannot execute the repository's PostgreSQL test harness because the required `pg` package/runtime is incomplete and no local PostgreSQL executable is available.

The passing results above therefore distinguish source/contract proof from real database probe evidence, and the Neon staging branch is explicitly marked incomplete rather than certified as a full migration environment.
