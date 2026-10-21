#!/usr/bin/env sh
# [runtime-capture-fa] exact-head discovery density validation.
# Grouped visual-wave source guard for the consolidated editorial hierarchy + quiet-surface redesign.
# Full-page evidence stays on category-specific fallback art; real media remains opt-in.
# Final verification capture after adding the scoped fixture contract.
# The restored #1560 baseline does not require a runtime media fixture; editorial media activation remains a separate visual wave.
set -eu
trap 'status=$?; echo "FAIL: source guard line ${LINENO}: ${BASH_COMMAND}" >&2; exit "$status"' ERR

opportunity="lib/core/ui/opportunity_card.dart"
premium="lib/core/ui/premium_components.dart"
theme="lib/core/theme/hope_v2_design.dart"
home="lib/features/home/premium_home_feed.dart"
jobs_widgets="lib/features/jobs/jobs_widgets.part.dart"
admin_operations="lib/features/admin/admin_operations_page.dart"
notification_devices="lib/features/notifications/notification_devices_page.dart"
admin_page="lib/features/admin/admin_page.dart"
android_theme="android/app/src/main/res/values/styles.xml"
android_theme_v26="android/app/src/main/res/values-v26/styles.xml"
runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"

test -f "$opportunity"
test -f "$premium"
test -f "$home"
test -f "$runtime_driver"

workflow=".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq 'timeout-minutes: 25' "$workflow"
grep -Fq 'name: Prepare Android compile SDK components' "$workflow"
grep -Fq 'platforms;android-36' "$workflow"
grep -Fq 'build-tools;36.0.0' "$workflow"
grep -Fq 'ndk;28.2.13676358' "$workflow"
grep -Fq 'name: Compile Android debug APK (Kotlin/Gradle)' "$workflow"
grep -Fq 'flutter build apk --debug --no-pub' "$workflow"
grep -Fq 'test -s build/app/outputs/flutter-apk/app-debug.apk' "$workflow"

sh test/runtime/editorial_media_fixture_source_test.sh
sh test/runtime/editorial_media_fixture_scope_test.sh

grep -Fq 'String? mediaUrl' "$opportunity"
grep -Fq '_fallbackMedia(context, primary)' "$opportunity"
grep -Fq "final media = ClipRRect(" "$opportunity"
grep -Fq "final mediaSize = compactViewport ? 56.0 : 88.0;" "$opportunity"
grep -Fq "height: 72" "$opportunity"
# Narrow standard cards use a 56px thumbnail; compact-grid media stays 72px.

grep -Fq 'class _HeroEditorialFallback extends StatelessWidget' "$premium"
grep -Fq 'static const darkBorder = Color(0x1FFFFFFF);' "$theme"
grep -Fq 'static const darkBorderStrong = Color(0x2BFFFFFF);' "$theme"
grep -Fq 'static const darkDivider = Color(0x18FFFFFF);' "$theme"
grep -Fq 'static const barHeight = 68.0;' "$theme"
grep -Fq '_HeroEditorialFallback(' "$premium"

grep -Fq 'padding: const EdgeInsets.fromLTRB(14, 4, 14, 12)' "$home"
grep -Fq 'The home ListView already owns navigation-aware end padding; its outer frame should not reserve another dead band.' 'test/features/home/premium_home_feed_test.dart'
grep -Fq 'fontSize: compact ? 19.5 : 25.5' "$premium"
grep -Fq 'class PremiumEmptyState extends StatelessWidget' "$premium"
grep -Fq 'maxLines: 2,' "$opportunity"
grep -Fq 'softWrap: true' "$opportunity"
# Home discovery tiles should size to their content, not reserve square fixed-aspect cells.
grep -Fq 'return Wrap(' "$home"
grep -Fq 'variant: OpportunityCardVariant.compactGrid' "$home"
grep -Fq 'wide Home opportunity cards size to content instead of square grid cells' 'test/features/home/premium_home_feed_test.dart'
if grep -Fq 'childAspectRatio: columns == 3 ? 0.92 : 1.02' "$home"; then
  echo "FAIL: Home opportunity cards still reserve fixed-aspect grid cells" >&2
  exit 1
fi
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
printf '%s\n' "$register_capture_block" | grep -Fq "HOPE_RUNTIME_REGISTER_READY_CAPTURE"
printf '%s\n' "$register_capture_block" | grep -Fq 'await _waitForRuntimeRegisterGoogleCta(tester)'
printf '%s\n' "$register_capture_block" | grep -Fq "find.byKey(const ValueKey('auth-google-sign-in'))"
grep -Fq 'HOPE_RUNTIME_REGISTER_GOOGLE_CTA_VISIBLE:' "$runtime_driver"
grep -Fq 'await tester.ensureVisible(googleButton)' "$runtime_driver"
grep -Fq 'final visibleBounds = bounds.intersect(viewport);' "$runtime_driver"
grep -Fq 'visibleBounds.height + 0.5 < bounds.height' "$runtime_driver"
grep -Fq "register shows configured Google sign-in visibly within a compact viewport" "test/features/auth/auth_pages_test.dart"
printf '%s\n' "$register_capture_block" | grep -Fq 'await _captureRuntimeScreenshot(marker, tester: tester)'
if printf '%s\n' "$register_capture_block" | grep -Eq 'Future<void>\.delayed'; then
  echo "FAIL: Register capture must use the bounded readiness helper, not a timed settle" >&2
  exit 1
