#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="${2:-test_driver/hope_runtime_screenshot_driver.dart}"
test_file="${3:-integration_test/runtime/critical_screens_evidence_test.dart}"
if [[ -x /system/bin/toybox ]]; then
  T="/system/bin/toybox"
  grep_fixed() { "$T" grep "$@"; }
else
  grep_fixed() { grep "$@"; }
fi

grep_fixed -Fq -- 'flutter drive' "$script"
grep_fixed -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep_fixed -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep_fixed -Fq -- 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
grep_fixed -Fq -- 'HOPE_CAPTURE_TEXT_SCALE="${CAPTURE_TEXT_SCALE}"' "$script"
grep_fixed -Fq -- '"text_scale": $CAPTURE_TEXT_SCALE' "$script"
grep_fixed -Fq -- 'RUNTIME_TEST_TIMEOUT_SECONDS=' "$script"
grep_fixed -Fq -- 'timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s"' "$script"
grep_fixed -Fq -- 'validate_capture_set "baseline-$CAPTURE_LOCALE"' "$script"
grep_fixed -Fq -- 'validate_capture_set "responsive-$CAPTURE_LOCALE-a"' "$script"
grep_fixed -Fq -- 'await integrationDriver(' "$driver"

grep_fixed -Fq -- 'onScreenshot:' "$driver"
grep_fixed -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
grep_fixed -Fq -- "const outputRoot = 'docs/audit/evidence/android-runtime';" "$driver"
grep_fixed -Fq -- 'docs/audit/evidence/android-runtime' "$driver"

grep_fixed -Fq -- 'IntegrationTestWidgetsFlutterBinding.ensureInitialized' "$test_file"
grep_fixed -Fq -- 'await binding.convertFlutterSurfaceToImage();' "$test_file"
grep_fixed -Fq -- "MethodChannel('hope.runtime/screenshot')" "$test_file"
grep_fixed -Fq -- "'captureScreenshot'," "$test_file"
grep_fixed -Fq -- 'await _captureHopeNativeScreenshot(binding, marker);' "$test_file"
grep_fixed -Fq -- 'await _prepareRuntimeScreenshotSurface(tester);' "$test_file"
grep_fixed -Fq -- 'TextScaler.linear(_captureTextScale)' "$test_file"
grep_fixed -Fq -- 'HOPE_RUNTIME_CAPTURE_TEXT_SCALE:$_captureTextScale' "$test_file"
grep_fixed -Fq -- 'find.byType(SkeletonBox).evaluate().isNotEmpty' "$test_file"
grep_fixed -Fq -- 'HOPE_SCREENSHOT_READY:$marker' "$test_file"

for forbidden in revertFlutterImage HOPE_SCREENSHOT_SYNC_ROOT HOPE_ADB_SCREENSHOT_CAPTURE files/hope-screen-sync- test-complete.ready completion_request= 'adb exec-out screencap -p' 'run-as com.hope.marketplace'; do
  if grep_fixed -Fq -- "$forbidden" "$script" "$test_file"; then
    echo "FAIL: legacy screenshot transport remains: $forbidden" >&2
    exit 1
  fi
done

echo "PASS: official Flutter integration_test screenshot transport contract"
