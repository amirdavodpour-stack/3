#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="${2:-test_driver/hope_runtime_screenshot_driver.dart}"

grep -Eq '^[[:space:]]*flutter drive --no-pub' "$script"
grep -Fq -- '--no-dds' "$script"
grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep -Fq -- 'export HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root"' "$script"
grep -Fq -- 'collect_runtime_screenshots()' "$script"
grep -Fq -- 'adb exec-out run-as com.hope.marketplace cat "$remote_path"' "$script"
grep -Fq -- 'onScreenshot:' "$driver"
grep -Fq -- 'capture_transport": "flutter_driver_takeScreenshot_app_private_file_post_test"' "$script"

if grep -Eq 'capture_screen\(\)' "$script"; then
  echo "FAIL: runtime evidence must not poll app-private screenshots while flutter drive is still running" >&2
  exit 1
fi

if grep -Fq -- 'HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT' "$driver" || grep -Fq -- 'HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT' "$script"; then
  echo "FAIL: runtime evidence must not use a post-hoc host callback output root" >&2
  exit 1
fi

baseline_wait_line="$(grep -nF 'wait "$test_pid"' "$script" | cut -d: -f1 | sed -n '1p')"
baseline_collect_line="$(grep -nF 'collect_runtime_screenshots "${screens[@]}"' "$script" | cut -d: -f1 | sed -n '1p')"
responsive_wait_line="$(grep -nF 'wait "$responsive_test_pid"' "$script" | cut -d: -f1 | sed -n '1p')"
responsive_collect_line="$(grep -nF 'collect_runtime_screenshots "${responsive_screens[@]}"' "$script" | cut -d: -f1 | sed -n '1p')"

if [ -z "$baseline_wait_line" ] || [ -z "$baseline_collect_line" ] || [ "$baseline_wait_line" -ge "$baseline_collect_line" ]; then
  echo "FAIL: baseline screenshots must be collected only after flutter drive exits" >&2
  exit 1
fi

if [ -z "$responsive_wait_line" ] || [ -z "$responsive_collect_line" ] || [ "$responsive_wait_line" -ge "$responsive_collect_line" ]; then
  echo "FAIL: responsive screenshots must be collected only after flutter drive exits" >&2
  exit 1
fi

if grep -Eq '(^|[[:space:]])flutter[[:space:]]+test[[:space:]]+--no-pub' "$script"; then
  echo "FAIL: runtime evidence must use flutter drive, not flutter test" >&2
  exit 1
fi

echo "PASS: runtime driver contract"
