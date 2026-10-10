#!/usr/bin/env sh
# [runtime-capture-fa] exact-head discovery density validation.
# Grouped visual-wave source guard for the consolidated editorial hierarchy + quiet-surface redesign.
# [runtime-capture-fa-home] isolate editorial media to the Home discovery capture.
# Final verification capture after adding the scoped fixture contract.
# The restored #1560 baseline does not require a runtime media fixture; editorial media activation remains a separate visual wave.
set -eu

opportunity="lib/core/ui/opportunity_card.dart"
premium="lib/core/ui/premium_components.dart"
theme="lib/core/theme/hope_v2_design.dart"
home="lib/features/home/premium_home_feed.dart"
jobs_widgets="lib/features/jobs/jobs_widgets.part.dart"
android_theme="android/app/src/main/res/values/styles.xml"
android_theme_v26="android/app/src/main/res/values-v26/styles.xml"
runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"

test -f "$opportunity"
test -f "$premium"
test -f "$home"
test -f "$runtime_driver"

sh test/runtime/editorial_media_fixture_source_test.sh
sh test/runtime/editorial_media_fixture_scope_test.sh

grep -Fq 'String? mediaUrl' "$opportunity"
grep -Fq '_fallbackMedia(context, primary)' "$opportunity"
grep -Fq "final media = ClipRRect(" "$opportunity"
grep -Fq "final mediaSize = compactViewport ? 64.0 : 88.0;" "$opportunity"
grep -Fq "height: 72" "$opportunity"
# Compact media keeps its existing footprint; standard media is the stronger editorial anchor.

grep -Fq 'class _HeroEditorialFallback extends StatelessWidget' "$premium"
grep -Fq 'static const darkBorder = Color(0x1FFFFFFF);' "$theme"
grep -Fq 'static const darkBorderStrong = Color(0x2BFFFFFF);' "$theme"
grep -Fq 'static const darkDivider = Color(0x18FFFFFF);' "$theme"
grep -Fq 'static const barHeight = 68.0;' "$theme"
grep -Fq '_HeroEditorialFallback(' "$premium"

grep -Fq 'padding: const EdgeInsets.fromLTRB(16, 6, 16, 24)' "$home"
grep -Fq 'fontSize: compact ? 20.5 : 27' "$premium"
grep -Fq 'class PremiumEmptyState extends StatelessWidget' "$premium"
grep -Fq 'maxLines: 2,' "$opportunity"
grep -Fq 'softWrap: true' "$opportunity"
grep -Fq 'childAspectRatio: columns == 3 ? 0.92 : 1.02' "$home"
grep -Fq 'PremiumEmptyState(' "lib/features/jobs/saved_searches_page.dart"
grep -Fq 'PremiumEmptyState(' "lib/features/applications/my_applications_page.dart"
grep -Fq 'PremiumEmptyState(' "lib/features/notifications/notifications_page.dart"
grep -Fq 'PremiumEmptyState(' "lib/features/chat/chat_page.dart"
grep -Fq 'this.radius = HopeV2Radii.lg' "$premium"
grep -Fq 'fontSize: 11' "$premium"
grep -Fq 'alpha: Theme.of(context).brightness == Brightness.dark ? .055 : .07' "$premium"
grep -Fq 'color: Colors.transparent,' "$premium"
grep -Fq 'HopeV2Surfaces.controlBorder(context).withValues(alpha: .30)' "lib/core/ui/components.dart"
grep -Fq 'variant: OpportunityCardVariant.compact' "$home"
# Current Home density contract is validated by its exact layout structure; no legacy vertical-spacing literal is required.
grep -Fq 'if (recommended.length > 1)' "$home"
grep -Fq 'OpportunityCardVariant.compact' "$jobs_widgets"
grep -Fq 'padding: EdgeInsets.all(compact ? 10 : HopeV2Spacing.md)' "lib/core/ui/premium_lifecycle.dart"
grep -Fq '<item name="android:navigationBarColor">#070A12</item>' "$android_theme"
grep -Fq '<item name="android:windowLightNavigationBar">false</item>' "$android_theme_v26"

