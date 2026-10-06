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
grep -Fq "width: 62" "$opportunity"
grep -Fq "height: 62" "$opportunity"

grep -Fq 'class _HeroEditorialFallback extends StatelessWidget' "$premium"
grep -Fq '_HeroEditorialFallback(' "$premium"

grep -Fq 'padding: const EdgeInsets.fromLTRB(16, 8, 16, 28)' "$home"
grep -Fq 'variant: OpportunityCardVariant.compact' "$home"
grep -Fq 'vertical: 6' "$home"
grep -Fq 'if (recommended.length > 1)' "$home"
grep -Fq 'variant: OpportunityCardVariant.compact' "$jobs_widgets"

register_block="$(sed -n '/if (child is RegisterPage)/,/if (child is PasswordResetPage)/p' "$runtime_driver")"
register_post_settle="$(printf '%s\n' "$register_block" | sed -n '/HOPE_RUNTIME_REGISTER_FAST_SETTLE_DONE/,$p')"
register_capture_tail="$(printf '%s\n' "$register_post_settle" | sed '/await _captureRuntimeScreenshot(marker)/q')"
printf '%s\n' "$register_post_settle" | grep -Fq 'await _captureRuntimeScreenshot(marker)'
if printf '%s\n' "$register_capture_tail" | grep -Eq 'await tester\.pump|Future<void>\.delayed'; then
  echo "FAIL: Register runtime capture performs an extra pump/delay after bounded settle" >&2
  exit 1
fi

password_reset_block="$(sed -n '/if (child is PasswordResetPage)/,/if (child is WalletPage)/p' "$runtime_driver")"
password_reset_post_settle="$(printf '%s\n' "$password_reset_block" | sed -n '/HOPE_RUNTIME_PASSWORD_RESET_FAST_SETTLE_DONE/,$p')"
password_reset_capture_tail="$(printf '%s\n' "$password_reset_post_settle" | sed '/await _captureRuntimeScreenshot(marker)/q')"
printf '%s\n' "$password_reset_post_settle" | grep -Fq 'await _captureRuntimeScreenshot(marker)'
if printf '%s\n' "$password_reset_capture_tail" | grep -Eq 'await tester\.pump|Future<void>\.delayed'; then
  echo "FAIL: PasswordReset runtime capture performs an extra pump/delay after bounded settle" >&2
  exit 1
fi
grep -Fq 'system-images/android-35/default/x86_64' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'hope-android-sdk-api35-cmake3.22.1-default' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'hope-android-avd-api35-default-pixel2' ".github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'api-level: 35' ".github/workflows/hope-ui-runtime-evidence.yml"
echo "PASS: premium visual composition wave source integrity"
echo "PASS: Register + PasswordReset runtime capture uses direct screenshot after bounded settle"
# [runtime-capture-fa] full FA/RTL + responsive editorial media certification after Home-only proof.
# [runtime-capture] full EN/LTR editorial media certification after FA/RTL proof.
