# SESSION-16 CHANGELOG

## UI/UX
- Reworked TransactionPage around an explicit lifecycle flow navigator.
- Added state/role-aware action surfaces for owner/provider roles.
- Added compact-width horizontal scrolling for lifecycle navigation.
- Improved financial amount presentation to use TOMAN wording consistently.

## Frontend/backend integration
- Added `TransactionController.executeJob()` for real start/deliver/accept backend commands.
- Added `HopePayment.copyWith()` for state-preserving UI updates after job mutations.
- Converted mobile payment amounts and fee fields to string-backed values.
- Converted Offer price from double/num to exact string-backed TOMAN across repository/use-case/controller/model.

## Backend financial boundary
- Offer route now consumes exact TOMAN validation.
- Offer persistence/view/serialization preserve PostgreSQL NUMERIC as string.
- Payment offer selection compares exact TOMAN values with BigInt.

## Validation
- `npm run test:fast` → 259/259 PASS.
- `npm run test:product` → 9/9 PASS.
- `toman-offer-contract` → 5/5 PASS.
- Flutter runtime remains BLOCKED/UNVERIFIED due toolchain/resource constraints.
