#!/usr/bin/env sh
# Full-page evidence uses category fallback art; opt-in editorial media is not injected into captured screens.
set -eu

runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$runtime_driver"

grep -Fq 'HopeJob _jobFixture({bool editorialMedia = false})' "$runtime_driver"
grep -Fq "if (editorialMedia)" "$runtime_driver"
if grep -Fq "_jobFixture(editorialMedia: true)" "$runtime_driver"; then
  echo "FAIL: stock editorial media must not be injected into any full-page evidence screen" >&2
  exit 1
fi
grep -Fq "JobDetailPage(job: _jobFixture())" "$runtime_driver"
grep -Fq "HopeJob get _job => _jobFixture();" "$runtime_driver"
if grep -Fq "HOPE Runtime" "$runtime_driver" || grep -Fq "runtime@example.invalid" "$runtime_driver"; then
  echo "FAIL: artificial runtime identity must not appear in evidence fixtures" >&2
  exit 1
fi

echo "PASS: captured screens use category fallback art and non-artificial identities"
