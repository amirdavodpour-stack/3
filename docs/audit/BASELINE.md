# HOPE UI/UX V2 — Baseline

Date: 2026-10-07  
Source branch: `feat/google-sign-in-2026-09-20`  
Source SHA: `d9eb4143c2622f85d33772aebf9bc351146e265e`  
Evidence workflow: [HOPE UI Runtime Evidence #1901](https://github.com/amirdavodpour-stack/3/actions/runs/37596668414)  
Artifact: `hope-critical-screens-runtime-evidence-d9eb4143c2622f85d33772aebf9bc351146e265e-37596668414` (artifact ID `11471421888`)

## Environment and evidence facts

- Runtime: Android emulator, API/OS recorded in artifact metadata; Flutter 3.47.2 pinned by workflow.
- Capture transport: `flutter_integration_test_onScreenshot`.
- Locale/theme: `fa-RTL`, dark only.
- Captures: 15 primary screens at 1080×1920 and 6 responsive screens at 720×1280; 21 PNGs total.
- Runtime test exit code: 0. Workflow completed successfully.
- Accessibility metadata: `accessibility-enabled.txt = 0`; `accessibility-services.txt = null`.
- No 360×640 capture, en-LTR, light theme, font scale 1.3/2.0, keyboard-open, state matrix, TalkBack-on or full-length scroll captures in this artifact.
- The screenshot artifact is the baseline evidence source; screenshots are unmodified. The binary ZIP is retained as a GitHub Actions artifact and is not copied into the repository by the available text-file GitHub write path.

## Visual review — all 21 PNGs inspected

The 21 screenshots were reviewed in a contact sheet and individually at full portrait resolution.

Observed blockers / confirmed defects:
- `D-03`: transaction detail exposes internal reference `payment-runtime-1`.
- `D-06`: test fixture identity is visible on Profile (`ali.test@hope.local)); it is not the forbidden `runtime@example.invalid` or a stock-photo leak in this run, but the evidence account still needs a clearly isolated test-only fixture contract.
- `D-10`: Google authentication button uses a person-add glyph instead of the official Google G asset.
- `D-11`: auth and detail hero regions remain tall; detail header content overlaps/competes with title/meta at responsive width.
- `D-12`: Register CTA is partially below the visible viewport; Create Opportunity preview and form compete for initial viewport space.
- `D-17`: 720×1280 Home Pulse metric labels/values wrap and truncate; Opportunity Detail hero controls/tags overlap the artwork.
- `D-19`: Notifications action uses insufficiently distinct disabled-looking grey styling.
- `D-21`: Wallet shows balance values again in a second “ledger financial view”; deposit is correctly capability-disabled in this environment, but the visible actions do not communicate capability state consistently.
- `D-22`: Transaction detail shows duplicate status treatments and a low-progress/mostly empty six-step timeline.
- `D-24`: Saved-search filter summary still includes raw English category text (`Software`) and a camera-like action glyph.
- `D-27`: evidence is incomplete for certification: no TalkBack, no small viewport, no locale/theme/scale matrix, and no top+bottom scroll pairs.

Other defects in §6 remain OPEN unless a subsequent wave report attaches exact after screenshots and tests. Do not treat a successful screenshot workflow as proof of full visual acceptance.

## Static/runtime verification status

| Gate | Status | Evidence |
|---|---|---|
| Existing runtime source-contract checks | PASS | Run #1901 steps 6–9 |
| Android rendered screenshot capture | PASS | Run #1901, 21 PNGs, test exit 0 |
| Flutter analyze / unit tests | NOT VERIFIED in this baseline run | Not part of this workflow |
| Backend fast suite (historical 267/267) | NOT VERIFIED in this session | No test execution performed here |
| Wallet ledger invariant tests | PARTIAL / NOT VERIFIED | Source reviewed; exact test run not performed |
| Contrast script / WCAG | NOT VERIFIED | No contrast report attached |
| Accessibility/TalkBack | FAIL for certification | Metadata explicitly reports accessibility disabled |
| Visual certification | FAIL / NOT CERTIFIED | Evidence matrix incomplete and defects remain |

## Source-of-truth and branch safety

- Implementation truth: live GitHub source at the SHA above.
- Runtime truth: the run/artifact above.
- Main SHA observed: `69e93456e811876fbfffd0c84bc19cd4143be580`; leave Main untouched.
- PR #20 observed OPEN and UNMERGED, head `d9eb4143c2622f85d33772aebf9bc351146e265e`; preserve that state.
- Historical migrations now extend through `033_human_chat.js`; the older “021” checkpoint is stale. Never edit migrations 001–033; any future backend schema change starts at 034+.
