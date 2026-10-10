# Wave 30 — Dual-locale runtime and text-scale resilience superwave

## Starting point

- Certified predecessor: Wave29 exact HEAD `8ebbb3edc78e613d39918ea7cc0e33512fce6109`.
- PR #30 is intentionally OPEN / DRAFT / UNMERGED against `feat/google-sign-in-2026-09-20`.
- `main`/production are forbidden write targets.
- This report does not claim acceptance until exact-head Static CI and Android evidence have completed.

## Grouped implementation

- Home Pulse switches from four tightly constrained metric cells to two readable columns when the user increases system text above 1.2x. Stable cell keys make the row reflow measurable in a widget regression; standard-scale wide layout remains four columns.
- Wallet's internal-money-flow signature retains the compact horizontal triad at ordinary scale. At enlarged text, its three steps become full-width, vertically stacked labeled rows; Toman amounts continue using the existing formatter and are not shrunk or ellipsized.
- Work Center stops forcing its payment/job lifecycle into compact icons/connectors at enlarged text, preserving readable stage names in English LTR.
- Explore has an English/LTR 360×640dp + 1.5x regression that verifies the headline, featured label, single-column card variants, and absence of Flutter layout exceptions.
- Full-resolution review of the first English/LTR 1.5x Android artifact found the Profile language label wrapping into three narrow lines beside its segmented selector. The responsive branch now stacks details above the selector whenever text scale exceeds 1.2x, while preserving the horizontal layout at standard scale. A dedicated 360×640dp widget regression asserts a compact title and a selector aligned under the details, safely above the fixed dock. The consolidated Flutter command and its source guard both include `test/features/profile/profile_page_test.dart`, so the regression executes rather than merely residing in the tree.
- Runtime certification gains a validated `HOPE_CAPTURE_TEXT_SCALE` parameter (1.0, 1.25, 1.5, 2.0). The one-shot PR marker `[runtime-capture-en-scale]` selects English at 1.5x and metadata records the numeric scale.
- Static CI includes the runtime-driver contract and Home Pulse regression in its consolidated gate.
- The first en-LTR 1.5x Android attempt rendered all 19 primary images and passed the Flutter driver body, but the host wrapper rejected `responsive-b`: the wrapper expected Wallet as the fourth responsive screen while the test driver intentionally isolates Transactions fourth, then Wallet/Profile in the final session. The shell marker list is now aligned with the driver map order (Transactions → Wallet → Profile), and the host contract asserts that order so this mismatch cannot recur.
- Full-resolution review of the first en-LTR 1.5x artifact also found the Wallet flow heading competing with its currency badge and the explanatory copy being ellipsized. The enlarged-scale branch now stacks the badge under a wrapping heading and removes the two-line clamp for the explanation; the widget regression explicitly asserts both Text widgets have no max-line clamp.
- Corrective change: `3cb73a780a4e7a3e6e419d0e87ec3ffd47398b0e`. The focused contract and runtime workflow need to be revalidated after this order correction; prior runtime artifact is retained as a failed attempt, not accepted evidence.

## Acceptance matrix

- Static CI must run with all runtime/`flutter-preverified` markers absent from the PR title, then pass on the exact code/test SHA.
- Only after Static PASS may the PR title gain `[runtime-capture-en-scale] [flutter-preverified]`. Runtime evidence is accepted only for the same SHA with metadata `capture_locale=en`, `text_scale=1.5`, `screens=19`, `responsive_screens=6`, and `test_exit_code=0`.
- Inspect every primary/responsive PNG, compute unique hashes, inspect metadata, and record archive SHA-256.
- TalkBack/T10 remains NOT ACCEPTED unless the Android artifact proves an enabled accessibility service. English/LTR imagery is not TalkBack certification.

## Scope invariants

No backend/API payload, authentication decision, route, wallet/ledger arithmetic, payment transition, job lifecycle semantics, or provider integration was intentionally changed. No dependency was added.

## Branch policy

- Feature branch: `feat/ui-v2-wave-1-execution-2026-10-07`
- Base branch: `feat/google-sign-in-2026-09-20`
- PR: [#30](https://github.com/amirdavodpour-stack/3/pull/30), draft and unmerged.
