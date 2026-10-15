#!/usr/bin/env sh
# [runtime-capture-fa] deterministic editorial media fixture contract.
set -eu

runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$runtime_driver"

grep -Fq "'imageUrl':" "$runtime_driver"
grep -Fq 'images.unsplash.com/photo-1758876022836-70b89d3e6944' "$runtime_driver"

echo "PASS: runtime editorial media fixture source integrity"
