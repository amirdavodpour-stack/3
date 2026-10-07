#!/usr/bin/env sh
# Wave 1: runtime evidence must not depend on a stock-media/editorial fixture.
set -eu

runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$runtime_driver"

if grep -Fq 'HopeJob _jobFixture({bool editorialMedia = false})' "$runtime_driver"; then
  echo "FAIL: obsolete editorialMedia fixture flag remains" >&2
  exit 1
fi
if grep -Fq "if (editorialMedia)" "$runtime_driver"; then
  echo "FAIL: obsolete editorialMedia branch remains" >&2
  exit 1
fi
if grep -Fq "images.unsplash.com" "$runtime_driver"; then
  echo "FAIL: stock media must not be embedded in runtime evidence fixtures" >&2
  exit 1
fi

echo "PASS: runtime evidence fixture is deterministic and stock-media free"