fi

password_reset_block="$(sed -n '/if (child is PasswordResetPage)/,/if (child is WalletPage)/p' "$runtime_driver")"
password_reset_capture_block="$(printf '%s\n' "$password_reset_block" | sed '/if (child is PasswordResetPage)/,/return;/p')"
printf '%s\n' "$password_reset_capture_block" | grep -Fq "HOPE_RUNTIME_PASSWORD_RESET_TARGET_ASSERTED"
printf '%s\n' "$password_reset_capture_block" | grep -Fq "expect(find.byType(PasswordResetPage), findsOneWidget"
printf '%s\n' "$password_reset_capture_block" | grep -Fq "expect(find.byType(RegisterPage), findsNothing"
printf '%s\n' "$password_reset_capture_block" | grep -Fq "expect(find.byType(TextField), findsOneWidget"
printf '%s\n' "$password_reset_capture_block" | grep -Fq "password-reset-\$localeMarker"
printf '%s\n' "$password_reset_capture_block" | grep -Fq "HOPE_RUNTIME_PASSWORD_RESET_DIRECT_CAPTURE"
printf '%s\n' "$password_reset_capture_block" | grep -Fq 'await _captureRuntimeScreenshot(marker, tester: tester)'
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
grep -Fq 'test "${png_count}" -ge 35' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'Build pinned Google TalkBack accessibility service' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq "HOPE_TALKBACK_REQUIRED: '1'" ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq '.talkback_service_bound == true' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq '"scroll_end_screens": $scroll_end_screens' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq "'transaction-detail', 'create-job'" "$runtime_driver"
grep -Fq '"transaction-detail-$scroll_suffix"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"create-job-$scroll_suffix"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"profile-$scroll_suffix"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '.scroll_end_screens == 10' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'HOPE_T10_TARGET_BOUNDS_PASS:' "$runtime_driver"
grep -Fq 'HOPE_T10_TARGET_BOUNDS_FAIL:' "$runtime_driver"
grep -Fq 'Rect _globalSemanticsNodeBounds(SemanticsNode node, RenderView renderView)' "$runtime_driver"
grep -Fq 'MatrixUtils.transformRect(transform, node.rect)' "$runtime_driver"
grep -Fq 'final targetBounds = _globalSemanticsNodeBounds(node, renderView);' "$runtime_driver"
grep -Fq 'talkback_target_bounds_screens' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'talkback_target_bounds_min_width_dp' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '.talkback_target_bounds_min_height_dp >= 48' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq '"financial-insights-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"job-satisfaction-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"candidate-matches-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq '"chat-fa-rtl"' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'CAPTURED_BASELINE_SCREENS="$(find "$evidence_dir" -maxdepth 1' "tools/hope-wallet-runtime-evidence.sh"
grep -Fq 'CAPTURED_RESPONSIVE_SCREENS="$(find "$evidence_dir" -maxdepth 1' "tools/hope-wallet-runtime-evidence.sh"
if grep -Fq 'CAPTURED_BASELINE_SCREENS=19' "tools/hope-wallet-runtime-evidence.sh" || grep -Fq 'CAPTURED_RESPONSIVE_SCREENS=6' "tools/hope-wallet-runtime-evidence.sh"; then
  echo "FAIL: artifact metadata must count actual screenshots, not hard-coded expected counts" >&2
  exit 1
fi
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
grep -Fq 'expandForAccessibilityText: true' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'final accessibilityTitleExpansion =' "$premium"
grep -Fq 'StackFit.loose' "$premium"
grep -Fq 'Job Detail hero expands to preserve long titles at 1.5x system text' "test/features/marketplace/job_detail_page_test.dart"
grep -Fq 'end: 10,' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'includeMatch: false' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'if (includeMatch)' "lib/core/ui/hope_signature_components.dart"
grep -Fq 'constraints.maxWidth < 420' "lib/core/ui/opportunity_card.dart"
test -f "test/core/ui/premium_visual_wave_15_test.dart"