register_block="$(sed -n '/if (child is RegisterPage)/,/if (child is PasswordResetPage)/p' "$runtime_driver")"
register_capture_block="$(printf '%s\n' "$register_block" | sed '/if (child is RegisterPage)/,/return;/p')"
printf '%s\n' "$register_capture_block" | grep -Fq "HOPE_RUNTIME_REGISTER_DIRECT_CAPTURE"
printf '%s\n' "$register_capture_block" | grep -Fq 'await _captureRuntimeScreenshot(marker)'
if printf '%s\n' "$register_capture_block" | grep -Eq 'await tester\.pump|Future<void>\.delayed'; then
  echo "FAIL: Register runtime capture must remain direct after surface preparation" >&2
  exit 1
fi

password_reset_block="$(sed -n '/if (child is PasswordResetPage)/,/if (child is WalletPage)/p' "$runtime_driver")"
password_reset_capture_block="$(printf '%s\n' "$password_reset_block" | sed '/if (child is PasswordResetPage)/,/return;/p')"
printf '%s\n' "$password_reset_capture_block" | grep -Fq "HOPE_RUNTIME_PASSWORD_RESET_DIRECT_CAPTURE"
printf '%s\n' "$password_reset_capture_block" | grep -Fq 'await _captureRuntimeScreenshot(marker)'
if printf '%s\n' "$password_reset_capture_block" | grep -Eq 'await tester\.pump|Future<void>\.delayed'; then
  echo "FAIL: PasswordReset runtime capture must remain direct after surface preparation" >&2
  exit 1
fi
grep -Fq 'system-images/android-35/default/x86_64' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'hope-android-sdk-api35-cmake3.22.1-default' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'hope-android-avd-api35-default-pixel2' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'api-level: 35' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq -- '-gpu swiftshader -feature -Vulkan' ".github/workflows/hope-ui-runtime-evidence.yml"
if grep -Fq 'swiftshader_indirect' ".github/workflows/hope-ui-runtime-evidence.yml"; then
  echo "FAIL: deprecated swiftshader_indirect runtime renderer remains in the capture lane" >&2
  exit 1
fi
grep -Fq "contains(github.event.pull_request.title, '[runtime-capture-fa]')" ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'test "${png_count}" -ge 25' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq '"financial-insights-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"job-satisfaction-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"candidate-matches-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"chat-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'CAPTURED_BASELINE_SCREENS=19' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq "'candidate-matches': () => EmployerCandidateMatchesPage(" "$runtime_driver"
grep -Fq "'chat': () => ChatPage(" "$runtime_driver"
grep -Fq "'job-satisfaction': () => const JobSatisfactionPage(" "$runtime_driver"
grep -Fq "'financial-insights': () => const FinancialInsightsPage()" "$runtime_driver"

# Wave 15: guard the actual screenshot defects before runtime capture.
grep -Fq "final scoreLabel = score == null ? '—' : " "$premium"
grep -Fq 'value * 100).round()' "$premium"
if grep -Fq '\${score}%' "$premium"; then
  echo "FAIL: raw match-score interpolation remains" >&2
  exit 1
fi
if grep -Fq '\${(value * 100).round()}%' "$premium"; then
  echo "FAIL: raw component-score interpolation remains" >&2
  exit 1
fi
grep -Fq 'compactHero: denseViewport' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'end: 10,' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'includeMatch: false' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'if (includeMatch)' "lib/core/ui/hope_signature_components.dart"
grep -Fq 'constraints.maxWidth < 420' "lib/core/ui/opportunity_card.dart"
test -f "test/core/ui/premium_visual_wave_15_test.dart"

# Wave 17: viewport fill, compact navigation labels and financial-value wrapping.
grep -Fq 'final compactLabels = width < 340 || textScale > 1.2;' "$premium"
grep -Fq 'showLabel: true,' "$premium"
grep -Fq 'blurRadius: dark ? 20 : 16' "$premium"
grep -Fq 'minHeight: availableHeight,' "$premium"
grep -Fq 'constraints: const BoxConstraints(maxWidth: 82)' "$premium"
grep -Fq 'maxLines: 2,' "lib/features/wallet/wallet_page.dart"
grep -Fq 'softWrap: true' "lib/features/wallet/wallet_page.dart"
grep -Fq 'maxLines: 2,' "lib/features/transactions/transactions_page.dart"
grep -Fq 'final compactViewport =' "$opportunity"
grep -Fq 'maxLines: compactViewport ? 3 : 2' "$opportunity"
grep -Fq 'String _budgetRangeLabel(BuildContext context, HopeJob job)' "lib/features/marketplace/job_detail_page.dart"
grep -Fq '_budgetRangeLabel(context, j)' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'wave17-filled-scroll-viewport' 'test/core/ui/premium_visual_wave_15_test.dart'

