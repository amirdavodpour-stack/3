#!/usr/bin/env sh
# [runtime-capture-fa] editorial media fixture must be scoped to discovery surfaces.
set -eu

runtime_driver="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$runtime_driver"

grep -Fq 'HopeJob _jobFixture({bool editorialMedia = false})' "$runtime_driver"
grep -Fq "if (editorialMedia)" "$runtime_driver"
grep -Fq "_jobFixture(editorialMedia: true)," "$runtime_driver"
grep -Fq "JobDetailPage(job: _jobFixture(editorialMedia: true))" "$runtime_driver"
grep -Fq "HopeJob get _job => _jobFixture();" "$runtime_driver"

echo "PASS: editorial media fixture is explicitly scoped"
