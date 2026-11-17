#!/usr/bin/env sh
# Wave 1 fixture safety: runtime evidence must not use stock/demo identity.
set -eu
runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$runtime_driver"

if grep -Fq 'images.unsplash.com' "$runtime_driver"; then
  echo "FAIL: stock Unsplash media must not leak into runtime fixtures" >&2
  exit 1
fi
if grep -Fq "HOPE Runtime" "$runtime_driver" || grep -Fq "runtime@example.invalid" "$runtime_driver"; then
  echo "FAIL: legacy runtime demo identity must not leak into UI fixtures" >&2
  exit 1
fi

echo "PASS: runtime fixtures use non-stock media and non-demo identity"
