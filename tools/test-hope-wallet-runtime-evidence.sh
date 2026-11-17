#!/usr/bin/env bash
set -euo pipefail

script="tools/hope-wallet-runtime-evidence.sh"
driver="test_driver/hope_runtime_screenshot_driver.dart"
dart_test="integration_test/runtime/critical_screens_evidence_test.dart"

test -f "$script"
test -f "$driver"
test -f "$dart_test"
bash -n "$script"

grep -Fq 'flutter drive' "$script"
grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep -Fq 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
grep -Fq 'timeout --foreground --signal=TERM --kill-after=30s' "$script"
grep -Fq 'validate_capture_set "baseline-$CAPTURE_LOCALE"' "$script"
grep -Fq 'validate_capture_set "responsive-$CAPTURE_LOCALE"' "$script"
grep -Fq 'HOPE_BASELINE_BATCH' "$script"
grep -Fq 'run_host_batch_session baseline-a' "$script"
grep -Fq 'run_host_batch_session baseline-b' "$script"
grep -Fq 'run_host_batch_session baseline-c' "$script"
grep -Fq 'run_host_batch_session baseline-e' "$script"
grep -Fq 'run_host_batch_session baseline-f' "$script"
grep -Fq "_baselineBatch == 'e'" "$dart_test"
grep -Fq "_baselineBatch == 'f'" "$dart_test"
grep -Fq 'HOPE_HOST_RUNTIME_AUTH_SINGLE_SCREEN_RECOVERY' "$script"
grep -Fq "_baselineBatch == 'c'" "$dart_test"
grep -Fq 'HOPE_BASELINE_BATCH' "$dart_test"

grep -Fq 'onScreenshot:' "$driver"
grep -Fq 'writeAsBytes(image, flush: true)' "$driver"

grep -Fq 'await binding.convertFlutterSurfaceToImage();' "$dart_test"
grep -Fq 'await binding.takeScreenshot(marker);' "$dart_test"
grep -Fq 'find.byType(SkeletonBox).evaluate().isNotEmpty' "$dart_test"

if grep -Eq 'integrationTestChannel|captureScreenshot|revertFlutterImage|HOPE_SCREENSHOT_SYNC_ROOT|HOPE_ADB_SCREENSHOT_CAPTURE|files/hope-screen-sync-|test-complete.ready|completion_request=|adb .*screencap -p|run-as com.hope.marketplace' "$script" "$dart_test"; then
  echo "runtime harness contract: FAIL — legacy app-file/native-channel screenshot transport remains" >&2
  exit 1
fi

echo "runtime harness contract: PASS"
