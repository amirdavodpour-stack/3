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
grep -Fq -- 'capture_screen()' "$script"
grep -Fq -- 'HOPE_HOST_SCREENSHOT_CAPTURED:' "$script"
grep -Fq -- 'capture_transport": "flutter_callbackManager_app_private_file_live_host"' "$script"
grep -Fq -- 'binding.callbackManager.takeScreenshot(marker)' "$test_file"
grep -Fq -- 'await integrationDriver(responseDataCallback: null);' "$driver"

if grep -Fq -- 'binding.takeScreenshot(marker)' "$test_file"; then
  echo "FAIL: runtime capture must bypass reportData accumulation" >&2
  exit 1
fi

if grep -Fq -- 'screenshots.clear()' "$test_file"; then
  echo "FAIL: obsolete screenshot reportData mutation remains" >&2
  exit 1
fi

if grep -Eq 'verify_runtime_screenshot\(\)|verify_runtime_screenshots\(' "$script"; then
  echo "FAIL: runtime evidence must capture screenshots while flutter drive is running" >&2
  exit 1
fi

if grep -Fq -- 'HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT' "$driver" || grep -Fq -- 'HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT' "$script"; then
  echo "FAIL: runtime evidence must not use post-test host callback transport" >&2
  exit 1
fi

baseline_capture_line="$(grep -nF 'capture_screen "HOPE_SCREENSHOT_READY:$marker"' "$script" | cut -d: -f1 | sed -n '1p')"
baseline_wait_line="$(grep -nF 'wait "$test_pid"' "$script" | cut -d: -f1 | sed -n '1p')"
responsive_capture_line="$(grep -nF 'capture_screen "HOPE_SCREENSHOT_READY:$marker"' "$script" | cut -d: -f1 | sed -n '2p')"
responsive_wait_line="$(grep -nF 'wait "$responsive_test_pid"' "$script" | cut -d: -f1 | sed -n '1p')"


if [ -z "$baseline_capture_line" ] || [ -z "$baseline_wait_line" ] || [ "$baseline_capture_line" -ge "$baseline_wait_line" ]; then
  echo "FAIL: baseline live screenshot collection must occur before flutter drive wait" >&2
  exit 1
fi

if [ -z "$responsive_capture_line" ] || [ -z "$responsive_wait_line" ] || [ "$responsive_capture_line" -ge "$responsive_wait_line" ]; then
  echo "FAIL: responsive live screenshot collection must occur before flutter drive wait" >&2
  exit 1
fi

if grep -Eq '(^|[[:space:]])flutter[[:space:]]+test[[:space:]]+--no-pub' "$script"; then
  echo "FAIL: runtime evidence must use flutter drive, not flutter test" >&2
  exit 1
fi

echo "PASS: runtime driver contract"
