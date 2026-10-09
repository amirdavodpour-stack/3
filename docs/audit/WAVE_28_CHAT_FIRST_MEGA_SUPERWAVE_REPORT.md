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
**Pending.** Source presence is not proof of success. Record the exact-head consolidated Flutter tests and static CI result before triggering the Android runtime capture. Inspect new Chat, Financial Insights, and responsive evidence from the same head. TalkBack/T10 remains NOT ACCEPTED unless runtime metadata explicitly reports an enabled accessibility service.

## Branch policy
Only `feat/ui-v2-wave-1-execution-2026-10-07` is in scope. PR #30 stays OPEN / DRAFT / UNMERGED. `main`/production are forbidden write targets; do not force-push, merge, publish, or bypass checks.
