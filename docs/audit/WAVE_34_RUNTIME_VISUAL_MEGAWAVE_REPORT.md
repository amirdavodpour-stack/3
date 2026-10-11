# Wave 34 — Runtime-grounded visual mega-wave

## Baseline evidence

- Source screenshot artifact: Runtime run [38050392925](https://github.com/amirdavodpour-stack/3/actions/runs/38050392925)
- Baseline source HEAD: `06fd5a51466bdefbc663666fd6e06a6cc54ca498`
- Artifact ID: `11669048199`; archive SHA-256: `2ba97585cec61c483b48a27c6507fbf48018f3f2e7f7aa302b8a3d2d551c2c99`
- Capture: native Android PixelCopy; fa-RTL; dark theme; logical viewport 360×640dp; 1.0 text scale; 19 primary + 6 responsive images.
- Screenshot review: `docs/audit/evidence/android-runtime/` in the downloaded workflow artifact (25 unique PNG files).
- TalkBack/T10 is not accepted: the artifact records `accessibility-enabled.txt=0` and `accessibility-services.txt=null`.

## Findings anchored in the baseline

1. Financial Insights used 9–11dp painter-rendered axis labels and 11dp legend text. The plot identified cash-flow series by color alone, and custom-painter text did not scale with the system text scale.
2. Candidate matching hid its real-value comparison matrix below the medium-width breakpoint, leaving compact phones with only a vertically stacked scan path. The “Best fit” label used a dark-theme muted color even in light mode.
3. Offers status filters used a wrapping flow. The final filter could wrap to another row and push offer content farther below the first fold.
4. Chat message timestamps used label-small typography and inherited overall RTL direction even though formatted time is a directional token.
5. Saved-search scope summaries concatenated user query/city text with localized Persian labels without isolating mixed-script substrings.
6. Other surfaces still need follow-up: Home/Explore first-fold space, a true stateful five-step Create Opportunity flow, compact Opportunity DNA, and error/empty/offline/IME/accessibility states. These are not misrepresented as fixed by this wave.

## Wave 34 implementation

- Financial charts: 12dp baseline labels and legend text, chart width responsive to text scale, extra label/plot height, directional/lock glyphs to distinguish series beyond color, repaint invalidation when axis color changes, and a widget regression at 1.5× text scale.
- Candidate matching: real-value comparison matrix at compact widths inside its existing horizontal scroller; light-mode muted foreground; 360×800dp comparison regression.
- Offers: one horizontal status-filter rail instead of a wrapping two-row group.
- Chat: more readable timestamps with explicit LTR direction and stable keys.
- Saved searches: Unicode bidi isolates around user query and city values.
- No API, ledger arithmetic, payment status, matching values, navigation, authentication, data semantics, backend behavior or package dependencies intentionally changed.

## Acceptance gates

- Run Flutter Analyze and the repository's consolidated Flutter regression suite on the exact resulting branch HEAD, together with existing backend/security/lockfile/design/source guards.
- Only after static PASS, restore the runtime-capture PR marker and run one serialized Android fa-RTL capture on that exact frozen HEAD. Do not use an older run as acceptance evidence.
- Inspect all new primary/responsive PNGs and metadata before concluding the visual wave is accepted.
- Recheck 360×640dp and 1.5× text scale; 411×731dp, 2.0× text, loading/empty/error/offline/keyboard and TalkBack require explicit evidence in follow-up lanes.
- Keep PR #30 OPEN / DRAFT / UNMERGED; never force-push or modify main/production.

## Wave 34 follow-on — truthful five-stage creation and shared opportunity readability

- Create Opportunity no longer presents five decorative milestones above a single long form. Stages now separate type/audience, details, compensation/schedule, fees/acceptance criteria, and final review.
- Step changes reset the form scroll position. The live preview appears in the final review, is still driven only by current user-entered values, and the existing create-then-publish use case remains unchanged.
- The selected opportunity-type tile uses paired Material primary-container colors for the selected fill and foreground, avoiding white-on-translucent-primary contrast assumptions across light and dark themes.
- Shared compact opportunity cards now use theme-aware location color, less undersized type/budget metadata, and explicit widget keys for contrast and 1.5×-scale regressions.
- Tests were adapted to traverse the real steps for mission/job creation, validation, busy/failure behavior, and job-deadline requirements; additional tests cover step isolation/back navigation and compact-card readability.
- The offers-source guard accepts either the prior wrapping filters or the new horizontally scrollable `offers-status-filter-scroll`; widget tests assert that the new rail is horizontal.

## Wave 35 follow-on — category localization and truthful progress labels

- The runtime Job Detail screenshot exposed a known category value (`Software`) untranslated in a Persian interface. A shared taxonomy formatter now maps known backend category slugs/labels to official app-localization strings in OpportunityCard, Job Detail, and Saved Searches. Unknown/custom category names remain untouched in cards/details; saved-search filters retain their existing safe “Other” fallback.
- The five-step creation progress rail now matches the real staged form: Type, Details, Budget, Criteria, Review; its current-step headline uses the same localized numbering.
- The 1.5× financial chart regression was hardened to drive the keyed outer list directly until Flutter mounts the lazy balance chart.

## Wave 36 — runtime-driven localization and chart semantics

- The Wave 35 native Job Detail capture still showed the English category label in the hero and recommendation decision strip. Both now use the canonical taxonomy mapper; the wider Opportunity DNA signature shares the same mapper rather than carrying a second category table.
- Persian progress labels now use Persian digits in both the current-step headline and all numbered step circles.
- Painted cash-flow and balance charts expose localized semantic descriptions of their actual recorded month/date/value sequences. Dedicated tests cover category localization across the Job Detail hero/decision strip, Persian progress numbering, and recorded chart semantics.
- The existing native evidence does not certify TalkBack: the artifact reports `accessibility-enabled.txt=0` and `accessibility-services.txt=null`. Semantic widget tests are not a substitute for an enabled-service runtime accessibility pass.

## Wave 36 — exact-HEAD runtime artifact inspection (2026-10-10)

### Provenance and integrity
- Runtime run: [38070229927](https://github.com/amirdavodpour-stack/3/actions/runs/38070229927), conclusion `success`, source HEAD `2af62ffad6157300abd85378d2b796fb23900034`.
- Artifact ID: `11676716904`; GitHub SHA-256 digest: `a18b55a5fa271b14b6e80546b78b381436f3eca74f459cbeef79c12756c907e8`. Independently computed archive SHA-256 matches exactly.
- Native PixelCopy artifact contains 25 distinct PNGs: 19 primary screens at 1080×1920 and 6 responsive screens at 720×1280 (360×640dp), fa-RTL, dark theme, text scale 1.0. Metadata reports `test_exit_code=0`.
- All 25 PNGs were opened and individually visually reviewed. The inventory, unique image hashes, metadata, and exact source SHA were checked.

### Baseline comparison and observed scope changes
- Baseline runtime: [38063346940](https://github.com/amirdavodpour-stack/3/actions/runs/38063346940), HEAD `560dde349bf5b6223878ab31bd7d999d63990885`; artifact ID `11673909591`. Independently computed archive SHA-256 matches GitHub's `8013b8c5dd6f68191e77b21abe1f7af7cc2d2ccf909c2f1253d7ff4d17be831d`.
- Alpha-agnostic RGB comparison: 22/25 images are byte-identical; 22/25 are RGB-identical. Three images have RGB differences:
  - `create-job-fa-rtl.png`: 874 changed RGB pixels (0.0421%), consistent with localized Persian step numerals.
  - `job-detail-fa-rtl.png`: 19,759 changed RGB pixels (0.9529%), consistent with localizing the known category `Software` to the app's Persian category label across the hero and category chip.
  - `responsive-720x1280-job-detail-fa-rtl.png`: 5,769 changed RGB pixels (0.6260%), consistent with the same category localization at the responsive viewport.
- Visual review confirmed the category is localized in the main and responsive Job Detail hero and taxonomy chip. The Create Opportunity progress headline/circles show Persian numerals. No overlap or clipping attributable to these changed regions was found in these captures.
- No claim is made that the 25 screenshots certify every app state, English/LTR, 1.5× text scale, keyboard/IME, offline/error state, or screen-reader behavior.

### Remaining gates and limits
- The Static workflow for source HEAD `2af62ffad6157300abd85378d2b796fb23900034` was `skipped`; the consolidated Flutter test step in the runtime workflow was also `skipped`. Therefore this runtime artifact is inspected evidence but does **not** substitute for a green exact-HEAD static gate.
- `accessibility-enabled.txt=0` and `accessibility-services.txt=null`; TalkBack/T10 remains **NOT ACCEPTED**.
- The PR title markers `[runtime-capture-fa]` and `[flutter-preverified]` were removed to unblock the static gate. Changing the title alone did not trigger the PR-only Static workflow because it does not declare the `edited` activity type. This report update will create a normal branch commit and trigger PR `synchronize` without starting a new runtime capture.
- This artifact belongs to `2af62ffad6157300abd85378d2b796fb23900034`. After the report commit, it is historical evidence for its recorded SHA; fresh visual acceptance requires Static PASS and then one serialized capture on the resulting exact HEAD.
