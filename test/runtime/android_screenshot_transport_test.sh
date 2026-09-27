#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
test_file="$repo_root/integration_test/runtime/critical_screens_evidence_test.dart"
driver_file="$repo_root/test_driver/hope_runtime_screenshot_driver.dart"
script_file="$repo_root/tools/hope-wallet-runtime-evidence.sh"

grep -Fq "await binding.convertFlutterSurfaceToImage();" "$test_file"
grep -Fq "await binding.takeScreenshot(marker);" "$test_file"
grep -Fq "final String screenKey;" "$test_file"
grep -Fq "key: ValueKey(screenKey)" "$test_file"
grep -Fq "screenKey: marker" "$test_file"
grep -Fq "Future<void> _captureRuntimeScreenshot(String marker)" "$test_file"

grep -Fq "integrationDriver(" "$driver_file"
grep -Fq "onScreenshot:" "$driver_file"
grep -Fq "HOPE_SCREENSHOT_OUTPUT_ROOT=" "$script_file"
grep -Fq "flutter drive --no-pub --no-dds --no-enable-impeller" "$script_file"
grep -Fq "timeout --foreground" "$script_file"
grep -Fq "validate_capture_set" "$script_file"
grep -Fq "duplicate-png-hash" "$script_file"

if grep -Fq "_adbScreenshotCapture" "$test_file"; then
  echo "FAIL: custom ADB screenshot capture branch is still present" >&2
  exit 1
fi
if grep -Fq "adb exec-out screencap -p" "$script_file"; then
  echo "FAIL: host framebuffer capture is still active" >&2
  exit 1
fi
if grep -Fq "HOPE_SCREENSHOT_SYNC_ROOT" "$test_file" || grep -Fq "HOPE_SCREENSHOT_SYNC_ROOT" "$script_file"; then
  echo "FAIL: app-private screenshot sync channel is still present" >&2
  exit 1
fi
if grep -Fq "capture_host_screenshot" "$script_file"; then
  echo "FAIL: per-screen host capture handshake is still present" >&2
  exit 1
fi

echo "PASS: official Flutter integration_test screenshot transport contract"