# Wave 17: viewport fill, compact navigation labels and financial-value wrapping.
grep -Fq 'final compactLabels = width < 340 || textScale > 1.2;' "$premium"
grep -Fq 'showLabel: true,' "$premium"
# Editorial navigation is a continuous rail with one direction-aware moving folio plate.
grep -Fq 'AnimatedPositionedDirectional(' "$premium"
grep -Fq "hope-navigation-selection-plate" "$premium"
navigation_selection_block="$(sed -n '/hope-navigation-selection-plate/,+16p' "$premium")"
printf '%s\n' "$navigation_selection_block" | grep -Fq 'RoundedRectangleBorder('
printf '%s\n' "$navigation_selection_block" | grep -Fq 'borderRadius: BorderRadius.circular(10)'
grep -Fq 'HopeV2SemanticColors.navigationLabel(' "$premium"
grep -Fq 'fit: BoxFit.scaleDown' "$premium"
grep -Fq 'navigationLabelMutedDark = Color(0xFFBDBDC3)' "$theme"
grep -Fq '360dp fa-RTL dock fits Workshop and keeps navigation copy achromatic' "test/core/ui/premium_navigation_test.dart"
grep -Fq "paragraph.didExceedMaxLines" "test/core/ui/premium_navigation_test.dart"
grep -Fq 'minHeight: availableHeight,' "$premium"
grep -Fq 'maxLines: 2,' "lib/features/wallet/wallet_page.dart"
grep -Fq 'softWrap: true' "lib/features/wallet/wallet_page.dart"
grep -Fq 'maxLines: 2,' "lib/features/transactions/transactions_page.dart"
grep -Fq 'final compactViewport =' "$opportunity"
grep -Fq 'maxLines: enlargedText' "$opportunity"
grep -Fq ': (compactViewport ? 3 : 2)' "$opportunity"
grep -Fq 'overflow: enlargedText' "$opportunity"
grep -Fq 'String _budgetRangeLabel(BuildContext context, HopeJob job)' "lib/features/marketplace/job_detail_page.dart"
grep -Fq '_budgetRangeLabel(context, job)' "lib/features/marketplace/job_detail_page.dart"
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
grep -Fq 'horizontal: horizontalSkeleton' "$jobs_widgets"
grep -Fq 'final horizontalSkeleton =' "$jobs_widgets"
# Admin financial/operational metrics expand with their recorded values at large text scale.
grep -Fq 'final enlargedText = textScale > 1.2;' "$admin_operations"
grep -Fq 'final metricWidth =' "$admin_operations"
grep -Fq 'maxLines: enlargedText ? null : 2' "$admin_operations"
grep -Fq 'maxLines: null' "$admin_operations"
grep -Fq 'admin metric cards preserve long financial values at 1.5x text scale' 'test/features/admin/admin_operations_page_test.dart'
grep -Fq 'admin summary metric cards adapt height and retain labels at 1.5x text scale' 'test/features/admin/admin_page_test.dart'
grep -Fq 'final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;' "$admin_page"
grep -Fq 'final cardWidth =' "$admin_page"
grep -Fq 'child: summaryCard(item, compact: false)' "$admin_page"
if grep -Fq 'mainAxisExtent: columns == 1 ? 82 : 96' "$admin_operations"; then
  echo "FAIL: admin metric cards still reserve fixed-height cells for arbitrary values" >&2
  exit 1
fi

grep -Fq 'SliverLayoutBuilder(' "$jobs_widgets"
grep -Fq 'constraints.crossAxisExtent' "$jobs_widgets"
grep -Fq 'final bool horizontal;' 'lib/core/ui/components.dart'
grep -Fq 'if (horizontal)' 'lib/core/ui/components.dart'
grep -Fq 'EdgeInsets.fromLTRB(0, 0, 0, 56)' 'lib/features/jobs/jobs_widgets.part.dart'
grep -Fq '_walletInitialLoadingSkeleton(' 'lib/features/wallet/wallet_page.dart'
grep -Fq "ValueKey('wallet-loading-skeleton')" 'lib/features/wallet/wallet_page.dart'
grep -Fq "ValueKey('wallet-loading-balance-hero')" 'lib/features/wallet/wallet_page.dart'
grep -Fq "ValueKey('wallet-loading-actions')" 'lib/features/wallet/wallet_page.dart'
grep -Fq "wallet-loading-history-row-0" 'lib/features/wallet/wallet_page.dart'
grep -Fq "Wallet initial loading uses a finance-shaped skeleton instead of a generic status panel" 'test/features/wallet/wave22_compact_wallet_test.dart'
grep -Fq 'tightViewport ? 12 : 20' 'lib/features/wallet/wallet_page.dart'
grep -Fq 'The wallet ListView already owns navigation-aware end padding; its outer frame should stay compact.' 'test/features/wallet/wallet_page_test.dart'
grep -Fq 'compactViewport ? 12 : 20' 'lib/features/marketplace/job_detail_page.dart'
grep -Fq 'The opportunity detail ListView owns navigation-aware end padding; its outer frame should stay compact.' 'test/features/marketplace/job_detail_page_test.dart'

