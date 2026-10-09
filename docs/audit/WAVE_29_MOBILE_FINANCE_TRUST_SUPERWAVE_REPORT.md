# Wave 29 — Mobile finance flow, scroll-tail reachability, and compact-screen resilience

## Implementation scope

Wave 29 groups the next wallet-focused quality jump with cross-surface compact-device stress checks. It targets the actual user path from opening Wallet to reading the final ledger entry and requesting the next transaction page, while preserving the fixed primary navigation and the distinction between ledger activity and withdrawal requests.

- Wallet ledger cards use a slightly tighter compact treatment: reduced horizontal/vertical insets and a smaller decorative direction glyph, while preserving the existing semantics label, full-row tap action, and navigation-safe bottom scroll padding.
- Ledger titles clamp to two lines with an ellipsis instead of expanding unexpectedly when descriptions are long.
- The “Load more transactions” action now appears directly after the ledger list and before the separate Withdrawals section. It previously appeared after withdrawals, coupling ledger pagination to an unrelated payout section.
- The pagination CTA has a stable widget key and explicit loading text. While a page request is pending, the action is disabled and shows a progress indicator; successful completion appends the repository-supplied entries and removes the CTA if there is no next cursor.
- The compact Wallet fixture now has 12 ledger entries plus a deferred second page. The regression scrolls to the final first-page entry, checks dock clearance, opens its details, then separately tests the loading state and the appended older entry.
- The Work Center regression stress-tests 12 jobs instead of 8.
- Primary navigation visibility is asserted at 320×640dp, not only at the taller 320×800dp viewport.
- Explore gains a 360×640dp final-card scroll-tail and hit-test regression.

## Product and financial invariants

No backend endpoint, API payload, route, authentication decision, wallet/ledger arithmetic, payment transition, job lifecycle, transaction identity, cursor semantics, or provider integration was intentionally changed. Toman rendering remains sourced from existing models and formatters; no synthetic ledger balance or mock metric is introduced. Pagination continues to consume the existing `_nextCursor` and `_loadMore` behavior.

## Validation policy

- The source guard checks the actual source ordering so the transaction-pagination CTA stays above the Withdrawals heading.
- Consolidated Flutter regression, backend fast/security/static checks, lockfile verification, contrast guard, Flutter Analyze, and exact-HEAD Android capture remain the acceptance gates.
- Static CI must run without runtime/preverified PR markers so the consolidated Flutter suite is truly executed. Only after Static PASS may the approved runtime markers be restored for the exact same feature SHA.
- Source, widget-regression and source-guard changes were grouped in commit `9e839e79260b08da9679be77d79fcf56ec1a2624`. A report-only follow-up commit is being used to emit the standard PR synchronization event; acceptance will bind to that resulting final SHA, not the grouped parent SHA.
- The Android artifact's exact SHA, run, screenshot count, and archive hash will only be reported after those records are fetched and checked.
- TalkBack/T10 is not accepted without proof that a screen-reader service was enabled. The fa-RTL runtime lane does not certify en-light/LTR parity.

## Branch policy

Repository: `amirdavodpour-stack/3`  
Feature branch: `feat/ui-v2-wave-1-execution-2026-10-07`  
Base branch: `feat/google-sign-in-2026-09-20`  
PR: [#30](https://github.com/amirdavodpour-stack/3/pull/30), intended to remain **OPEN / DRAFT / UNMERGED**.

`main`/production are forbidden write targets. This report does not pre-claim workflow PASS; acceptance is tied to the final exact HEAD and matching CI records.
