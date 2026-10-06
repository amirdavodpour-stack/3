#!/usr/bin/env sh
# [runtime-capture-fa] exact-head discovery density validation.
# [runtime-capture-fa] fix POSIX-shell guard quoting for notification card key.
# [runtime-capture-fa] certify Wave IV offers + notifications hierarchy after #1856 screenshot audit.
# [runtime-capture-fa] certify finance density wave after #1851 artifact review.
# [runtime-capture-fa] exact-head guard corrected for multiline wallet metric border invariant.
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
grep -Fq "width: 70" "$opportunity"
grep -Fq "height: 70" "$opportunity"

grep -Fq 'class _HeroEditorialFallback extends StatelessWidget' "$premium"
grep -Fq '_HeroEditorialFallback(' "$premium"

grep -Fq 'padding: const EdgeInsets.fromLTRB(16, 8, 16, 28)' "$home"
grep -Fq 'variant: OpportunityCardVariant.compact' "$home"
grep -Fq 'vertical: 4' "$home"
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

# Wave III finance-density guard: compact work-center metrics and lighter wallet secondary metrics.
transactions="lib/features/transactions/transactions_page.dart"
wallet="lib/features/wallet/wallet_page.dart"
test -f "$transactions"
test -f "$wallet"
grep -Fq 'Widget _workCenterMetric(' "$transactions"
if grep -Fq 'PremiumStatCard(' "$transactions"; then
  echo "FAIL: Work & finance center still uses heavyweight stat cards in the runtime-certified surface" >&2
  exit 1
fi
grep -Fq 'final metricWidth = (constraints.maxWidth - 16) / 3;' "$transactions"
grep -Fq 'fontSize: emphasized ? 14 : 11.5' "$wallet"
grep -Fq 'border: emphasized' "$wallet"
grep -Fq 'HopeV2Colors.primary.withValues(alpha: .30)' "$wallet"
# Wave IV: Offers and Notifications must use calmer, more legible secondary-surface hierarchy.
offers="lib/features/offers/offers_page.dart"
notifications="lib/features/notifications/notifications_page.dart"
test -f "$offers"
test -f "$notifications"
grep -Fq 'Widget _offerMetric(' "$offers"
grep -Fq "label: _t('در انتظار', 'Pending')" "$offers"
grep -Fq "label: _t('پذیرفته‌شده', 'Accepted')" "$offers"
grep -Fq 'constraints: const BoxConstraints(minHeight: 76)' "$offers"
grep -Fq 'required Object icon,' "$offers"
grep -Fq 'HopeIcon(icon, size: 15' "$offers"
grep -Fq "notification-card-" "$notifications"
grep -Fq 'padding: const EdgeInsets.all(15)' "$notifications"
echo "PASS: premium visual composition wave source integrity"
echo "PASS: Register + PasswordReset runtime capture uses direct screenshot after surface preparation"
# [runtime-capture-fa] full FA/RTL + responsive editorial media certification after Home-only proof.
# [runtime-capture] full EN/LTR editorial media certification after FA/RTL proof.
# [runtime-capture-fa] certify current HEAD after Offers icon type-contract fix.


# Signature surface wave: visual primitives for creation and internal finance.
signature="lib/core/ui/hope_signature_components.dart"
test -f "$signature"
grep -Fq 'class HopeOpportunityLivePreview' "$signature"
grep -Fq 'class HopeWalletFlowSignature' "$signature"
grep -Fq "HopeOpportunityLivePreview(" "lib/features/marketplace/create_job_widgets.part.dart"
grep -Fq "HopeWalletFlowSignature(wallet: wallet)" "lib/features/wallet/wallet_page.dart"
grep -Fq "color: primary.withValues(alpha: .14)" "lib/features/marketplace/job_detail_page.dart"
grep -Fq "border: Border.all(color: primary.withValues(alpha: .12))" "$opportunity"
echo "PASS: signature surface visual wave source integrity"