# Wave 19: scan amounts remain uncapped; featured amounts cap only at normal scale.
grep -Fq "opportunity-card-budget-amount" "$opportunity"
grep -Fq "budgetText.data, contains('۲٬۵۰۰٬۰۰۰ تومان')" 'test/core/ui/premium_visual_wave_15_test.dart'
grep -Fq 'didExceedMaxLines' 'test/core/ui/premium_visual_wave_15_test.dart'
featured_budget_block="$(sed -n '/Widget _featuredStandard(/,/Widget _standard(/p' "$opportunity")"
printf '%s\n' "$featured_budget_block" | grep -Fq "ValueKey('opportunity-card-standard-budget')"
printf '%s\n' "$featured_budget_block" | grep -Fq 'maxLines: enlargedText ? null : 3,'
printf '%s\n' "$featured_budget_block" | grep -Fq 'overflow: enlargedText'
printf '%s\n' "$featured_budget_block" | grep -Fq 'TextOverflow.visible'
printf '%s\n' "$featured_budget_block" | grep -Fq 'TextOverflow.clip'

# Wave 21: locale-safe date output, compact hero layering, visible filters,
# compact financial metrics, and truthful exact-source evidence metadata.
grep -Fq 'gy -= gy <= 1600 ? 621 : 1600;' "lib/core/ui/hope_display_formatters.dart"
grep -Fq "icon: compactHero ? null : icon" "$premium"
grep -Fq 'find.descendant(' 'test/core/ui/premium_visual_wave_15_test.dart'
grep -Fq '۱۰ شهریور ۱۴۰۵' 'test/core/ui/hope_display_formatters_test.dart'
grep -Fq 'در ۱۲ ساعت' 'test/core/ui/hope_display_formatters_test.dart'
grep -Fq 'offers-status-filter-scroll' "lib/features/offers/offers_page.dart" || grep -Fq 'Wrap(' "lib/features/offers/offers_page.dart"
# Wave 43: financial metric tiles adapt to actual width and accessibility text scale.
grep -Fq 'final columns = compact &&' "lib/features/financial/financial_insights_page.dart"
grep -Fq 'textScale <= 1.2' "lib/features/financial/financial_insights_page.dart"
grep -Fq '? 3' "lib/features/financial/financial_insights_page.dart"
grep -Fq ': 2;' "lib/features/financial/financial_insights_page.dart"
grep -Fq '(constraints.maxWidth - gap * (columns - 1)) / columns;' "lib/features/financial/financial_insights_page.dart"
grep -Fq 'maxLines: 2,' "lib/features/financial/financial_insights_page.dart"
grep -Fq 'height: compactViewport' "lib/features/marketplace/job_detail_page.dart"
grep -Fq ': denseViewport' "lib/features/marketplace/job_detail_page.dart"
grep -Fq '? (viewportWidth < 360 ? 96 : 184)' "lib/features/marketplace/job_detail_page.dart"
# Wave 42: enlarged text on narrow Job Detail uses a horizontal, accessible lifecycle rail.
grep -Fq 'if (enlargedText && constraints.maxWidth < 360)' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'scrollDirection: Axis.horizontal' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'Scroll horizontally to view all lifecycle stages.' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'Wave 42 final Job Detail section remains reachable above the fixed CTA at 1.5x text' "test/features/marketplace/job_detail_page_test.dart"
grep -Fq ': 214,' "lib/features/marketplace/job_detail_page.dart"
grep -Fq 'HOPE_RUNTIME_EXACT_HEAD=$exact_head' ".github/workflows/hope-ui-runtime-evidence.yml"
if sed -n '/class HopeWalletFlowSignature/,/Target-aligned opportunity DNA signature/p' "lib/core/ui/hope_signature_components.dart" | grep -Eq 'wallet\.(totalBalance|availableBalance|lockedBalance)'; then
  echo "FAIL: wallet ledger lifecycle panel must not repeat balance values" >&2
  exit 1
fi
grep -Fq '"sha": "${HOPE_RUNTIME_EXACT_HEAD:-$GITHUB_SHA}"' "tools/hope-wallet-runtime-evidence.sh"



# Compact-grid becomes text-first at enlarged system text to avoid fixed-tile clipping.
grep -Fq 'final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.15;' "$opportunity"
grep -Fq 'maxLines: enlargedText ? null : 5,' "$opportunity"
grep -Fq "opportunity-card-compact-grid-kind" "$opportunity"
# Batched discovery hierarchy: real recommendation signals only and readable compact scan cards.
grep -Fq 'if (featuredScan)' "$opportunity"
grep -Fq "opportunity-featured-scan-layout" "$opportunity"
grep -Fq "opportunity-card-compact-grid-category" "$opportunity"
grep -Fq "final recommendedIndex = jobs.indexWhere(" "$jobs_widgets"
grep -Fq "job.isRecommended && job.recommendationScore != null" "$jobs_widgets"
grep -Fq "Available opportunities" "$jobs_widgets"
grep -Fq "Explore does not fabricate a recommended opportunity without a real score" "test/features/marketplace/jobs_page_test.dart"
grep -Fq "Explore promotes a featured card only when a real recommendation score exists" "test/features/marketplace/jobs_page_test.dart"

