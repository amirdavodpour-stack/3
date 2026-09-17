# Session 15 Changelog — 2026-09-15

## Financial precision
- Added `tomanField()` for integer-only TOMAN job amounts with the shared 9e15 maximum.
- Switched Job budget/salary input handling to `tomanField()`.
- Changed repository Job mappers to keep PostgreSQL monetary values string-backed.
- Changed Job serialization to keep PostgreSQL monetary values string-backed.
- Hardened `paymentAmountForJob()` to validate exact TOMAN strings and return a canonical string.
- Removed Flutter `double.parse()` from TOMAN Job creation payload generation.
- Hardened Flutter Job validation for integer TOMAN values and the shared max boundary.
- Removed TOMAN `Number()` coercion from ledger row serialization.

## Wallet/API contracts
- Added explicit Wallet transfer error mappings for invalid amount and idempotency conflict/in-progress.
- Added explicit withdrawal error mappings for invalid amount, idempotency conflict, wallet lookup/unavailability.
- Added explicit top-up error mappings for invalid amount and idempotency conflict/in-progress.

## Tests
- Updated payment amount-selection assertions for string-backed TOMAN values.
- Added exact Job mapper regression coverage.
- Added Flutter TOMAN payload static contract coverage.
- Added Wallet mutation error-contract coverage.
- Fresh `test:fast`: 259/259 PASS.
- Fresh `test:contract`: 90/90 PASS.
- Fresh `test:product`: 9/9 PASS.
- Fresh `test:backup`: 11/11 PASS.
- Fresh payment E2E: 6/6 PASS.

## Release discipline
- No production/main changes.
- No fake evidence or score manipulation.
- No ZIP created at this checkpoint; checkpoint packaging remains aligned with the requested five-session cadence.
