#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="${2:-test_driver/hope_runtime_screenshot_driver.dart}"
test_file="${3:-integration_test/runtime/critical_screens_evidence_test.dart}"

grep -Eq '^[[:space:]]*flutter drive --no-pub' "$script"
grep -Fq -- '--no-dds' "$script"
grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep -Fq -- 'export HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root"' "$script"
grep -Fq -- 'export HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
grep -Fq -- 'verify_runtime_screenshots()' "$script"
grep -Fq -- 'onScreenshot:' "$driver"
grep -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
grep -Fq -- 'capture_transport": "flutter_driver_onScreenshot_host_callback_post_test"' "$script"

if grep -Eq 'capture_screen\(\)|collect_runtime_screenshot\(\)|collect_runtime_screenshots\(' "$script"; then
  echo "FAIL: runtime evidence must not pull screenshots through live/app-private ADB transport" >&2
  exit 1
fi

if grep -Eq 'adb exec-out run-as com\.hope\.marketplace cat' "$script"; then
  echo "FAIL: runtime evidence must not depend on ADB screenshot file reads" >&2
  exit 1
fi

if grep -Fq -- 'screenshots.clear()' "$test_file"; then
  echo "FAIL: screenshot reportData must remain available for post-test driver callback" >&2
  exit 1
fi

baseline_wait_line="$(grep -nF 'wait "$test_pid"' "$script" | cut -d: -f1 | sed -n '1p')"
baseline_verify_line="$(grep -nF 'verify_runtime_screenshots "${screens[@]}"' "$script" | cut -d: -f1 | sed -n '1p')"
responsive_wait_line="$(grep -nF 'wait "$responsive_test_pid"' "$script" | cut -d: -f1 | sed -n '1p')"
responsive_verify_line="$(grep -nF 'verify_runtime_screenshots "${responsive_screens[@]}"' "$script" | cut -d: -f1 | sed -n '1p')"

if [ -z "$baseline_wait_line" ] || [ -z "$baseline_verify_line" ] || [ "$baseline_wait_line" -ge "$baseline_verify_line" ]; then
  echo "FAIL: baseline screenshots must be verified after flutter drive completion" >&2
  exit 1
fi

if [ -z "$responsive_wait_line" ] || [ -z "$responsive_verify_line" ] || [ "$responsive_wait_line" -ge "$responsive_verify_line" ]; then
  echo "FAIL: responsive screenshots must be verified after flutter drive completion" >&2
  exit 1
fi

if grep -Eq '(^|[[:space:]])flutter[[:space:]]+test[[:space:]]+--no-pub' "$script"; then
  echo "FAIL: runtime evidence must use flutter drive, not flutter test" >&2
  exit 1
fi

echo "PASS: runtime driver contract"
