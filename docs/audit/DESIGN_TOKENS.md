# HOPE Design System 2.0 — Token Contract

Single source currently lives in `lib/core/theme/hope_v2_design.dart`; `lib/core/theme/app_theme.dart` is a compatibility facade. The target path `lib/core/design/tokens.dart` is not present on the baseline branch; migrate only after imports are mapped to avoid a duplicate token source.

## Canonical semantic palette

| Token | Hex | Use |
|---|---|---|
| primary | `#6366F1` | primary action, focus, selected navigation |
| success | `#10B981` | completed/positive ledger events |
| warning | `#F59E0B` | genuine exceptions only |
| danger | `#EF4444` | destructive/failure |
| surface | `#0F111A` | dark base surface |
| text | `#F8FAFC` | primary dark-theme text |
| secondary accent | `#14B8A6` | restrained teal accent; avoid meaning ambiguity |
| light page | `#F4F0FB` | lavender-led light canvas |
| dark page | `#0B0F18` | near-black navy canvas |

## Spacing, shape, motion and typography

- Spacing: 4 / 8 / 12 / 16 / 20 / 24 / 32 dp.
- Radii: 12 / 16 / 20 / 28 dp; expressive hero radius only for hero surfaces.
- Motion target: 150–250 ms ease-out; respect `MediaQuery.disableAnimations`.
- Font: Vazirmatn; Latin fallback currently Roboto.
- Meaningful text floor: 12sp. Body 16sp, body-small 14sp, section 18sp, title 22sp, display 28/32sp.
- Touch target: at least 48×48dp.
- Dark/light/system theme controller exists; full screenshot parity and Profile appearance selector are not yet verified.
- Surface elevation should be communicated through restrained tint and borders rather than heavy shadows.

## Contrast verification

The baseline has no executed `tool/contrast_check.py` report. Required thresholds: normal body text 4.5:1; large text and essential icon/border controls 3:1. Run a script across dark/light surfaces and fail CI on violation before claiming compliance.

## Known debt

- Tokens are split between legacy compatibility names and `HopeV2Colors`; there is not yet a dedicated `tokens.dart`.
- Baseline contains sub-12sp metrics labels and truncation at 720×1280.
- A target token value does not itself prove contrast; calculate actual foreground/background pairs.
