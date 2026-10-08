#!/usr/bin/env sh
# [runtime-capture-fa] exact-head discovery density validation.
# Grouped visual-wave source guard for the aggregated editorial hierarchy + scan-card redesign.
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
grep -Fq "width: 72" "$opportunity"
grep -Fq "height: 72" "$opportunity"

grep -Fq 'class _HeroEditorialFallback extends StatelessWidget' "$premium"
grep -Fq 'static const darkBorder = Color(0x1FFFFFFF);' "$theme"
grep -Fq 'static const darkBorderStrong = Color(0x2BFFFFFF);' "$theme"
grep -Fq 'static const darkDivider = Color(0x18FFFFFF);' "$theme"
grep -Fq '_HeroEditorialFallback(' "$premium"

grep -Fq 'padding: const EdgeInsets.fromLTRB(16, 6, 16, 24)' "$home"
grep -Fq 'fontSize: compact ? 23 : 28' "$premium"
grep -Fq 'fontSize: 10.5' "$premium"
grep -Fq 'alpha: Theme.of(context).brightness == Brightness.dark ? .078 : .085' "$premium"
grep -Fq 'HopeV2Surfaces.border(context).withValues(alpha: .18)' "$premium"
grep -Fq 'HopeV2Surfaces.controlBorder(context).withValues(alpha: .42)' "lib/core/ui/components.dart"
grep -Fq 'variant: OpportunityCardVariant.compact' "$home"
# Current Home density contract is validated by its exact layout structure; no legacy vertical-spacing literal is required.
grep -Fq 'if (recommended.length > 1)' "$home"
grep -Fq 'variant: OpportunityCardVariant.compact' "$jobs_widgets"
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
grep -Fq '-gpu swiftshader -feature -Vulkan' ".github/workflows/hope-ui-runtime-evidence.yml"
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
echo "PASS: premium visual composition wave source integrity"
echo "PASS: Register + PasswordReset runtime capture uses direct screenshot after surface preparation"
# [runtime-capture-fa] full FA/RTL + responsive editorial media certification after Home-only proof.
# [runtime-capture] full EN/LTR editorial media certification after FA/RTL proof.