# Wave 22 compact-first-fold visual contracts.
grep -Fq "this.compact = false" "$premium"
grep -Fq "premium-hero-compact-fallback" "$premium"
grep -Fq "final itemWidth = compact" "$premium"
grep -Fq "ValueKey('wallet-history-filters')" "lib/features/wallet/wallet_page.dart"
grep -Fq "final showDistinctWorkModeDna =" "lib/features/marketplace/job_detail_page.dart"
grep -Fq "remoteModeDuplicatesLocation" "lib/features/marketplace/job_detail_page.dart"
grep -Fq "SizedBox(height: compactViewport ? 6 : 8)" "lib/features/marketplace/job_detail_page.dart"
grep -Fq "compact Job Detail exposes the real work-mode DNA trait without duplicating decision facts" "test/features/marketplace/job_detail_page_test.dart"
grep -Fq "The decision strip already presents remote as the location." "test/features/marketplace/job_detail_page_test.dart"
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
grep -Fq "initiallyExpanded: true" "lib/features/marketplace/create_job_widgets.part.dart"
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
grep -Fq 'height: HopeV2Navigation.barHeight + (textScale > 1.2 ? 12 : 0)' lib/core/ui/premium_components.dart
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
# Editorial navigation labels, motion, and selected-state glyphs remain explicit.
grep -Fq 'showLabel: true,' "$premium"
grep -Fq 'reduceMotion ? Duration.zero' "$premium"
grep -Fq 'HopeV2NavigationIcons.homeSelected, selected: true' "$premium"
grep -Fq 'HopeV2NavigationIcons.walletSelected, selected: true' "$premium"
grep -Fq 'HopeV2NavigationIcons.profileSelected, selected: true' "$premium"
grep -Fq "Wave 29 keeps every navigation label visible at 320x640dp" "test/core/ui/premium_navigation_test.dart"

# Wave 26 adaptive Explore density must use the purpose-built compact grid tile.
grep -Fq 'final textScale = MediaQuery.textScalerOf(context).scale(1);' "$jobs_widgets"
grep -Fq 'constraints.maxWidth >= 420' "$jobs_widgets"
grep -Fq 'enum OpportunityCardVariant { compact, compactGrid, standard, featured, featuredScan, expanded }' "$opportunity"
grep -Fq 'Widget _compactGrid(' "$opportunity"
grep -Fq 'String _formatCompactGridAmount(' "$opportunity"
grep -Fq '_formatCompactGridAmount(amount, context)' "$opportunity"
grep -Fq 'variant: columns == 2' "$jobs_widgets"
grep -Fq 'variant: textScale > 1.2' "$jobs_widgets"
# Explore opportunity tiles are content-sized; grid width remains responsive.
grep -Fq 'return Wrap(' "$jobs_widgets"
grep -Fq 'variant: columns == 2' "$jobs_widgets"
grep -Fq 'OpportunityCardVariant.compactGrid' "$jobs_widgets"
# Device-management loading previews the actual compact row structure, not a lone spinner.
grep -Fq "label: _t('در حال بارگذاری دستگاه‌های اعلان', 'Loading notification devices')" "$notification_devices"
grep -Fq 'SkeletonBox(' "$notification_devices"
grep -Fq 'liveRegion: true' "$notification_devices"
if grep -Fq 'SizedBox(height: 72, child: Center(child: CircularProgressIndicator()))' "$notification_devices"; then
  echo "FAIL: notification-device loading regressed to a spinner-only placeholder" >&2
  exit 1
fi
grep -Fq 'wide Explore opportunity cards size to content instead of square grid cells' 'test/features/marketplace/jobs_page_test.dart'
if grep -Fq 'childAspectRatio: columns == 3 ? 1.04 : 0.86' "$jobs_widgets"; then
  echo "FAIL: Explore still reserves fixed-aspect opportunity grid cells" >&2
  exit 1
fi
grep -Fq 'final columns = textScale > 1.2' "$jobs_widgets"
grep -Fq "Wave 26 Explore falls back to a single column at enlarged text scale" "test/features/marketplace/jobs_page_test.dart"
grep -Fq 'minimumSize: WidgetStatePropertyAll(' "lib/features/jobs/jobs_filter_bar.part.dart"
grep -Fq 'Size(0, enlargedText ? 56 : 48)' "lib/features/jobs/jobs_filter_bar.part.dart"
grid_money_block="$(sed -n '/Widget _compactGrid(/,/Widget _compact(/p' "$opportunity")"
printf '%s\n' "$grid_money_block" | grep -Fq "ValueKey('opportunity-card-compact-grid-budget')"
printf '%s\n' "$grid_money_block" | grep -Fq 'maxLines: enlargedText ? null : 5,'
printf '%s\n' "$grid_money_block" | grep -Fq 'overflow: enlargedText ? TextOverflow.visible : TextOverflow.clip,'
compact_layout_block="$(sed -n '/Widget _compact(/,/Widget _featuredStandard(/p' "$opportunity")"
printf '%s\n' "$compact_layout_block" | grep -Fq "ValueKey('opportunity-card-compact-budget')"
compact_budget_text_block="$(printf '%s\n' "$compact_layout_block" | sed -n '/_formatCompactRangeAmount(amount, context)/,/style: TextStyle/p')"
printf '%s\n' "$compact_budget_text_block" | grep -Fq '_formatCompactRangeAmount(amount, context)'
printf '%s\n' "$compact_budget_text_block" | grep -Fq 'softWrap: true'
if printf '%s\n' "$compact_budget_text_block" | grep -Eq 'maxLines:|TextOverflow\.clip'; then
  echo "FAIL: compact financial amount can be line-capped or clipped" >&2
  exit 1