# Wave 18: responsive screenshots represent a real 360x640dp viewport, and short
# page bodies do not waste the first fold on the fixed navigation-safe tail.
grep -Fq 'adb shell wm density 320' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'adb shell wm density reset' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'responsive-density.txt' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'responsive_logical_viewport": "360x640dp' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'final compactBottomPadding = size.height < 560' "$premium"
grep -Fq "premium-page-frame-content-padding" "$premium"
grep -Fq 'wave18-compact-scroll-viewport' 'test/core/ui/premium_visual_wave_15_test.dart'
grep -Fq 'framePadding.padding.resolve(TextDirection.rtl).bottom, 16' 'test/core/ui/premium_visual_wave_15_test.dart'
grep -Fq 'EdgeInsets.fromLTRB(0, 0, 0, 56)' 'lib/features/jobs/jobs_widgets.part.dart'
grep -Fq 'tightViewport ? 24 : 32' 'lib/features/wallet/wallet_page.dart'
grep -Fq 'compactViewport ? 24 : 32' 'lib/features/marketplace/job_detail_page.dart'

# Wave 19: the financial range uses the full card width and must not be ellipsized.
grep -Fq "opportunity-card-budget-amount" "$opportunity"
grep -Fq 'maxLines: 3,' "$opportunity"
grep -Fq 'overflow: TextOverflow.clip' "$opportunity"
grep -Fq "budgetText.data, contains('۲٬۵۰۰٬۰۰۰ تومان')" 'test/core/ui/premium_visual_wave_15_test.dart'
grep -Fq 'didExceedMaxLines' 'test/core/ui/premium_visual_wave_15_test.dart'

# Wave 21: locale-safe date output, compact hero layering, visible filters,
# compact financial metrics, and truthful exact-source evidence metadata.
grep -Fq 'gy -= gy <= 1600 ? 621 : 1600;' "lib/core/ui/hope_display_formatters.dart"
grep -Fq "icon: compactHero ? null : icon" "$premium"
grep -Fq 'find.descendant(' 'test/core/ui/premium_visual_wave_15_test.dart'
grep -Fq '۱۴۰۵ شهریور ۱۰' 'test/core/ui/hope_display_formatters_test.dart'
grep -Fq 'در ۱۲ ساعت' 'test/core/ui/hope_display_formatters_test.dart'
grep -Fq 'Wrap(' "lib/features/offers/offers_page.dart"
grep -Fq 'final metricWidth = (constraints.maxWidth - gap) / 2;' "lib/features/financial/financial_insights_page.dart"
grep -Fq 'maxLines: 2,' "lib/features/financial/financial_insights_page.dart"
grep -Fq 'height: compactViewport ? 132 : denseViewport ? 166 : 214,' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'HOPE_RUNTIME_EXACT_HEAD=$exact_head' ".github/workflows/hope-ui-runtime-evidence.yml"
if sed -n '/class HopeWalletFlowSignature/,/Target-aligned opportunity DNA signature/p' "lib/core/ui/hope_signature_components.dart" | grep -Eq 'wallet\.(totalBalance|availableBalance|lockedBalance)'; then
  echo "FAIL: wallet ledger lifecycle panel must not repeat balance values" >&2
  exit 1
fi
grep -Fq '"sha": "${HOPE_RUNTIME_EXACT_HEAD:-$GITHUB_SHA}"' "tools/hope-wallet-runtime-evidence.sh"

