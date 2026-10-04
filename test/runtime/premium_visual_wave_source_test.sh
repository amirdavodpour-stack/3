#!/usr/bin/env sh
# Grouped visual-wave source guard for the runtime-certified discovery surfaces.
set -eu

opportunity="lib/core/ui/opportunity_card.dart"
premium="lib/core/ui/premium_components.dart"
home="lib/features/home/premium_home_feed.dart"

test -f "$opportunity"
test -f "$premium"
test -f "$home"

grep -Fq 'String? mediaUrl' "$opportunity"
grep -Fq '_fallbackMedia(context, primary)' "$opportunity"
grep -Fq "final media = ClipRRect(" "$opportunity"
grep -Fq "width: 54" "$opportunity"
grep -Fq "height: 54" "$opportunity"

grep -Fq 'class _HeroEditorialFallback extends StatelessWidget' "$premium"
grep -Fq '_HeroEditorialFallback(' "$premium"

grep -Fq 'padding: const EdgeInsets.fromLTRB(16, 8, 16, 28)' "$home"
grep -Fq 'variant: OpportunityCardVariant.compact' "$home"
grep -Fq 'vertical: 7' "$home"

echo "PASS: premium visual composition wave source integrity"
