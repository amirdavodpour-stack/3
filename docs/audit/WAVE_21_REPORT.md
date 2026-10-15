# Wave 21 Audit + Implementation Report — 2026-10-09

## Status
**Implementation gate pending.** The Wave 20 baseline run succeeded, but Wave 21 has not yet been tested or captured. T10 is not accepted.

- Repository: `amirdavodpour-stack/3`
- Feature branch: `feat/ui-v2-wave-1-execution-2026-10-07`
- Baseline source HEAD: `1d3c92f3742fd76880a2325dc9504b1d4d2ef209`
- PR: #30, Draft / unmerged, base `feat/google-sign-in-2026-09-20`
- Baseline runtime: [37903124390](https://github.com/amirdavodpour-stack/3/actions/runs/37903124390)
- Baseline artifact: `11603134050`
- New artifact acceptance: pending Wave 21 static gate and exact-head capture.

## Screenshot matrix
The baseline artifact contains 25 PNGs and metadata for:
- 19 primary Persian/RTL screens: Home, Jobs, Job Detail, My Applications, Saved Searches, Transactions, Transaction Detail, Wallet, Profile, Notifications, Offers, Create Opportunity, Login, Register, Password Reset, Financial Insights, Job Satisfaction, Candidate Matches, Chat.
- 6 responsive 360×640dp views captured at 320dpi: Home, Jobs, Job Detail, Wallet, Profile, Transactions.
- Runtime metadata records dark theme, fa-RTL, native Android PixelCopy and a 48px interactive-target contract. Accessibility services were not enabled, so screenshot review does not certify TalkBack.

## Findings and disposition

| Priority | Artifact evidence | Defect | Wave 21 response |
|---|---|---|---|
| P0 | `notifications-fa-rtl.png`, `offers-fa-rtl.png` | Jalali date year renders as 3005 rather than 1405; Persian date numbers remain Latin | Correct Gregorian epoch offset; localize all Persian relative/absolute-date digits; test forward and past dates |
| P0 | `login-fa-rtl.png`, `register-fa-rtl.png`, `password-reset-fa-rtl.png` | Compact hero icon collides with hero heading; foreground icon is omitted but fallback decoration still renders it | Pass no icon to the fallback whenever `compactHero=true`; add a subtree regression assertion |
| P1 | `wallet-fa-rtl.png`, `responsive-720x1280-wallet-fa-rtl.png` | Lower ledger-flow panel repeats money values already shown in the balance card, and mixes distinct balance fields under the same visual hierarchy | Replace duplicate numeric cards with a compact, static ledger lifecycle narrative; leave source balances and backend semantics untouched |
| P1 | `offers-fa-rtl.png` | Four filters form a wider-than-viewport horizontal row, clipping the rejected state and hiding discoverability | Wrap status chips into responsive rows |
| P1 | `job-detail-fa-rtl.png`, `responsive-720x1280-job-detail-fa-rtl.png` | Hero and trait cards use too much compact first-fold height; useful opportunity details are pushed below the sticky action boundary | Reduce compact hero and tile heights while retaining all real values/scores |
| P1 | `financial-insights-fa-rtl.png` | Four summary numbers have weak grouping; single-line metric values can be ellipsized | Two-column, individually surfaced metric tiles; allow exact money values up to two lines |
| P1 (evidence integrity) | `metadata.json` and runtime job log | Artifact metadata field `sha` reports merge SHA `696e3de...`; job log records `HOPE_RUNTIME_EXACT_HEAD:1d3c92f...` and artifact API points to feature `head_sha=1d3c92f...` | Export the exact checked-out source SHA via `GITHUB_ENV`; write that SHA to metadata, with `GITHUB_SHA` fallback only outside the PR exact-head path |

## Implementation scope
Production/source changes are bounded to shared display formatting, premium Hero composition, wallet flow signature, Offers filters, Financial Insights metric hierarchy, Opportunity Detail compact density, runtime SHA provenance and regression guards. No API or business logic change is in scope.

## Verification plan
1. One invocation: `flutter test --no-pub test/core/ui/premium_visual_wave_15_test.dart test/core/ui/hope_display_formatters_test.dart`.
2. Static gate: backend fast tests, security/static checks, localization parity, contrast/source guards, Flutter analyze and the one focused test invocation.
3. After static success, append `[runtime-capture-fa] [wave21-preverified]` to the PR title. Runtime workflow then skips a duplicate Flutter test and captures the exact feature SHA.
4. Validate 25 PNGs, metadata source SHA, screenshot set, responsive 360×640dp at 320dpi and all Wave 21 criteria.
5. Record per-screen outcomes. Do not accept T10 before the artifact is reviewed.

## Visual invariants
- RTL order, Persian typography and localization remain intact.
- Money uses exact internal Toman values; no rounding or display truncation of critical financial values.
- Existing API-backed fields and lifecycle state stay authoritative.
- No new dependencies, provider/payment logic, authentication behavior, route semantics or permission changes.
- PR #30 stays Draft/unmerged; `main/production` remains untouched.
