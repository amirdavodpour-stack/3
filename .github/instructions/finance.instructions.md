---
applyTo: "lib/core/transactions/**/*.dart,lib/features/wallet/**/*.dart,lib/features/transactions/**/*.dart,test/features/wallet/**/*.dart,test/features/transactions/**/*.dart"
---

# HOPE finance-specific guidance

- The current product ledger is internal Toman: 1 Toman = 1 internal unit.
- Currency metadata returned by a backend must not change the user-facing internal unit.
- Never render raw currency codes such as IRR or technical lifecycle enums directly to users when a localized mapper is available.
- Keep backend/domain enums unchanged; localize only at the presentation boundary unless a domain contract explicitly requires another representation.
- Preserve the job/payment lifecycle and authorization semantics: Fund -> Pay -> Lock -> Complete -> Approve/Refund -> Release -> Payout.
- Preserve idempotency and audit-sensitive behavior.
- Validate finance changes with focused widget/controller tests plus the repository's full quality gate before further UI changes.
