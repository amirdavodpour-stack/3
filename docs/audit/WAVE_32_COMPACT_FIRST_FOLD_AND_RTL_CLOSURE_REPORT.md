# Wave 32 — Compact First-Fold + RTL Display Closure

## Baseline and traceability
- Base HEAD: `1964677e6e89b71df9ca52c313555492225b9de8`
- Scope: Wallet compact first-fold reachability, Jobs compact control band, RTL formatting in Jobs filters, Opportunity DNA, candidate comparison and Match Intelligence confidence labels.
- Runtime baseline: [Run 38040481038](https://github.com/amirdavodpour-stack/3/actions/runs/38040481038), exact base HEAD, 19 primary + 6 responsive fa-RTL screenshots, 360×640dp responsive viewport. Artifact digest: `sha256:978c9aada28d7a6062a4a7d0fb7a15879ba6e2fc933695d781a5de09cd8c71b3`.
- Research references: [Flutter SafeArea & MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery), [Flutter ListView API](https://api.flutter.dev/flutter/widgets/ListView-class.html), [Flutter accessibility styling](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling), and [Unicode Bidirectional Algorithm](https://www.unicode.org/reports/tr9/).
- Product principle: responsive means fitting in the available space; adaptive means remaining usable in that space. Do not fix a first-fold defect solely by shrinking text or hiding authoritative money.

## Implementation decisions
1. On compact Wallet, move the explanatory money-flow signature after the ledger list, remove the redundant history subtitle on compact widths, and preserve the signature on wider widths. Balances, source amounts, filters, chronology and pagination are unchanged.
2. On compact Jobs, place search, result count and filter launcher in one row; keep the 48dp filter target and existing 48dp kind selector in a second row. Job/filter counts use the shared localizer. Active filter count remains represented by the launcher's count badge and tooltip.
3. Opportunity DNA match score and budget labels use the shared formatter, including equal min/max range collapsing.
4. Candidate comparison matrix percentage values and rank digits use the shared formatter.
5. Match Intelligence confidence percentages use the same formatter in both expanded and compact presentations.
6. Regression coverage checks first-transaction amount geometry above the navigation dock, Jobs row consolidation and first-fold presence at 360×640, candidate matrix fa-RTL values, and Opportunity DNA percentage/equal-budget output.

## Acceptance contract
- Run the named consolidated static gate on the final exact HEAD with no `[runtime-capture-fa]` or `[flutter-preverified]` title markers until it passes.
- Only after Static PASS, request one serialized Android fa-RTL runtime for that same HEAD.
- Verify artifact digest, exact metadata SHA, 19 primary + 6 responsive PNG count, image decode and dimensions; inspect original-resolution images before calling the wave accepted.
- TalkBack remains NOT ACCEPTED unless runtime metadata proves the accessibility service was enabled.
- Scoped CI PASS is not proof that excluded legacy test suites are healthy; keep test debt visible.

## Hard constraints
- Feature branch `feat/ui-v2-wave-1-execution-2026-10-07` only. PR #30 remains OPEN / DRAFT / UNMERGED. No `main`/production writes or merge.
- No API, payload, authentication, route, backend, ledger arithmetic, payment/job state semantic or provider changes; no dependencies added.
- `1 تومان = 1 internal unit`. Display formatting does not alter source values.
