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
grep -Fq "final mediaSize = compactViewport ? 70.0 : 88.0;" "$opportunity"
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
grep -Fq 'variant: OpportunityCardVariant.compact' "$jobs_widgets"
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
grep -Fq 'final compactLabels = width < 340;' "$premium"
grep -Fq 'showLabel: !compactLabels || index == selectedIndex' "$premium"
grep -Fq 'minHeight: availableHeight,' "$premium"
grep -Fq 'constraints: const BoxConstraints(maxWidth: 82)' "$premium"
grep -Fq 'maxLines: 2,' "lib/features/wallet/wallet_page.dart"
grep -Fq 'softWrap: true' "lib/features/wallet/wallet_page.dart"
grep -Fq 'maxLines: 2,' "lib/features/transactions/transactions_page.dart"
grep -Fq 'final compactViewport =' "$opportunity"
grep -Fq 'maxLines: compactViewport ? 2 : 1' "$opportunity"
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
grep -Fq 'expect(framePadding.padding.bottom, 40);' 'test/core/ui/premium_visual_wave_15_test.dart'

echo "PASS: premium visual composition wave source integrity"
echo "PASS: Register + PasswordReset runtime capture uses direct screenshot after surface preparation"
# [runtime-capture-fa] full FA/RTL + responsive editorial media certification after Home-only proof.
# [runtime-capture] full EN/LTR editorial media certification after FA/RTL proof.
