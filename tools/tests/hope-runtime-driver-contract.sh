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
$T grep -Fq -- 'capture_host_screenshot "$marker" "$process_pid" || { capture_status=$?; break; }' "$script"
$T grep -Fq -- 'test -s "$output"' "$script"
$T grep -Fq -- 'HOPE_HOST_SCREENSHOT_CAPTURED:$marker' "$script"
$T grep -Fq -- 'RUNTIME_SHUTDOWN_GRACE_SECONDS=' "$script"

$T grep -Fq -- 'onScreenshot:' "$driver"
$T grep -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
$T grep -Fq -- "Platform.environment['GITHUB_WORKSPACE']" "$driver"

$T grep -Fq -- 'IntegrationTestWidgetsFlutterBinding.ensureInitialized' "$test_file"
$T grep -Fq -- 'await binding.convertFlutterSurfaceToImage();' "$test_file"
$T grep -Fq -- 'await binding.takeScreenshot(marker);' "$test_file"
$T grep -Fq -- 'await tester.binding.endOfFrame;' "$test_file"
$T grep -Fq -- 'find.byType(SkeletonBox).evaluate().isNotEmpty' "$test_file"

for forbidden in integrationTestChannel captureScreenshot revertFlutterImage HOPE_SCREENSHOT_SYNC_ROOT HOPE_ADB_SCREENSHOT_CAPTURE files/hope-screen-sync- test-complete.ready completion_request= 'adb exec-out screencap -p' 'run-as com.hope.marketplace'; do
  if $T grep -Fq -- "$forbidden" "$script" "$test_file"; then
    echo "FAIL: legacy screenshot transport remains: $forbidden" >&2
    exit 1
  fi
done

echo "PASS: official Flutter integration_test screenshot transport contract"
