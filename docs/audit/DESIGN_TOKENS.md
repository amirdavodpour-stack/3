# HOPE Design System 2.0 — Token Contract

Single source currently lives in `lib/core/theme/hope_v2_design.dart`; `lib/core/theme/app_theme.dart` is a compatibility facade. The target path `lib/core/design/tokens.dart` is not present on the baseline branch; migrate only after imports are mapped to avoid a duplicate token source.

## Canonical color genome — updated 2026-10-15

**Hard rule: no readable text uses indigo/purple.** This includes prices, budgets, money totals, metrics, selected labels, navigation text, tab labels, text buttons, chip labels and score labels. Brand indigo may remain in action fills, focus rings, selected backgrounds/borders, progress graphics and decorative icons. If a status or score needs colored text, use its contrast-safe semantic foreground instead.

The canonical genome is implemented in `HopeV2TonalPalettes`: six 11-stop ramps (`50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950`) for brand-action, warm-neutral, information/teal, success, warning and danger. Use `palette.shade(step)` for a named tone; do not interpolate ad-hoc values or introduce a second palette source. Legacy `HopeV2Colors` tokens remain stable while the UI migrates.

Semantic foregrounds are separate from ramps: `amount` stays neutral for ordinary prices and balances; `pending` maps to warning, `processing` to information, and only actual incoming/outgoing transaction states use positive/negative semantics. Featured content uses a dedicated warm accent foreground with matching soft surfaces. `readableAccent` maps known interaction hues to a contrast-safe semantic foreground; action colors must never be passed directly to a text style.

| Role | Light foreground / token | Dark foreground / token | Intended meaning |
|---|---|---|---|
| Brand actions | `primaryAction #4F46E5`; hover `#4338CA`; pressed `#3730A3` | `primaryDark #818CF8` for fills/indicators | Primary action, focus and selection graphics only; never text |
| Money / price | `moneyTextLight #24271F` | `moneyTextDark #F1F3EC` | Neutral readable prices, budgets, balances and totals |
| Information / intelligence | `infoTextLight #0F766E` | `infoTextDark #5EEAD4` | Match score, neutral information, non-error guidance |
| Success / trust | `successOnLight #236443` | `successDark #89BD95` | Verified, completed, positive ledger events |
| Warning / pending | `warningOnLight #92400E` | `warningDark #D5B56C` | Genuine exception, pending state or attention required |
| Danger / failure | `dangerOnLight #B91C1C` | `dangerDark #DC766F` | Destructive action, failure or negative state |
| Teal accent | `secondaryAction #0F766E`; `secondary #14B8A6` | `secondaryDark #5EEAD4` | Trust/intelligence accents; avoid ambiguous success use |
| Neutral text | `ink #24271F`; `muted #66675B` | `darkText #F1F3EC`; `darkMuted #AEB7AC` | Primary, secondary and supporting copy |
| Canvas/surface | `pageLight #F2F0E8`; `panelSoftLight #FAF9F4` | `pageDark #070A12`; `darkSurface #0F111A`; `darkCard #111827` | Warm light neutral and near-black navy/charcoal hierarchy |

Semantic fills are deliberately softer than text foregrounds: use `successSurfaceLight/Dark`, `warningSurfaceLight/Dark`, `dangerSurfaceLight/Dark`, and `infoSurfaceLight/Dark` behind compact state indicators rather than washing entire cards in strong colors. The indigo tonal ramp `primaryTintLight/Dark` and `primaryBorderLight/Dark` is for fills and edges only.

## Spacing, shape, motion and typography

- Spacing: 4 / 8 / 12 / 16 / 20 / 24 / 32 dp. Compact scan cards use a 72dp editorial media tile and stack title/location/value to prevent horizontal competition at phone widths.
- Radii: 12 / 16 / 20 / 28 dp; expressive hero radius only for hero surfaces.
- Motion target: 150–250 ms ease-out; respect `MediaQuery.disableAnimations`.
- Font: Vazirmatn; Latin fallback currently Roboto.
- Meaningful text floor: 12sp. Body 16sp, body-small 14sp, section 18sp, title 22sp, display 28/32sp.
- Touch target: at least 48×48dp.
- Dark/light/system theme controller exists; full screenshot parity and Profile appearance selector are not yet verified.
- Surface elevation should be communicated through restrained tint and borders rather than heavy shadows.

