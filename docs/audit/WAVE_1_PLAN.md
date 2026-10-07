# Wave 1 — Foundation + Shell + Global Defect Sweep

## Implementation scope

1. Shared formatting: remove user-visible internal payment IDs; extend integer-money/range, Jalali/relative-time and stable-reference contracts with tests. Do not invent a human reference while server capability is false.
2. Shared wallet semantics: remove duplicated “نمای مالی دفترکل” balance view; render total once and hold breakdowns as subsets; hide unsupported deposit action from the normal UI; preserve transfer/withdraw/history idempotency behavior.
3. Shared theme/components: preserve existing `HopeV2Colors` as the single token source for this wave; document contrast gaps, then add a contrast script after exact color/surface pairs are mapped.
4. Auth/iconography: use an official Google G asset only if an approved asset is already in repository or can be added from the official brand source; otherwise document as open rather than redraw it. Compact auth hero without changing auth/session behavior.
5. Layout defects: fix Home metric label/value shrink/truncation and Detail hero overlap at responsive widths; reduce Create Opportunity live preview to a collapsible peek; ensure Register CTA can scroll into view and remains above keyboard.
6. Copy/category formatting: replace raw category enums at display boundaries with localized mapping; use relative/Jalali formatter consistently in Notifications and Offers; add static guards for raw IDs/ISO patterns and ARB key parity.
7. Tests/evidence: add/extend widget/source tests; run existing Flutter/backend checks via CI if available; only then trigger one exact-HEAD runtime evidence capture. No intermediate runtime runs.

## Files to inspect/change (confirm before mutation)

- `lib/core/theme/hope_v2_design.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/theme_controller.dart`
- `lib/core/ui/hope_display_formatters.dart` and `test/core/ui/hope_display_formatters_test.dart`
- `lib/features/transactions/transaction_widgets.part.dart`
- `lib/features/wallet/wallet_page.dart`, `test/features/wallet/wallet_page_test.dart`
- `lib/features/home/premium_home_feed.dart`, `lib/features/marketplace/job_detail_page.dart`, `lib/features/marketplace/create_job_widgets.part.dart`
- `lib/features/auth/login_page.dart`, `lib/features/auth/register_page.dart`
- `lib/features/notifications/notifications_page.dart`, `lib/features/offers/offers_page.dart`, `lib/features/marketplace/job_detail_page.dart`
- `lib/l10n/app_fa.arb`, `lib/l10n/app_en.arb`, generated localization output only via `flutter gen-l10n`
- `test/runtime/premium_visual_wave_source_test.sh`, formatter/widget tests, CI workflow guards
- Backend changes only if the existing capability/fee contract audit proves a missing endpoint can be added safely. Historical migrations 001–033 are immutable; future schema changes begin at 034+.

## Acceptance gates

- Integer TOMAN only; no UI fee math; no internal IDs/UUIDs rendered.
- One wallet total; subcategories do not double-count.
- No new fake trust/rating/response-time/distance/earnings values.
- Persian-first formal copy, RTL-safe amounts and dates.
- 48dp touch targets; no important labels below 12sp.
- Static/test suite before one runtime capture; inspect every screenshot; batch one fix pass; hard cap two evidence runs for this wave.
- Wave report includes actual run IDs, screenshots, defect status, parity delta and NOT VERIFIED/NOT DONE list.
