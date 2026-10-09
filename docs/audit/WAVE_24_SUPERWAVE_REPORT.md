# HOPE Visual Superwave Wave 24 — Expanded Audit and Acceptance Report

**State at assembly:** implementation grouped; exact-head static CI and runtime evidence pending.  
**Repository:** `amirdavodpour-stack/3`  
**Branch:** `feat/ui-v2-wave-1-execution-2026-10-07`  
**Starting HEAD:** `d383bb2462edb6df9608daa89b230efe1d89a486`

## Objective

Turn Wave23's reviewed runtime defects and the supplied HOPE Design System 2.0 reference into one coherent, behavior-preserving compact UI wave. The reference image is a visual direction, not authority to invent financial amounts, job data, routes or backend state.

## A — Dock, scrolling and navigation

- Add shared `HopeV2Navigation.scrollEndGap = 12dp` and consume the canonical 68dp dock height token.
- Key the Wallet history row, Profile language selector and each Work Center lifecycle panel.
- Provide a non-empty wallet transaction fixture.
- At 360×640dp, scroll each target into view, assert a 12dp gap above the fixed dock, and test hit-target visibility.
- Keep OS padding, keyboard viewInsets and dock reservation distinct. Do not add arbitrary full-dock padding twice.

## B — Compact discovery

- Expose existing ALL / JOB / MISSION state in a 48dp segmented control wired to the existing kind callback.
- Reduce compact opportunity media from 70dp to 64dp while preserving title, full budget amount, company, work mode, location and match signal.
- Preserve four model-backed match components and the wide layout.

## C — Work and communication

- Work Center lifecycle panels gain stable keys and a scroll end-gap.
- Compact application cards reduce inner padding to 11dp and long lists gain a normal scroll tail.
- Chat composer shows at most three visible lines, while multiline input and send behavior remain unchanged.

## D — Auth and Create Opportunity

- Reduce auth prefix glyphs from 20px to 18px without shrinking Material input slots, field height or suffix actions.
- Compact Create Opportunity choices use tighter padding and 22px icon art. Required fields, fees, validation and route behavior remain unchanged; the existing live preview stays collapsed.
- Satisfaction remains explicit-choice-only; required answers remain unselected until user input, and submit gating is preserved.

## E — Financial chart clarity

- Monthly cash-flow bars reserve a label band and display the API-provided month label (fallback to month key).
- A keyed legend maps the existing inflow/outflow/reserved colors to their labels.
- Balance-trend chart shows API-provided date strings in the current text direction.
- No amount, balance arithmetic, ledger flow, payment status or job lifecycle transition changes.

## Evidence and tool boundaries

- Exa and Firecrawl reviewed official Flutter SafeArea/MediaQuery, adaptive-layout and accessibility-testing guidance.
- Desktop Commander is online, but its available local checkout belongs to a release branch; no local release-branch source was changed. The GitHub feature branch remains the source of truth.
- The existing Canva HOPE UI Audit Board was reused. No unavailable Figma/Miro/MagicPath artifact is represented as implementation evidence.
- No backend or dependency changes are intended.

## Required exit gates

1. The static workflow completes backend fast/security/static, lock/dependency, contrast, source guards, Flutter Analyze, and exactly one consolidated Flutter test invocation on one feature SHA.
2. Only after static PASS, one Android runtime capture runs against that exact feature SHA. Runtime skips the Flutter test command already passed by static.
3. Runtime metadata SHA matches the feature SHA. Artifact contains 19 primary + 6 responsive PNGs, with archive SHA-256 recorded.
4. Open and individually inspect every PNG. Record residual issues and actual accessibility-service state.
5. PR #30 remains open, Draft and unmerged. `main/production` is untouched. TalkBack/T10 remains NOT ACCEPTED unless separately evidenced with accessibility enabled.

## Official references

- [SafeArea & MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery)
- [Adaptive and responsive design](https://docs.flutter.dev/ui/adaptive-responsive)
- [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing)
- [Android tap-target guideline](https://api.flutter.dev/flutter/flutter_test/androidTapTargetGuideline-constant.html)

## Test-scope clarification (2026-10-09)

The first expanded run surfaced old widget files not included in the Wave23 green suite; several assert legacy Wallet/Profile/Opportunity Detail labels and keys that do not match the current implementation. Wave24 does not claim those tests passed. The authoritative Wave24 command keeps the prior seven-test Wave23 baseline and adds focused tests for the touched compact UI surfaces. The old broader widget files are excluded from this particular command, and their failures remain documented rather than being counted as Wave24 failures or successes.

The focused suite explicitly tests the compact Wallet history row, Profile language selector, Work Center lifecycle, Explore filter state, finance chart legend and navigation target/label guidance. A final PASS still requires one exact-head static run plus a same-head runtime capture and individual review of all 25 screenshots.
