# HOPE Design System 2.0 — Wave 26 Superwave Report

## Evidence boundary

- Repository: `amirdavodpour-stack/3`
- Feature branch: `feat/ui-v2-wave-1-execution-2026-10-07`
- Base branch: `feat/google-sign-in-2026-09-20`
- Starting feature HEAD for this batch: `b4b64e72c0afb8d9ef8515436385464b0fb270e9`
- PR #30 must stay **OPEN / DRAFT / UNMERGED**. `main/production` is forbidden.
- Static outcome must be read from the workflow run linked to the resulting exact HEAD; runtime visual acceptance remains pending until fresh same-HEAD screenshots are available and reviewed.

## Design and product inputs actually used

- Notion's `HOPE Visual Superwave Execution Skill` and `Wave 23 Runtime Audit + Wave 24 Execution Plan` define the grouped scope and acceptance rules.
- The existing Canva `HOPE UI Audit Board` was inspected rather than duplicated. It requires Persian-first RTL, responsive layout, source-grounded data, a clear primary action and touch targets of at least 48dp.
- Exa research retrieved official Flutter guidance for `SafeArea`, `MediaQuery`, adaptive layout and accessibility testing. These inform the responsive and enlarged-text constraints.
- GitHub is the implementation/test source of truth. Notion/Canva/research do not substitute for build, test or screenshot evidence.
- Miro/Whimsical/Amplitude probes did not surface a project-specific artifact or useful V2hope product analytics in this probe; no results were invented. Figma edits, paid assets and generated media were not prerequisites or introduced.

## Wave 26 grouped implementation

1. **Navigation labels/semantics:** keep the five Persian navigation labels visible at narrow widths; the legacy regression expects the intended visible Profile label and enables the semantics tree before checking its accessible name.
2. **Adaptive Explore density:** use one-column presentation when text scale exceeds 1.2 even on wide canvases; do not force accessibility-scaled text into two/three dense columns.
3. **Financial disclosure on cards:** compact-grid, compact, standard and expanded opportunity-card amount ranges wrap over up to three lines instead of using ellipsis. Compact-grid media height is reduced to reclaim vertical space for the financial value.
4. **Executable regression coverage:** assert complete minimum/maximum Toman values and that the compact-grid amount paragraph does not exceed its line limit; add an Explore test for enlarged text fallback.
5. **Persistent guardrails:** source guard pins the high-text fallback and no-ellipsis amount contract.

## Business and safety invariants

- No API payloads, backend state transitions, wallet/ledger calculations, idempotency, payment lifecycle, routes, fake amounts or new package dependencies are changed.
- The financial-card contract is display-only: preserve model-provided budget/salary values and change layout only.
- PR #30 is not merged; `main/production` remains out of scope.

## Verification status at assembly

- Baseline static attempt on the starting HEAD: [run 37971041004](https://github.com/amirdavodpour-stack/3/actions/runs/37971041004) failed at the consolidated Flutter invocation (102 passed, 1 failed). The remaining failure is a semantics-name finder run with the semantics tree disabled; this batch enables semantics instead of removing the assertion.
- The first grouped run on this batch, [run 37972172732](https://github.com/amirdavodpour-stack/3/actions/runs/37972172732), failed in the backend executable-permissions test because the Git tree assembly accidentally changed `test/runtime/premium_visual_wave_source_test.sh` from mode `100755` to `100644`. This is a packaging/mode regression, not a test assertion; the follow-up commit explicitly restores mode `100755`.
- The next exact-HEAD static run must pass backend checks, contrast/source guards, Flutter Analyze and the one consolidated Flutter invocation before any visual acceptance claim.
- Same-HEAD runtime capture and visual inspection remain pending. Do not claim screenshot parity or a higher visual-alignment percentage from source/CI results alone.
- TalkBack/T10 remains **NOT ACCEPTED** unless a fresh runtime artifact proves accessibility is enabled and a screen-reader service is active.

## Acceptance checklist

- [ ] Grouped static gate passes on the exact resulting feature HEAD.
- [ ] One consolidated Flutter invocation passes, including Wave 26 budget and enlarged-text tests.
- [ ] Same-HEAD runtime capture produces the expected primary/responsive screenshot set.
- [ ] Inspect each new screenshot and report residual issues.
- [ ] Keep PR #30 open/Draft/unmerged and leave `main/production` untouched.
