#!/usr/bin/env sh
# [runtime-capture-fa] Wave 1: runtime fixtures intentionally use deterministic product fallback media.
set -eu

runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$runtime_driver"

if grep -Fq 'images.unsplash.com' "$runtime_driver"; then
  echo "FAIL: editorial stock media must not appear in runtime fixtures" >&2
  exit 1
fi
if grep -Fq "HOPE Runtime" "$runtime_driver" || grep -Fq "runtime@example.invalid" "$runtime_driver"; then
  echo "FAIL: legacy demo identity must not appear in runtime fixtures" >&2
  exit 1
fi

# The fixture must still provide a complete job object for all evidence screens.
grep -Fq "HopeJob _jobFixture()" "$runtime_driver"
grep -Fq "'title': 'طراحی رابط موبایل حرفه‌ای'" "$runtime_driver"
grep -Fq "'category': 'طراحی'" "$runtime_driver"

echo "PASS: runtime fixture is deterministic, non-stock, and non-demo"
