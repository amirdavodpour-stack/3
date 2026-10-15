# HOPE Wallet / Ledger Invariants

Status: source-derived definition; automated property tests and Flutter render assertions are still required.

## Source facts

- `backend/src/repository/wallet.js` returns `totalBalance = available_balance + locked_balance`.
- `available_balance` is spendable TOMAN.
- `locked_balance` includes active held amounts. Funding moves value from available to locked.
- `escrowBalance` is the active-hold sum for `hold_type='JOB_PAYMENT'`.
- `pendingWithdrawalBalance` is the active-hold sum for `hold_type='PAYOUT_RESERVATION'`.
- `otherLockedBalance` is the remaining active-hold sum.
- These three hold categories are breakdowns of `locked_balance`, not extra components to add to total.
- TOMAN values are represented as strings at the backend boundary to preserve integer precision; Flutter model converts numeric values to integers and should not introduce floats.
- User top-up/deposit is capability-gated. Current capabilities report it false unless the internal sandbox configuration is explicitly enabled.

## Formal invariants

Let (A) = available, (L) = locked, (E) = active job-payment escrow, (P) = active payout reservations, (O) = other active holds, (T) = total.

1. `T = A + L`.
2. `A >= 0`, `L >= 0`, `E >= 0`, `P >= 0`, `O >= 0` for normal wallet state.
3. `E + P + O <= L` as a conservative cross-check; exact equality is expected only if every locked amount is represented by one active hold row and no transitional/reconciliation category exists. Do not assert equality without checking the full hold lifecycle.
4. `P` is already unavailable for spending and already included in `L`; never compute `T = A + L + P`.
5. `E) is not the worker's spendable balance. Funds are released to the worker only after the server-authorized lifecycle transition.
6. All TOMAN arithmetic is integer/BigInt at backend financial boundaries. Flutter must render server values without recalculating fees or net amounts.
7. A wallet UI may omit a breakdown that is not present in the response; it must never replace missing values with fabricated non-zero values.
8. The customer's total/flow and worker's total/flow are role-specific; never combine payer charge and worker payout in a single perspective without an explicit reconciled explanation.

## Required tests

- Backend property/invariant tests over funding, payout reservation, payout terminal state, release, refund and transfer.
- Flutter widget/model tests asserting displayed totals reconcile and that pending/escrow amounts are not added twice.
- Idempotency and authorization tests remain mandatory for every financial mutation.
- No migration rewrites. Current latest historical migration observed is `033_human_chat.js`; future schema work starts at `034+`.
