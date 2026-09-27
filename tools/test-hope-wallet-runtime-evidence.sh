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
grep -Fq 'capture_host_screenshot "$marker" "$process_pid" || { capture_status=$?; break; }' "$script"
grep -Fq 'test -s "$output"' "$script"
grep -Fq 'RUNTIME_SHUTDOWN_GRACE_SECONDS=' "$script"

grep -Fq 'onScreenshot:' "$driver"
grep -Fq 'writeAsBytes(image, flush: true)' "$driver"
grep -Fq 'HOPE_SCREENSHOT_OUTPUT_ROOT' "$driver"

grep -Fq 'await binding.convertFlutterSurfaceToImage();' "$dart_test"
grep -Fq 'await binding.takeScreenshot(marker);' "$dart_test"
grep -Fq 'find.byType(SkeletonBox).evaluate().isNotEmpty' "$dart_test"

if grep -Eq 'integrationTestChannel|captureScreenshot|revertFlutterImage|HOPE_SCREENSHOT_SYNC_ROOT|HOPE_ADB_SCREENSHOT_CAPTURE|files/hope-screen-sync-|test-complete.ready|adb .*screencap -p|run-as com.hope.marketplace' "$script" "$dart_test"; then
  echo "runtime harness contract: FAIL — legacy app-file/native-channel screenshot transport remains" >&2
  exit 1
fi

echo "runtime harness contract: PASS"
