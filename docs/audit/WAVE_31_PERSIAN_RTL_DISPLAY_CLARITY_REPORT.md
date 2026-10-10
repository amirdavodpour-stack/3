# Wave 31 — Persian RTL Display Consistency & Finance Readability

## Source baseline
- Feature branch: `feat/ui-v2-wave-1-execution-2026-10-07`
- Parent source HEAD: `713c02fe55dc2b747293ca4570a2f40946c30917`
- This wave is Persian-first; it does not introduce an English redesign phase.
- No API, authentication, routing, wallet arithmetic, ledger state, payment transitions, or job lifecycle semantics are changed.

## Implementation scope
- Shared display formatter adds:
  - Persian percent sign and decimal separator localization.
  - Signed Toman amount output with RTL-safe LTR isolation.
  - A single-value display for equal minimum/maximum budgets without altering underlying values.
- Wallet uses the active locale for Toman formatting, presents signed credits/debits in a directionally isolated run, and raises compact sub-balance labels/values to 12sp.
- Locale-aware digits are applied to Home Pulse metrics, Profile counts, Work Center metrics, notification unread count, offer and saved-search counts, satisfaction ratings, candidate-match scores, job-detail percentage scores, and financial breakdown percentages.
- Payment summary adopts the canonical formatter for Persian integer Toman values while preserving the existing English “Toman” presentation.
- Exact-HEAD Static CI includes page-level regression suites for the touched financial, wallet, detail, profile, notification, and offer surfaces in one consolidated Flutter invocation.

## Scope decisions
- Do not apply a blanket global text-size floor. Existing shared component and compact-density contracts remain intact.
- Do not globally redesign accent colors or change back-button placement based on low-confidence screenshot-only assumptions.
- The alleged Job Detail fixed-CTA overlap is not treated as a confirmed defect: the original 360×640dp screenshot visibly separates the CTA and description heading.
- The existing source order already places opportunity content before secondary Home metrics; it is not reordered based on the older screenshot.
- The artifact key `transactions` corresponds to the Work & Finance Center surface. Filename/validator cleanup is a separate evidence-contract task and is not mixed into these product display fixes.

## Verification contract
- Formatter tests cover equal ranges, signed positive/negative values, Persian percent/decimal localization, and unchanged English output.
- Widget tests cover wallet amount text/semantics, Persian payment-summary numbers, candidate percentages, Work Center count digits, and notification unread count.
- The one consolidated Static CI run must pass on the exact new HEAD before a serialized `fa-RTL` Android runtime capture is requested.
- Runtime acceptance requires exact metadata SHA, 19 primary + 6 responsive screenshots, unique hashes, and individual review of all 25 images.
- PR #30 remains OPEN / DRAFT / UNMERGED. `main` and production are forbidden.
