# HOPE V8 — Session 17 Changelog

- Added transaction status refresh affordance and payment ID presentation.
- Added explicit refund confirmation dialog.
- Added direct Activity → Transaction action CTA.
- Added Wallet dashboard metrics for available/locked/pending payout values.
- Added Wallet transaction filters (all/credit/debit/hold).
- Added wallet amount input digit-only + length bounds.
- Localized shared `PremiumPaymentSummary` status and metric labels for FA/EN.
- Localized Activity job-state labels instead of exposing raw backend enum values.
- Added `frontend-financial-wiring-contract.test.mjs`.
- Added the new contract suite to `test:fast`.
- Re-ran canonical backend suite: 263/263 PASS.