# Wave 22 compact-first-fold visual contracts.
grep -Fq "this.compact = false" "$premium"
grep -Fq "premium-hero-compact-fallback" "$premium"
grep -Fq "final itemWidth = compact" "$premium"
grep -Fq "ValueKey('wallet-history-filters')" "lib/features/wallet/wallet_page.dart"
grep -Fq "if (!compactViewport) ...[" "lib/features/marketplace/job_detail_page.dart"
grep -Fq "saved-search-create-cta" "lib/features/jobs/saved_searches_page.dart"
grep -Fq "Wave 22 compact wallet exposes the history heading and every filter above navigation" "test/features/wallet/wave22_compact_wallet_test.dart"
grep -Fq "Saved Search create action stays beside page content" "test/features/jobs/saved_searches_page_test.dart"
grep -Fq "HOPE Superwave — one consolidated Flutter regression gate" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "test/features/wallet/wave22_compact_wallet_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "test/features/jobs/saved_searches_page_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"

# HOPE Design System 2.0 superwave: concrete visual and form contracts.
grep -Fq "ValueKey('home-pulse-panel')" "lib/features/home/premium_home_feed.dart"
grep -Fq "final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;" "lib/features/home/premium_home_feed.dart"
grep -Fq "final columns = enlargedText" "lib/features/home/premium_home_feed.dart"
grep -Fq "opportunity-match-score-ring" "$premium"
grep -Fq "wallet-balance-metric-locked-total" "lib/features/wallet/wallet_page.dart"
grep -Fq "_money(wallet.lockedBalance)" "lib/features/wallet/wallet_page.dart"
grep -Fq "for (var i = 0; i < en.length; i++)" "lib/features/transactions/transaction_widgets.part.dart"
grep -Fq "initiallyExpanded: !compact" "lib/features/marketplace/create_job_widgets.part.dart"
grep -Fq "candidate-comparison-matrix" "lib/features/marketplace/employer_candidate_matches_page.dart"
grep -Fq "bool? _completedAsAgreed;" "lib/features/jobs/job_satisfaction_page.dart"
grep -Fq "emptySelectionAllowed: true" "lib/features/jobs/job_satisfaction_page.dart"
grep -Fq "test/features/jobs/job_satisfaction_page_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "test/features/marketplace/employer_candidate_matches_page_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "Wave 23 vertical transaction timeline" "test/features/transactions/transaction_page_test.dart"
# Wave 24 compact flow, discovery controls, chart labels and accessibility gates.
grep -Fq 'radius: MediaQuery.sizeOf(context).width < 500 ? 24 : 32' lib/features/profile/profile_page.dart
grep -Fq "contains(github.event.pull_request.title, '[flutter-preverified]')" .github/workflows/hope-ui-wave-1-static.yml
grep -Fq "contains(github.event.pull_request.title, '[flutter-preverified]')" .github/workflows/hope-ui-runtime-evidence.yml
grep -Fq 'static const scrollEndGap = 12.0;' lib/core/theme/hope_v2_design.dart
grep -Fq 'height: HopeV2Navigation.barHeight,' lib/core/ui/premium_components.dart
grep -Fq 'wallet-history-entry-${item.id}' lib/features/wallet/wallet_page.dart
grep -Fq 'profile-language-selector' lib/features/profile/profile_page.dart
grep -Fq 'work-center-lifecycle-${job.id}' lib/features/transactions/transactions_page.dart
grep -Fq 'hope-explore-kind-filters' lib/features/jobs/jobs_filter_bar.part.dart
grep -Fq 'financial-cashflow-legend' lib/features/financial/financial_insights_page.dart
grep -Fq 'Wave 25 first-fold profile language selector stays fully above the dock' test/features/profile/wave24_compact_dock_test.dart
grep -Fq 'Wave 24 collaboration lifecycle clears the dock' test/features/transactions/transactions_page_test.dart
grep -Fq 'Wave 24 compact Explore kind filter' test/features/marketplace/jobs_page_test.dart
grep -Fq 'Wave 24 financial chart legend' test/features/financial/financial_insights_page_test.dart
grep -Fq 'Wave 24 primary dock satisfies Android target sizing' test/core/ui/premium_navigation_test.dart
grep -Fq 'test/features/financial/financial_insights_page_test.dart' .github/workflows/hope-ui-wave-1-static.yml
if grep -Fq '[wave23-preverified]' .github/workflows/hope-ui-wave-1-static.yml; then
  echo 'FAIL: static workflow still carries the Wave23 skip marker' >&2
  exit 1
