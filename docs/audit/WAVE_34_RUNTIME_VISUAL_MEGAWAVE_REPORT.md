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
