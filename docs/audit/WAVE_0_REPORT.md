# Wave 0 — Recon & Baseline Report

Date: 2026-10-07  
Branch: `feat/ui-v2-wave-1-execution-2026-10-07`  
Source baseline SHA: `d9eb4143c2622f85d33772aebf9bc351146e265e`

## 1. What was inspected

- GitHub branch/PR/run state, source tree, Flutter theme/formatting, wallet repository/model, wallet API, capabilities endpoint, offers route, localization ARBs, existing UI source-contract tests and runtime workflow.
- Existing `.maestro/flows/hope-first-runtime.yml` and `.github/workflows/hope-maestro-first-real.yml`.
- Latest exact-HEAD Android evidence artifact #1901; all 21 PNGs visually reviewed at contact-sheet and full portrait resolution.
- Exa + Firecrawl primary Flutter accessibility guidance; current Flutter docs recommend Flutter Accessibility Guideline API for target size, labels and contrast. Exa also surfaced `shamsi_date` with BSD-3-Clause; package migration remains deferred pending lockfile/version compatibility verification.
- Full connected-tool namespace and installed-skill inventory recorded in `TOOLING_INVENTORY.md` (1,786 tools across 57 namespaces; 884 discoverable skills).

## 2. Live GitHub facts

- Feature branch HEAD: `d9eb4143c2622f85d33772aebf9bc351146e265e`.
- Run #1901 / ID `37596668414`: SUCCESS on that exact SHA.
- Artifact ID `11471421888`: 21 PNGs, 15 full-size and 6 responsive.
- PR #20: OPEN, UNMERGED, base `Main`, head SHA matches the feature branch.
- Main SHA: `69e93456e811876fbfffd0c84bc19cd4143be580`; untouched.
- `feat/ui-v2` is 24 commits behind current feature HEAD but is an ancestor, so a new isolated branch was created from current feature HEAD.
- Existing `feat/ui-v2-wave-1` is divergent (41 commits behind, 24 commits ahead in the opposite comparison); it is deliberately not reused.
- Current migrations reach `033_human_chat.js`, not 021. Future migration work starts at 034+.
- The current runtime workflow does not run Flutter analyze, the full Flutter unit suite, or the backend fast suite. Those remain NOT VERIFIED here.
- Remote Desktop Commander has no online device; local container has git but no Flutter/Maestro executable. Runtime/Flutter gates must run in CI until a machine becomes available.

## 3. Baseline evidence

See `BASELINE.md`, `DEFECT_CLOSURE.md`, `PARITY_MATRIX.md`, and `LEDGER_INVARIANTS.md`. The evidence run is green but does not qualify as visual certification because accessibility is disabled and the capture matrix is incomplete.

## 4. Decisions and changes

- Added a Wave 1 execution branch from the exact current feature SHA.
- Added tooling inventory, baseline, decisions, terminology, design token contract, icon map, ledger invariants, capability gap matrix, parity matrix, defect register, UX debt register and this report.
- No source code or historical migration was changed by Wave 0.
- No new runtime run was triggered during Wave 0.

## 5. NOT DONE / NOT VERIFIED

- No Flutter analyze or Flutter test run was executed in this environment.
- No backend fast suite run was executed; 267/267 remains historical only.
- No contrast script or full locale/theme/scale/state matrix exists yet.
- TalkBack is disabled in current evidence (`accessibility-enabled=0`).
- No 360×640 captures or scrolled/full-length captures.
- Figma file creation/editing is not verified; connected seat is View-only.
- No actual binary screenshot files were committed into the repository; baseline points to the retained CI artifact.
- No human reference, fee quote, next-action, activity badge, saved-opportunity, lifetime-earnings or candidate-comparison capability was added in Wave 0.

## 6. Wave 1 entry condition

Proceed with a grouped foundation/global defect pass, not one-off screen polish. Do not trigger runtime evidence until all scoped code changes and static/test changes are batched. Keep PR #20 open and Main untouched.