fi
# Wave 26 navigation labels and selected-state glyphs remain explicit.
grep -Fq 'showLabel: true,' "$premium"
grep -Fq 'blurRadius: dark ? 20 : 16' "$premium"
grep -Fq 'HopeV2Icons.homeSelected, selected: true' "$premium"
grep -Fq 'HopeV2Icons.walletSelected, selected: true' "$premium"
grep -Fq 'HopeV2Icons.profileSelected, selected: true' "$premium"
grep -Fq "Wave 29 keeps every navigation label visible at 320x640dp" "test/core/ui/premium_navigation_test.dart"

# Wave 26 adaptive Explore density must use the purpose-built compact grid tile.
grep -Fq 'final textScale = MediaQuery.textScalerOf(context).scale(1);' "$jobs_widgets"
grep -Fq 'constraints.maxWidth >= 340' "$jobs_widgets"
grep -Fq 'enum OpportunityCardVariant { compact, compactGrid, standard, featured, featuredScan, expanded }' "$opportunity"
grep -Fq 'Widget _compactGrid(' "$opportunity"
grep -Fq 'String _formatCompactGridAmount(' "$opportunity"
grep -Fq '_formatCompactGridAmount(amount, context)' "$opportunity"
grep -Fq 'variant: columns == 2' "$jobs_widgets"
grep -Fq 'variant: textScale > 1.2' "$jobs_widgets"
grep -Fq 'childAspectRatio: columns == 3 ? 1.04 : 0.86' "$jobs_widgets"
grep -Fq 'final columns = textScale > 1.2' "$jobs_widgets"
grep -Fq "Wave 26 Explore falls back to a single column at enlarged text scale" "test/features/marketplace/jobs_page_test.dart"
grep -Fq 'minimumSize: WidgetStatePropertyAll(' "lib/features/jobs/jobs_filter_bar.part.dart"
grep -Fq 'Size(0, enlargedText ? 56 : 48)' "lib/features/jobs/jobs_filter_bar.part.dart"
grid_money_block="$(sed -n '/Widget _compactGrid(/,/Widget _compact(/p' "$opportunity")"
printf '%s\n' "$grid_money_block" | grep -Fq "ValueKey('opportunity-card-compact-grid-budget')"
printf '%s\n' "$grid_money_block" | grep -Fq 'maxLines: 3,'
printf '%s\n' "$grid_money_block" | grep -Fq 'overflow: TextOverflow.clip,'
compact_money_block="$(sed -n '/Widget _compact(/,/Widget _standard(/p' "$opportunity")"
printf '%s\n' "$compact_money_block" | grep -Fq "ValueKey('opportunity-card-compact-budget')"
printf '%s\n' "$compact_money_block" | grep -Fq 'overflow: TextOverflow.clip,'

echo "PASS: Wave 23 superwave + Wave 22 compact-first-fold source contracts"
echo "PASS: Wave 21 shared visual + locale + evidence integrity contracts"
echo "PASS: premium visual composition wave source integrity"
echo "PASS: Register + PasswordReset runtime capture uses direct screenshot after surface preparation"
# [runtime-capture-fa] full FA/RTL + responsive editorial media certification after Home-only proof.
# [runtime-capture] full EN/LTR editorial media certification after FA/RTL proof.

# Wave 27 mega-superwave: dock-safe scroll tails across the real product surfaces.
grep -Fq 'static EdgeInsets scrollEndPadding(' "$theme"
grep -Fq 'final bottomInset = MediaQuery.paddingOf(context).bottom;' "$theme"
grep -Fq 'bottomInset + scrollEndGap' "$theme"
for page in \
  lib/features/wallet/wallet_page.dart \
  lib/features/transactions/transactions_page.dart \
  lib/features/profile/profile_page.dart \
  lib/features/marketplace/job_detail_page.dart \
  lib/features/marketplace/employer_candidate_matches_page.dart \
  lib/features/applications/my_applications_page.dart \
  lib/features/jobs/saved_searches_page.dart \
  lib/features/jobs/jobs_page.dart \
  lib/features/home/premium_home_feed.dart \
  lib/features/notifications/notifications_page.dart \
  lib/features/notifications/notification_devices_page.dart \
  lib/features/offers/offers_page.dart \
  lib/features/transactions/transaction_widgets.part.dart \
  lib/features/marketplace/create_job_widgets.part.dart \
  lib/features/jobs/job_satisfaction_page.dart \
  lib/features/auth/login_page.dart \
  lib/features/auth/register_page.dart \
  lib/features/auth/password_reset_page.dart; do
  test -f "$page"
  grep -Fq 'HopeV2Navigation.scrollEndPadding' "$page"
