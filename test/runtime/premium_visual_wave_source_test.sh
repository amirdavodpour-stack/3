#!/usr/bin/env sh
# [runtime-capture-fa] exact-head discovery density validation.
# Grouped visual-wave source guard for the runtime-certified discovery surfaces.
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
printf '%s
' "$register_block" |
  awk '
    /HOPE_RUNTIME_REGISTER_FAST_SETTLE_DONE/ { seen=1; next }
    seen && /await _captureRuntimeScreenshot(marker)/ { found=1; exit }
    seen && /await tester.pump(/ { bad=1; exit }
    seen && /Future<void>.delayed/ { bad=1; exit }
    END { if (!found || bad) exit 1 }
  '

echo "PASS: premium visual composition wave source integrity"
echo "PASS: Register runtime capture uses direct screenshot after bounded settle"
