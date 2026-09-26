#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="${2:-test_driver/hope_runtime_screenshot_driver.dart}"
test_file="${3:-integration_test/runtime/critical_screens_evidence_test.dart}"

grep -Fq -- 'flutter drive' "$script"
grep -Fq -- '--no-dds' "$script"
grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep -Fq -- 'env HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" flutter drive' "$script"
grep -Fq -- 'validate_capture_set()' "$script"
grep -Fq -- 'capture_transport": "flutter_driver_onScreenshot_host_callback"' "$script"
grep -Fq -- 'onScreenshot:' "$driver"
grep -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
grep -Fq -- 'binding.takeScreenshot(marker)' "$test_file"

if grep -Fq -- 'binding.callbackManager.takeScreenshot(marker)' "$test_file"; then
  echo "FAIL: runtime screenshot must use integration_test reportData for driver callback" >&2
  exit 1
fi

if grep -Fq -- 'screenshots.clear()' "$test_file"; then
  echo "FAIL: screenshot reportData must remain available for driver callback" >&2
  exit 1
fi

if grep -Eq 'capture_screen\(\)|verify_runtime_screenshot\(\)|collect_runtime_screenshot\(' "$script"; then
  echo "FAIL: screenshot capture must be handled by flutter_driver onScreenshot, not ADB live polling" >&2
  exit 1
fi

if grep -Eq 'flutter drive.*&$' "$script"; then
  echo "FAIL: flutter drive must run foreground" >&2
  exit 1
fi

echo "PASS: runtime driver foreground contract"
