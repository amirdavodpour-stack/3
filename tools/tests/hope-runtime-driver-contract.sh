#!/usr/bin/env bash
set -euo pipefail

script="\${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="\${2:-test_driver/hope_runtime_screenshot_driver.dart}"
test_file="\${3:-integration_test/runtime/critical_screens_evidence_test.dart}"
T="/system/bin/toybox"

$T grep -Fq -- 'flutter drive' "$script"
$T grep -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
$T grep -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
$T grep -Fq -- 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
$T grep -Fq -- 'RUNTIME_TEST_TIMEOUT_SECONDS=' "$script"
$T grep -Fq -- 'timeout --foreground --signal=TERM --kill-after=30s' "$script"
$T grep -Fq -- 'validate_capture_set "baseline-$CAPTURE_LOCALE"' "$script"
$T grep -Fq -- 'validate_capture_set "responsive-$CAPTURE_LOCALE"' "$script"
$T grep -Fq -- "integration_test's extended driver receives screenshot bytes from" "$script"

$T grep -Fq -- 'onScreenshot:' "$driver"
$T grep -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
$T grep -Fq -- "Platform.environment['GITHUB_WORKSPACE']" "$driver"
$T grep -Fq -- 'docs/audit/evidence/android-runtime' "$driver"

$T grep -Fq -- 'IntegrationTestWidgetsFlutterBinding.ensureInitialized' "$test_file"
$T grep -Fq -- 'await binding.convertFlutterSurfaceToImage();' "$test_file"
$T grep -Fq -- 'await binding.takeScreenshot(marker);' "$test_file"
$T grep -Fq -- 'await tester.binding.endOfFrame;' "$test_file"
$T grep -Fq -- 'find.byType(SkeletonBox).evaluate().isNotEmpty' "$test_file"
$T grep -Fq -- 'HOPE_SCREENSHOT_READY:$marker' "$test_file"

for forbidden in integrationTestChannel captureScreenshot revertFlutterImage HOPE_SCREENSHOT_SYNC_ROOT HOPE_ADB_SCREENSHOT_CAPTURE files/hope-screen-sync- test-complete.ready completion_request= 'adb exec-out screencap -p' 'run-as com.hope.marketplace'; do
  if $T grep -Fq -- "$forbidden" "$script" "$test_file"; then
    echo "FAIL: legacy screenshot transport remains: $forbidden" >&2
    exit 1
  fi
done

echo "PASS: official Flutter integration_test screenshot transport contract"
