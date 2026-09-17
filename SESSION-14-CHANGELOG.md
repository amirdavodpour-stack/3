# SESSION 14 CHANGELOG

- Hardened `lib/features/wallet/wallet_page.dart` for Wallet product UX and mobile retry behavior.
- Added persistent operation fingerprint/idempotency storage via `SharedPreferences`.
- Added terminal error cleanup for stale client idempotency keys.
- Added wallet identity copy/select surface and payout history.
- Added transaction detail bottom sheet.
- Added inactive-wallet action gating and state messaging.
- Added responsive detail rows and TOMAN amount bounds.
- Extended `backend/tests/wallet-mobile-integration-contract.test.mjs`.
- Fresh backend `test:fast`: 258/258 PASS.
- No production/main files touched.
- No ZIP produced this session.
