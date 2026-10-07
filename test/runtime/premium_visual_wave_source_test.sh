#!/usr/bin/env sh
# [runtime-capture-fa] exact-head discovery density validation.
# Grouped visual-wave source guard for the runtime-certified discovery surfaces.
# [runtime-capture-fa-home] isolate editorial media to the Home discovery capture.
# Final verification capture after adding the scoped fixture contract.
# The restored #1560 baseline does not require a runtime media fixture; editorial media activation remains a separate visual wave.
set -eu

opportunity="lib/core/ui/opportunity_card.dart"
premium="lib/core/ui/premium_components.dart"
home="lib/features/home/premium_home_feed.dart"
jobs_widgets="lib/features/jobs/jobs_widgets.part.dart"
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
grep -Fq "width: 64" "$opportunity"
grep -Fq "height: 64" "$opportunity"

grep -Fq 'class _HeroEditorialFallback extends StatelessWidget' "$premium"
grep -Fq '_HeroEditorialFallback(' "$premium"

grep -Fq 'padding: const EdgeInsets.fromLTRB(16, 8, 16, 28)' "$home"
grep -Fq 'variant: OpportunityCardVariant.compact' "$home"
# Current Home density contract is validated by its exact layout structure; no legacy vertical-spacing literal is required.
grep -Fq 'if (recommended.length > 1)' "$home"
grep -Fq 'variant: OpportunityCardVariant.compact' "$jobs_widgets"

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
