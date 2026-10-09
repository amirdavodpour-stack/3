# Wave 28 — Chat-first visual mega-superwave

## Scope
- Reorganizes the chat surface into a compact, source-backed conversation header, a calmer message timeline, grouped consecutive sender labels, and a visually separate composer.
- Removes the oversized decorative chat input glyph while preserving the 48dp send target; enables send only for non-empty drafts and restores the draft after a failed request.
- Compresses Financial Insights first-fold vertical rhythm on compact-height devices so the real cash-flow chart months and actual three-series legend are available earlier; values and chart series remain repository-sourced.
- Normalizes decorative authentication field glyphs to 16dp / 1.6 stroke without reducing field control or password-action hit areas.
- Adds compact chat layout/accessibility-target tests, a failed-send draft regression, message grouping coverage, a 360×640 first-fold financial regression, and a compact Work Center last-row/dock hit-test.
- Extends existing runtime source guardrails.

## Non-goals and invariants
No dependencies, API, payload, route, authentication decision, wallet/ledger arithmetic, financial calculation, payment transition or job lifecycle rule is intentionally changed. No chat features unsupported by the current repository (search, typing, receipts, attachments, reactions) are fabricated. Monetary displays remain backed by repository data. Primary action targets remain at least 48dp.

## Verification
Wave28 initial exact-head Static run 37996055350 passed with 111 consolidated Flutter tests. Android run 37996231004 passed on that same SHA and generated 19 primary + 6 responsive fa-RTL PixelCopy screenshots (artifact ID 11647990553; archive SHA-256 e2e13f1620b40f6646390195e4dc0d014887fe2b19ef4ca545788c81abf4c85b). Post-capture visual review found residual Auth field glyphs still read oversized and cash-flow legend was not legible on the actual capture, despite source-level size changes. Follow-up calibration replaces auth prefixes with standard 18dp Material glyphs plus exact render-box tests, and places the real three-series legend before the plot with a plot-order/visibility regression. Follow-up exact-head Static and Android verification are required before accepting those refinements. TalkBack/T10 remains NOT ACCEPTED because accessibility metadata says enabled=0 and services=null.

## Branch policy
Only `feat/ui-v2-wave-1-execution-2026-10-07` is in scope. PR #30 stays OPEN / DRAFT / UNMERGED. `main`/production are forbidden write targets; do not force-push, merge, publish, or bypass checks.
