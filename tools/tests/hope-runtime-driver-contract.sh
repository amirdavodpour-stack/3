#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"

grep -Eq '^[[:space:]]*flutter drive --no-pub' "$script"
grep -Fq -- '--no-dds' "$script"
grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep -Fq -- 'export HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"

if grep -Eq '(^|[[:space:]])flutter[[:space:]]+test[[:space:]]+--no-pub' "$script"; then
  echo "FAIL: runtime evidence must use flutter drive, not flutter test" >&2
  exit 1
fi

echo "PASS: runtime evidence driver contract"