## Contrast-safe semantic variants

- Brand indigo is allowed for controls and decorative state graphics, not readable text. Text in selected controls stays neutral; the selected fill, border, focus ring or icon carries the interaction signal.
- Prices and all financial values always use `HopeV2SemanticColors.amount(context)`; they do not switch to green for an ordinary value and never use brand indigo. Reserve success/danger colors for actual state or direction.
- `HopeV2SemanticColors.info(context)` resolves to readable teal on light surfaces and cyan-teal on dark surfaces. Match intelligence and informational scores use this role rather than the brand action token.
- `HopeV2SemanticColors.featured(context)` provides warm burnt-orange text (`#9A3412` in light mode, `#FDBA74` in dark mode); these are measured against neutral and featured surfaces by the Flutter widget contract and static contrast guard.
- Use `successOnLight`, `warningOnLight`, `dangerOnLight` with the matching dark variants for semantic text. Soft semantic surface tokens remain separate from their foreground tokens.
- `tool/contrast_check.py` enforces a 4.5:1 minimum for money and semantic body text across the canonical light/dark surface sets; icon/border/action states retain their respective checks.

## Contrast verification

`tool/contrast_check.py` now runs from `tools/verify-design-quality.sh` and checks the canonical light/dark text, semantic icon/border and action-label token pairs. A passing CI result is still required before claiming compliance. Required thresholds: normal body text 4.5:1; large text and essential icon/border controls 3:1. Run a script across dark/light surfaces and fail CI on violation before claiming compliance.

## Wave 8 — Quiet Surfaces + Decision Density

Runtime #2038 on HEAD `dd27d7bafd6c34dd4b3a874f8f6c7db76695c4bc` is the accepted visual input for this wave: 25/25 FA/RTL screenshots (19×1080×1920 + 6×720×1280). The screenshots show a coherent dark/indigo identity and strong featured/detail surfaces, while repeated list cards, search/filter chrome and deterministic fallback media carry too much containment and compete with decision content.

Wave 8 applies one shared composition correction: quieter dark borders/dividers and panel shadows; quieter tags and unselected filters; lower-contrast search controls; restrained deterministic fallback media; and quiet outer containers for repeated applications/work-center rows. The design grammar remains **focal surface → decision/state → quiet rows → utility**. No new brand palette was introduced.

Invariants preserved: RTL/LTR semantics, 48dp touch targets, real product data, existing wallet/ledger semantics, accessibility semantics, runtime harness contract, and `MainActivity.kt` untouched.

Acceptance gate: Static verification must pass once for this grouped tree, then exactly one serialized exact-HEAD Runtime capture must produce the complete 25-screen artifact. Actual PNGs must be inspected before Wave 8 is accepted or the next wave is planned.

## Known debt

- Tokens are split between legacy compatibility names and `HopeV2Colors`; there is not yet a dedicated `tokens.dart`.
- Baseline contains sub-12sp metrics labels and truncation at 720×1280.
- A target token value does not itself prove contrast; calculate actual foreground/background pairs.


## Wave 24 — Compact layout and scroll-end contract

- HopeV2Navigation.barHeight is the canonical dock height (68dp).
- HopeV2Navigation.scrollEndGap is a 12dp tail inside relevant scrollables. It is not a second dock reservation: the Scaffold owns dock geometry and system insets.
- At 360×640 logical dp, meaningful rows and controls must remain scrollable, end at least 12dp above the fixed dock after ensureVisible, and pass hit testing.
- Android interactive targets should remain at least 48×48dp. Use Flutter's Accessibility Guideline API for size and label checks rather than visual inspection alone.
- Compact chart axes use existing API labels; never manufacture balance points or alter financial state to make a chart look smoother.
