#!/usr/bin/env sh
# [runtime-capture-fa] editorial media fixture must be scoped to discovery surfaces.
set -eu

driver="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$driver"

grep -Fq 'HopeJob _jobFixture({bool editorialMedia = false})' "$driver"
grep -Fq "if (editorialMedia) 'imageUrl':" "$driver"
grep -Fq "_jobFixture(editorialMedia: true)," "$driver"
grep -Fq "JobDetailPage(job: _jobFixture(editorialMedia: true))" "$driver"
grep -Fq "HopeJob get _job => _jobFixture();" "$driver"

echo "PASS: editorial media fixture is explicitly scoped"
