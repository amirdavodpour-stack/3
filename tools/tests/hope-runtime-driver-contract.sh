#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="${2:-test_driver/hope_runtime_screenshot_driver.dart}"
test_file="${3:-integration_test/runtime/critical_screens_evidence_test.dart}"
T="/system/bin/toybox"

$T grep -Fq -- 'flutter drive' "$script"
$T grep -Fq -- '--no-dds' "$script"
$T grep -Fq -- 'CAPTURE_LOCALE="${HOPE_CAPTURE_LOCALE:-}"' "$script"
$T grep -Fq -- 'case "$CAPTURE_LOCALE" in' "$script"
$T grep -Fq -- 'fa|en) ;;' "$script"
$T grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
$T grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
$T grep -Fq -- 'env HOPE_CAPTURE_LOCALE="$CAPTURE_LOCALE" HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" flutter drive' "$script"
$T grep -Fq -- 'validate_capture_set()' "$script"
$T grep -Fq -- 'capture_transport":' "$script"
$T grep -Fq -- 'HOPE_ADB_SCREENSHOT_CAPTURE=true' "$script"
$T grep -Fq -- 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" flutter drive' "$script"
$T grep -Fq -- '--dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
$T grep -Fq -- 'adb exec-out screencap -p' "$script"
$T grep -Fq -- 'run-as com.hope.marketplace cat "$request"' "$script"
$T grep -Fq -- 'HOPE_SCREENSHOT_SYNC_ROOT' "$script"
$T grep -Fq -- 'onScreenshot:' "$driver"
$T grep -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
$T grep -Fq -- 'binding.takeScreenshot(marker)' "$test_file"
$T grep -Fq -- '_prepareRuntimeScreenshotSurface(tester);' "$test_file"

$T grep -Fq -- 'await _prepareRuntimeScreenshotSurface(tester);' "$test_file"
$T grep -Fq -- 'if (_responsiveOnly) {' "$test_file"
$T grep -Fq -- 'await _captureBaselineLocale(' "$test_file"
$T grep -Fq -- 'await _captureResponsiveLocale(' "$test_file"

if $T grep -Fq -- 'binding.callbackManager.takeScreenshot(marker)' "$test_file"; then
  echo "FAIL: runtime screenshot must use integration_test reportData for driver callback" >&2
  exit 1
fi

if $T grep -Fq -- 'screenshots.clear()' "$test_file"; then
  echo "FAIL: screenshot reportData must remain available for driver callback" >&2
  exit 1
fi

if $T grep -Fq -- 'capture_screen()' "$script" ||
   $T grep -Fq -- 'verify_runtime_screenshot()' "$script" ||
   $T grep -Fq -- 'collect_runtime_screenshot(' "$script"; then
  echo "FAIL: screenshot capture must be handled by flutter_driver onScreenshot, not ADB live polling" >&2
  exit 1
fi

if $T grep -Fq -- 'flutter drive' "$script"; then
  if $T grep -Fq -- 'flutter drive --no-pub --no-dds' "$script"; then
    :
  fi
fi

echo "PASS: runtime driver foreground contract"