done
# Finance charts preserve real data while allowing readable category/date labels.
grep -Fq "financial-cashflow-chart-scroll" lib/features/financial/financial_insights_page.dart
grep -Fq "financial-balance-chart-scroll" lib/features/financial/financial_insights_page.dart
grep -Fq 'math.max(constraints.maxWidth, data.length * 42.0)' lib/features/financial/financial_insights_page.dart
grep -Fq 'math.max(constraints.maxWidth, points.length * 52.0)' lib/features/financial/financial_insights_page.dart
grep -Fq "find.byKey(const ValueKey('financial-cashflow-chart-scroll'))" test/features/financial/financial_insights_page_test.dart
grep -Fq "find.byKey(const ValueKey('financial-balance-chart-scroll'))" test/features/financial/financial_insights_page_test.dart
grep -Fq 'constraints.maxWidth >= 1080 ? 3' lib/features/home/premium_home_feed.dart
grep -Fq "isNot(contains(r'\\n'))" test/core/ui/premium_visual_wave_15_test.dart
grep -Fq 'HopeV2Icons.message,' lib/features/chat/chat_page.dart
grep -Fq 'initiallyExpanded: !compact' lib/features/marketplace/create_job_widgets.part.dart
grep -Fq 'onPressed: _busy || !_feedbackComplete ? null : _submit' lib/features/jobs/job_satisfaction_page.dart
grep -Fq 'Wave 27 scroll tail includes unconsumed system bottom inset' test/core/ui/premium_navigation_test.dart
echo "PASS: Wave 27 cross-surface scroll safety + readable finance chart contracts"

# Wave 28 chat-first composition and compact-input contracts.
grep -Fq "ValueKey('chat-conversation-header')" "lib/features/chat/chat_page.dart"
grep -Fq "ValueKey('chat-message-list')" "lib/features/chat/chat_page.dart"
grep -Fq "ValueKey('chat-composer-panel')" "lib/features/chat/chat_page.dart"
grep -Fq "ValueKey('chat-message-input')" "lib/features/chat/chat_page.dart"
grep -Fq "final shortViewport = MediaQuery.sizeOf(context).height < 800;" "lib/features/financial/financial_insights_page.dart"
grep -Fq "painter.paint(canvas, Offset(x, 0));" "lib/features/financial/financial_insights_page.dart"
grep -Fq "final plotTop = labelHeight + 3;" "lib/features/financial/financial_insights_page.dart"
grep -Fq "shortViewport ? 106.0 : compact ? 148.0 : 172.0" "lib/features/financial/financial_insights_page.dart"
grep -Fq "Icons.mail_outline_rounded, size: 18, key: ValueKey('auth-email-field-icon')" "lib/features/auth/login_page.dart"
grep -Fq "Icons.person_add_alt_1_rounded, size: 18, key: ValueKey('auth-name-field-icon')" "lib/features/auth/register_page.dart"
grep -Fq "auth-password-field-icon" "lib/features/auth/login_page.dart"
grep -Fq "auth-password-field-icon" "lib/features/auth/register_page.dart"
grep -Fq "Explain the series before rendering their plot." "test/features/financial/financial_insights_page_test.dart"
grep -Fq "last Work Center item stays reachable above the fixed dock" "test/features/transactions/transactions_page_test.dart"

