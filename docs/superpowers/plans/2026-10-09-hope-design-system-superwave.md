# HOPE Design System 2.0 Superwave — implementation plan

## Objective
Raise actual visual and interaction quality against the user-supplied HOPE showcase. This is one grouped UI-only delivery, not a collection of cosmetic micro-waves.

## Source-of-truth boundaries
- Repo: `amirdavodpour-stack/3`
- Feature branch: `feat/ui-v2-wave-1-execution-2026-10-07`
- Parent HEAD: `1308b9a96a7334e42e2a215a302b7721923e2b1d`
- PR #30 remains Draft and unmerged; `main/production` is forbidden.
- Keep API contracts, backend state transitions, idempotency, payment lifecycle and ledger calculations unchanged.
- No amount may be manufactured in the UI. Wallet values are display projections of source model fields.

## Design decisions
1. Reuse the existing palette: primary indigo `#6366F1`, success `#10B981`, warning `#F59E0B`, danger `#EF4444`, dark surface `#0F111A`, text `#F8FAFC`.
2. Compress default compact panel insets but leave explicitly tuned feature padding intact.
3. Put HOPE Pulse before recommendations and remove horizontal overflow from its four-metric summary.
4. Give the compact opportunity score a circular ring without changing the numeric input or component percentages.
5. Display aggregate locked money from `lockedBalance`; do not substitute the residual `otherLockedBalance` component.
6. Use a vertical transaction timeline at all widths; preserve state mapping and action gates.
7. Add a data-grounded wide candidate comparison matrix while retaining stacked mobile cards.
8. Collapse the optional live preview on compact Create Opportunity screens.
9. Leave ratings and work agreement unset until explicitly selected; disable incomplete satisfaction submission.
10. Never ellipsize opportunity-card amount/range text; compact variants may wrap to three lines and must retain the full model-supplied value.
11. Explore must fall back to a single column above a 1.2 text scale so layout density never outranks accessibility readability; enable Semantics when testing accessible navigation labels.

## Regression plan
- Keep shared visual/localization, date formatter, compact Wallet, Saved Search and transaction behavior tests in one consolidated Flutter invocation.
- Assert aggregate locked-balance visibility if active-hold detail values are zero.
- Assert a score ring and compact Money Flow heading/steps while preventing duplicate lifecycle amounts.
- Assert compact-grid Toman ranges remain complete without paragraph max-line overflow.
- Assert Explore uses a single-column card summary at enlarged text scale with no layout exception.
- Assert the mobile transaction page renders a vertical timeline.
- Add wide candidate matrix and satisfaction-form tests for no biased defaults/incomplete submission.
- Extend source guards without removing previous-wave checks.
- Static PASS must be recorded on this exact commit before enabling the runtime-capture marker.
- Capture once on the same exact HEAD and individually inspect all 25 PNGs. Screenshots cannot certify TalkBack where accessibility is disabled.

## Evidence status at assembly
Pending: Flutter analysis, the one consolidated Flutter test command, exact-head runtime capture and screenshot audit. Earlier Wave22 PASS is baseline only.