fi

echo "PASS: Wave 23 superwave + Wave 22 compact-first-fold source contracts"
echo "PASS: Wave 21 shared visual + locale + evidence integrity contracts"
echo "PASS: premium visual composition wave source integrity"
echo "PASS: Register captures configured Google CTA after bounded readiness; PasswordReset remains direct"
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
grep -Fq 'final monthWidth = math.max(58.0, 58.0 * textScale);' lib/features/financial/financial_insights_page.dart
grep -Fq 'final pointWidth = math.max(64.0, 64.0 * textScale);' lib/features/financial/financial_insights_page.dart
grep -Fq "find.byKey(const ValueKey('financial-cashflow-chart-scroll'))" test/features/financial/financial_insights_page_test.dart
grep -Fq "financial-balance-chart-scroll" test/features/financial/financial_insights_page_test.dart
grep -Fq 'constraints.maxWidth >= 1080 ? 3' lib/features/home/premium_home_feed.dart
grep -Fq "isNot(contains(r'\\n'))" test/core/ui/premium_visual_wave_15_test.dart
grep -Fq 'HopeV2Icons.message,' lib/features/chat/chat_page.dart
grep -Fq 'initiallyExpanded: true' lib/features/marketplace/create_job_widgets.part.dart
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
grep -Fq "shortViewport ? 122.0 : compact ? 156.0 : 172.0" "lib/features/financial/financial_insights_page.dart"
grep -Fq "HopeV2Icons.mail, size: 18, key: ValueKey('auth-email-field-icon')" "lib/features/auth/login_page.dart"
grep -Fq "HopeV2Icons.userAdd, size: 18, key: ValueKey('auth-name-field-icon')" "lib/features/auth/register_page.dart"
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
grep -Fq "maxLines: enlargedText ? null : (compact ? 1 : 2)" "lib/core/ui/hope_signature_components.dart"
grep -Fq "expect(flowHeading.maxLines, isNull)" "test/features/wallet/wave22_compact_wallet_test.dart"
grep -Fq "expect(flowExplanation.maxLines, isNull)" "test/features/wallet/wave22_compact_wallet_test.dart"
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

# Wave30 narrow-rail correction: only use four metrics columns when cells are wide enough to align labels.
grep -Fq "constraints.maxWidth >= 800" "lib/features/home/premium_home_feed.dart"
grep -Fq "statGridWidth >= 800 ? 70.0 : 140.0" "test/features/home/premium_home_feed_test.dart"
grep -Fq "if (gridWidth >= 800)" "test/features/home/premium_home_feed_test.dart"
echo "PASS: Wave30 narrow Home Pulse columns stay aligned at responsive widths"

# Wave30 screenshot-led correction: profile language label stacks at enlarged English LTR scale.
grep -Fq 'MediaQuery.textScalerOf(context).scale(1) <= 1.2' "lib/features/profile/profile_page.dart"
grep -Fq 'Wave30 Profile language selector uses a readable stacked layout at 1.5x English LTR' "test/features/profile/wave30_profile_language_scale_test.dart"

# Wave30: the Profile 1.5x regression must execute inside the consolidated Flutter gate.
grep -Fq "test/features/profile/wave30_profile_language_scale_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"

# Wave44: Create Opportunity keeps stage context and primary actions outside the scrolling form.
grep -Fq "ValueKey('create-opportunity-action-dock')" "lib/features/marketplace/create_job_widgets.part.dart"
grep -Fq "child: HopeCreationProgress(activeIndex: activeStep)" "lib/features/marketplace/create_job_widgets.part.dart"
grep -Fq "Wave 44 progress and action dock remain fixed while the active step scrolls" "test/features/marketplace/create_job_page_test.dart"
echo "PASS: Wave44 Create Opportunity sticky progress/action dock and responsive form contracts"

# Wave45: wallet and transaction detail keep full TOMAN amounts visible on compact/enlarged layouts.
grep -Fq "final singleColumnMetrics = enlargedText ||" "lib/features/wallet/wallet_page.dart"
grep -Fq "Wave 45 Wallet preserves full long TOMAN totals and available balance values" "test/features/wallet/wave22_compact_wallet_test.dart"
grep -Fq "final compactLayout = constraints.maxWidth < 380 ||" "lib/features/transactions/transaction_page.dart"
grep -Fq "Wave 45 transaction summary preserves full TOMAN amount and fee values at 1.5x" "test/features/transactions/transaction_page_test.dart"
echo "PASS: Wave45 exact monetary value readability on Wallet and Transaction Detail"