# Wave 29: ledger pagination sits before payouts; compact rows and real list tails remain guarded.
wallet_page="lib/features/wallet/wallet_page.dart"
grep -Fq "ValueKey('wallet-transactions-load-more')" "$wallet_page"
grep -Fq "ValueKey('wallet-history-title')" "$wallet_page"
grep -Fq "ValueKey('wallet-withdrawals-title')" "$wallet_page"
load_more_line="$(grep -nF "ValueKey('wallet-transactions-load-more')" "$wallet_page" | head -n 1 | cut -d: -f1)"
withdrawals_line="$(grep -nF "ValueKey('wallet-withdrawals-title')" "$wallet_page" | head -n 1 | cut -d: -f1)"
test "$load_more_line" -lt "$withdrawals_line"
grep -Fq "size: compact ? 34 : 38" "$wallet_page"
grep -Fq "Loading transactions…" "$wallet_page"
grep -Fq "Wave 29 load-more is adjacent to transaction history" "test/features/wallet/wave22_compact_wallet_test.dart"
grep -Fq "List.generate(12, _transaction)" "test/features/wallet/wave22_compact_wallet_test.dart"
grep -Fq "Wave 29 last Work Center item stays reachable" "test/features/transactions/transactions_page_test.dart"
grep -Fq "Wave 29 keeps every navigation label visible at 320x640dp" "test/core/ui/premium_navigation_test.dart"
grep -Fq "Wave 29 final Explore opportunity stays reachable" "test/features/marketplace/jobs_page_test.dart"
echo "PASS: Wave 29 wallet pagination ordering + compact transaction density + 320x640 cross-surface reachability"

# Wave 30: enlarged system text gets readable finance/discovery layouts and exact en-LTR evidence.
grep -Fq "final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;" "lib/features/home/premium_home_feed.dart"
grep -Fq "final columns = enlargedText" "lib/features/home/premium_home_feed.dart"
grep -Fq "Wave30 Home Pulse reflows into two readable rows at 1.5x text scale" "test/features/home/premium_home_feed_test.dart"
grep -Fq "final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;" "lib/core/ui/hope_signature_components.dart"
grep -Fq "if (enlargedText)" "lib/core/ui/hope_signature_components.dart"
grep -Fq "compact: MediaQuery.textScalerOf(context).scale(1) <= 1.2" "lib/features/transactions/transactions_page.dart"
grep -Fq "Wave30 English Work Center expands lifecycle rows at 1.5x" "test/features/transactions/transactions_page_test.dart"
grep -Fq "Wave30 Explore renders English LTR single-column cards with 1.5x system text" "test/features/marketplace/jobs_page_test.dart"
grep -Fq "Wave30 Wallet money-flow signature expands for English LTR at 1.5x text scale" "test/features/wallet/wave22_compact_wallet_test.dart"
grep -Fq "HOPE_CAPTURE_TEXT_SCALE" "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"text_scale": $CAPTURE_TEXT_SCALE' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq "TextScaler.linear(_captureTextScale)" "integration_test/runtime/critical_screens_evidence_test.dart"
grep -Fq "[runtime-capture-en-scale]" ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq "jq -e --arg sha" ".github/workflows/hope-ui-runtime-evidence.yml"
echo "PASS: Wave 30 enlarged-text, cross-surface adaptive layout, and exact-head en-LTR evidence contracts"

# Wave30: preserve readable Home Pulse header/metric reflow and wallet/dock LTR large-text layouts.
grep -Fq "if (enlargedText)" "lib/features/home/premium_home_feed.dart"
grep -Fq "ValueKey('home-pulse-stat-grid')" "lib/features/home/premium_home_feed.dart"
grep -Fq "if (textScale <= 1) return child!;" "test/features/home/premium_home_feed_test.dart"
grep -Fq "home pulse adapts its metric rows to the actual responsive rail width" "test/features/home/premium_home_feed_test.dart"
grep -Fq "final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;" "lib/features/wallet/wallet_page.dart"
grep -Fq "height: HopeV2Navigation.barHeight + (textScale > 1.2 ? 12 : 0)" "lib/core/ui/premium_components.dart"
grep -Fq "Wave30 English navigation dock expands vertically at 1.5x" "test/core/ui/premium_navigation_test.dart"
echo "PASS: Wave30 responsive Home rail, enlarged Wallet status and navigation dock fit contracts"
