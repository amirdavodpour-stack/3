#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="${2:-test_driver/hope_runtime_screenshot_driver.dart}"

grep -Eq '^[[:space:]]*flutter drive --no-pub' "$script"
grep -Fq -- '--no-dds' "$script"
grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep -Fq -- 'export HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root"' "$script"
grep -Fq -- 'export HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
grep -Fq -- 'HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT' "$driver"
grep -Fq -- 'onScreenshot:' "$driver"
grep -Fq -- 'flutter_driver_onScreenshot_host_callback' "$script"

if grep -Eq 'adb exec-out run-as com\.hope\.marketplace cat .*hope-screen-captures-' "$script"; then
  echo "FAIL: host screenshot evidence must not depend on app-private ADB file reads" >&2
  exit 1
fi

if grep -Fq -- 'capture_transport": "flutter_driver_takeScreenshot_app_private_file"' "$script"; then
  echo "FAIL: stale app-private capture transport metadata remains" >&2
  exit 1
fi

if grep -Eq '(^|[[:space:]])flutter[[:space:]]+test[[:space:]]+--no-pub' "$script"; then
  echo "FAIL: runtime evidence must use flutter drive, not flutter test" >&2
  exit 1
fi

echo "PASS: runtime driver contract"