# Wave45 follow-up: long total balance avoids the compact mid-width two-column split;
# transaction identity/status reflows when enlarged text is active.
grep -Fq "final longTotalBalance = totalBalanceValue.length > 18;" "lib/features/wallet/wallet_page.dart"
grep -Fq "if (width < 340 ||" "lib/features/wallet/wallet_page.dart"
grep -Fq "(_isEnglish && width < 400) ||" "lib/features/wallet/wallet_page.dart"
grep -Fq "longTotalBalance)" "lib/features/wallet/wallet_page.dart"
grep -Fq "final enlargedText =" "lib/features/transactions/transaction_widgets.part.dart"
grep -Fq "children: [statusTag, refreshButton]" "lib/features/transactions/transaction_widgets.part.dart"
echo "PASS: Wave45 follow-up for long total balances and enlarged transaction headings"

# Wave46: loading, empty and initial error remain distinct across Offers, Notifications and Applications.
grep -Fq "if (!_loading && (_loadError == null || _items.isNotEmpty))" "lib/features/offers/offers_page.dart"
grep -Fq "rows.isEmpty &&" "lib/features/offers/offers_page.dart"
grep -Fq "'Notification status could not be refreshed'" "lib/features/notifications/notifications_page.dart"
grep -Fq "if (!_loading && (_loadError == null || _items.isNotEmpty))" "lib/features/applications/my_applications_page.dart"
grep -Fq "Wave46 offers loading and empty states remain mutually exclusive" "test/features/offers/offers_page_test.dart"
grep -Fq "find.byKey(const ValueKey('applications-status-filter-scroll'))" "test/features/applications/my_applications_page_test.dart"
echo "PASS: Wave46 async-state truth across Offers, Notifications and Applications"

# Wave46 test contract: Applications filter rail exists only for a successful result or retained stale rows.
grep -Fq "ValueKey('applications-status-filter-scroll')" "lib/features/applications/my_applications_page.dart"
grep -Fq "find.byKey(const ValueKey('applications-status-filter-scroll'))" "test/features/applications/my_applications_page_test.dart"
echo "PASS: Wave46 Applications filter rail tracks authoritative data state"

# Wave47: Chat empty-state/composer, Profile no-fabricated trust metrics, and auth retry after API failure.
grep -Fq "Wave47 successful empty chat keeps the composer available" "test/features/chat/chat_page_test.dart"
grep -Fq "find.text('تأییدشده'), findsNothing" "test/features/profile/profile_page_test.dart"
grep -Fq "Wave47 login failure preserves credentials and re-enables the submit action" "test/features/auth/auth_pages_test.dart"
grep -Fq "Wave47 registration failure preserves fields and re-enables the submit action" "test/features/auth/auth_pages_test.dart"
grep -Fq "test/features/chat/chat_page_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "test/features/profile/profile_page_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "test/features/auth/auth_pages_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
echo "PASS: Wave47 Chat/Profile/Auth recovery and state-truth contracts"

# Wave48: actual Wallet + Work Center viewport/locale matrix; keep the executable guard mode.
grep -Fq "final wide = constraints.maxWidth >= 720;" "lib/features/wallet/wallet_page.dart"
grep -Fq "Wave48 Wallet adapts hero/action composition across FA-RTL and EN-LTR viewports" "test/features/wallet/wave22_compact_wallet_test.dart"
grep -Fq "Wave48 Work Center preserves lifecycle reachability across widths and locales" "test/features/transactions/transactions_page_test.dart"
grep -Fq "test/features/wallet/wave22_compact_wallet_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "test/features/transactions/transactions_page_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "item.width < HopeV2Breakpoints.medium" "test/features/transactions/transactions_page_test.dart"
echo "PASS: Wave48 Wallet and Work Center responsive/locale matrix contracts"

# Wave52: expanded opportunity reason panel must not leak unknown backend enums.
grep -Fq "String? _reason(BuildContext context, String value)" "lib/core/ui/opportunity_card.dart"
expanded_helper_line=$(grep -nF "Widget _expandedStandard(" "lib/core/ui/opportunity_card.dart" | head -n1 | cut -d: -f1)
reason_labels_line=$(grep -nF "final reasonLabels = reasons" "lib/core/ui/opportunity_card.dart" | head -n1 | cut -d: -f1)
test -n "$expanded_helper_line" && test -n "$reason_labels_line" && test "$reason_labels_line" -gt "$expanded_helper_line"
grep -Fq "if (reasonLabels.isNotEmpty) ...[" "lib/core/ui/opportunity_card.dart"
grep -Fq "expanded opportunity omits unknown match reason values" "test/core/ui/opportunity_card_test.dart"
grep -Fq "test/core/ui/opportunity_card_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
echo "PASS: Wave52 expanded OpportunityCard reason hygiene"

