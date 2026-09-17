# SESSION 19 CHANGELOG

- Restored the real Transaction widget test file after test/source overwrite was detected.
- Removed duplicate Start/Deliver/Accept/Release actions from the evidence panel.
- Added localized Transaction state guidance, state color/icon helpers, and pull-to-refresh UX.
- Removed raw payment status from the primary user-facing status presentation.
- Changed payment currency fallback from USD to TOMAN.
- Added exact/grouped TOMAN formatting to PremiumPaymentSummary.
- Expanded frontend-financial-wiring regression coverage with a no-duplicate lifecycle-control contract.
- Fresh backend canonical suite: 265/265 PASS.
- Fresh frontend-financial-wiring contract: 6/6 PASS.
