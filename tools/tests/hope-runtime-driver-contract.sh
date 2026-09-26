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
$T grep -Fq -- 'env HOPE_CAPTURE_LOCALE="$CAPTURE_LOCALE" HOPE_ADB_SCREENSHOT_CAPTURE=true HOPE_SCREENSHOT_SYNC_ROOT=' "$script"
$T grep -Fq -- 'validate_capture_set()' "$script"
$T grep -Fq -- 'capture_transport":' "$script"
$T grep -Fq -- 'HOPE_ADB_SCREENSHOT_CAPTURE=true' "$script"
$T grep -Fq -- 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" flutter drive' "$script"
$T grep -Fq -- '--dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
$T grep -Fq -- 'adb exec-out screencap -p' "$script"
$T grep -Fq -- 'run-as com.hope.marketplace cat "$request"' "$script"
$T grep -Fq -- 'HOPE_SCREENSHOT_SYNC_ROOT' "$script"
$T grep -Fq -- 'run_en_host_session baseline "${baseline_screens[@]}" || baseline_status=$?' "$script"
$T grep -Fq -- 'run_en_host_session responsive       "responsive-720x1280-home-fa-rtl"' "$script"
$T grep -Fq -- 'run_en_host_session responsive       "responsive-720x1280-jobs-fa-rtl"' "$script"
$T grep -Fq -- '"capture_transport": "adb_exec_out_screencap_host_handshake"' "$script"
$T grep -Fq -- 'onScreenshot:' "$driver"
$T grep -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
$T grep -Fq -- "Platform.environment['GITHUB_WORKSPACE']" "$driver"
$T grep -Fq -- 'docs/audit/evidence/android-runtime' "$driver"
$T grep -Fq -- 'binding.takeScreenshot(marker)' "$test_file"
$T grep -Fq -- '_prepareRuntimeScreenshotSurface(tester);' "$test_file"

$T grep -Fq -- 'await _prepareRuntimeScreenshotSurface(tester);' "$test_file"
$T grep -Fq -- 'if (_responsiveOnly) {' "$test_file"
$T grep -Fq -- 'await _captureBaselineLocale(' "$test_file"
$T grep -Fq -- 'await _captureResponsiveLocale(' "$test_file"
$T grep -Fq -- 'await tester.pumpWidget(' "$test_file"
$T grep -Fq -- '_EvidenceHost(' "$test_file"
$T grep -Fq -- 'test-complete.ready' "$test_file"
$T grep -Fq -- 'HOPE_RUNTIME_TEST_BODY_COMPLETE' "$test_file"
$T grep -Fq -- 'completion_request="files/hope-screen-sync-${GITHUB_RUN_ID}/test-complete.ready"' "$script"
$T grep -Fq -- 'completion_deadline=$((SECONDS + 30))' "$script"
$T grep -Fq -- 'grace_deadline=$((SECONDS + 5))' "$script"
$T grep -Fq -- 'kill "$process_pid"' "$script"
if $T grep -Fq -- 'ValueNotifier<_RuntimeScreen>' "$test_file" ||
   $T grep -Fq -- 'ValueListenableBuilder<_RuntimeScreen>' "$test_file"; then
  echo "FAIL: runtime capture must rebuild the host between screens" >&2
  exit 1
fi


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

# EN baseline must pass the host driver's required output root, not only the responsive branch.
$T grep -Fq -- 'HOPE_SCREENSHOT_SYNC_ROOT="/data/user/0/com.hope.marketplace/files/hope-screen-sync-${GITHUB_RUN_ID}" HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" flutter drive' "$script"

echo "PASS: runtime driver foreground contract"

# EN host capture must fail fast instead of spending one full timeout per later marker.
if $T grep -Fq -- 'capture_host_screenshot "$marker" "$process_pid" || capture_status=1' "$script"; then
  echo "FAIL: EN host session continues after first capture failure" >&2
  exit 1
fi
$T grep -Fq -- 'capture_host_screenshot "$marker" "$process_pid" || { capture_status=$?; break; }' "$script"

# EN READY handshake must use direct adb exec-out; avoid an extra adb shell layer.
if $T grep -Fq -- 'adb shell run-as com.hope.marketplace cat "$request"' "$script"; then
  echo "FAIL: EN READY handshake still uses adb shell run-as" >&2
  exit 1
fi
$T grep -Fq -- 'adb exec-out run-as com.hope.marketplace cat "$request"' "$script"