# Wave51: include the full Wallet page suite in the consolidated gate so later tests are not skipped after a different widget assertion fails.
grep -Fq 'test/features/wallet/wallet_page_test.dart' ".github/workflows/hope-ui-wave-1-static.yml"
grep -Fq "pending withdrawal summary agrees with the reserved payout row" "test/features/wallet/wallet_page_test.dart"
grep -Fq "wallet withdraw action label uses a readable semantic foreground" "test/features/wallet/wallet_page_test.dart"
grep -Fq "wallet initial error state keeps recovery near the first fold" "test/features/wallet/wallet_page_test.dart"
grep -Fq "wallet uses a compact finance header on narrow surfaces" "test/features/wallet/wallet_page_test.dart"
grep -Fq "wallet action labels do not truncate at 1.5x on a compact viewport" "test/features/wallet/wallet_page_test.dart"
grep -Fq "wallet history cards avoid duplicate reference text and expose date to assistive tech" "test/features/wallet/wallet_page_test.dart"
grep -Fq "wallet history rows stay compact when the visible facts fit on two lines" "test/features/wallet/wallet_page_test.dart"
echo "PASS: Wave51 consolidated full Wallet page regression coverage"

# Wave49: adaptive Offers, Notifications and Chat rows across locale/viewport combinations.
grep -Fq "final compactHeading =" "lib/features/offers/offers_page.dart"
grep -Fq 'offer-status-${o.id}' "lib/features/offers/offers_page.dart"
grep -Fq "Wave49 Offers card title and status fit FA-RTL/EN-LTR responsive matrix" "test/features/offers/offers_page_test.dart"
grep -Fq "offer status rail keeps every filter fully reachable in RTL/LTR and enlarged text" "test/features/offers/offers_page_test.dart"
grep -Fq "padding: const EdgeInsetsDirectional.symmetric(horizontal: 16)" "lib/features/offers/offers_page.dart"
grep -Fq "final compactText =" "lib/features/notifications/notifications_page.dart"
grep -Fq 'notification-title-${n.id}' "lib/features/notifications/notifications_page.dart"
grep -Fq "Wave49 Notifications preserve title/body at narrow FA-RTL and EN-LTR 1.5x" "test/features/notifications/notifications_page_test.dart"
grep -Fq "final compactBanner =" "lib/features/chat/chat_page.dart"
grep -Fq "chat-send-error-retry" "lib/features/chat/chat_page.dart"
grep -Fq "Wave49 Chat send failure keeps full error and Retry reachable at 1.5x in both directions" "test/features/chat/chat_page_test.dart"
echo "PASS: Wave49 adaptive heading and recovery content across locale/viewport matrix"

# Wave53: OpportunityCard 2.0 category identity, quiet list surfaces, and one RTL-aware action cue.
grep -Fq 'class HopeV2OpportunityAccents' "lib/core/theme/hope_v2_design.dart"
grep -Fq 'static const software = Color(0xFF557D75);' "lib/core/theme/hope_v2_design.dart"
grep -Fq 'static const sales = Color(0xFF6B895D);' "lib/core/theme/hope_v2_design.dart"
grep -Fq 'final cardAccent = _categoryArtwork(primary).accent;' "$opportunity"
grep -Fq "ValueKey('opportunity-card-surface')" "$opportunity"
grep -Fq "ValueKey('opportunity-card-accent-rail')" "$opportunity"
grep -Fq 'boxShadow: featured || featuredScan' "$opportunity"
grep -Fq 'Widget _actionAffordance(BuildContext context)' "$opportunity"
grep -Fq "ValueKey('opportunity-card-action-affordance')" "$opportunity"
grep -Fq "opportunity cards carry a category-specific accent rail in light and dark themes" "test/core/ui/opportunity_card_test.dart"
grep -Fq "opportunity card action cue stays compact and follows RTL/LTR across shared layouts" "test/core/ui/opportunity_card_test.dart"
grep -Fq "repeated opportunity cards stay quiet while featured cards own surface depth" "test/core/ui/opportunity_card_test.dart"
grep -Fq "opportunity artwork accents stay unique and separate from semantic states" "test/core/theme/hope_v2_design_test.dart"
grep -Fq "test/core/theme/hope_v2_design_test.dart" ".github/workflows/hope-ui-wave-1-static.yml"
echo "PASS: Wave53 OpportunityCard 2.0 category identity + surface hierarchy + RTL action cue"


# Candidate Matches is an audited runtime target, not a semantics-only exception.
grep -Fq 'final shouldRevealCandidateMatchesTarget =' "$runtime_driver"
grep -Fq "candidate-match-details-candidate-user-1" "$runtime_driver"
grep -Fq 'shouldRevealCandidateMatchesTarget' "$runtime_driver"
if grep -Fq "final requiresTapAction = marker != 'candidate-matches-fa-rtl';" "$runtime_driver"; then
  echo "FAIL: Candidate Matches is still exempt from actionable-target assertions" >&2
  exit 1
fi
