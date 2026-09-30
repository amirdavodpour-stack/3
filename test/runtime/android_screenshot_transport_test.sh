#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
test_file="$repo_root/integration_test/runtime/critical_screens_evidence_test.dart"
driver_file="$repo_root/test_driver/hope_runtime_screenshot_driver.dart"
script_file="$repo_root/tools/hope-wallet-runtime-evidence.sh"

capture_start="$(grep -n '^Future<void> _captureRuntimeScreenshot(String marker) async {' "$test_file" | cut -d: -f1)"
capture_end="$(grep -n '^Future<void> _waitForRuntimeRenderToSettle' "$test_file" | cut -d: -f1)"
if [ -z "$capture_start" ] || [ -z "$capture_end" ] || [ "$capture_end" -le "$capture_start" ]; then
  echo "FAIL: screenshot capture function bounds are missing" >&2
  exit 1
fi
capture_body="$(sed -n "${capture_start},$((capture_end - 1))p" "$test_file")"

grep -Fq 'await binding.takeScreenshot(marker);' <<<"$capture_body"

if grep -Fq 'waitUntilFirstFrameRasterized' "$test_file"; then
  echo "FAIL: runtime screenshot harness must not block on platform rasterization before the Flutter capture surface is prepared" >&2
  exit 1
fi

grep -Fq "HOPE_SCREENSHOT_SOURCE:flutter-driver" "$test_file"
if grep -Fq '_adbScreenshotCapture' "$test_file"; then
  echo "FAIL: retired ADB screenshot flag remains" >&2
  exit 1
fi
if grep -Fq 'HOPE_SCREENSHOT_SYNC_ROOT' "$test_file"; then
  echo "FAIL: retired app-private screenshot sync root remains" >&2
  exit 1
fi

grep -Fq 'onScreenshot:' "$driver_file"
grep -Fq 'writeAsBytes(image, flush: true)' "$driver_file"
grep -Fq 'wait_for_screenshot_file' "$script_file"
grep -Fq 'HOPE_HOST_SCREENSHOT_READY' "$script_file"
if grep -Fq 'adb exec-out screencap -p' "$script_file"; then
  echo "FAIL: host still captures a later framebuffer snapshot" >&2
  exit 1
fi
if grep -Fq 'HOPE_ADB_SCREENSHOT_CAPTURE=true' "$script_file"; then
  echo "FAIL: build still enables retired ADB screenshot mode" >&2
  exit 1
fi

grep -Fq 'HOPE_RUNTIME_TEST_BODY_COMPLETE' "$script_file"
grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$script_file"
completion_line="$(grep -Fn 'if [ "$completion_status" -eq 0 ]; then' "$script_file" | head -n1 | cut -d: -f1)"
stop_line="$(grep -Fn 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$script_file" | head -n1 | cut -d: -f1)"
if [ -z "$completion_line" ] || [ -z "$stop_line" ] || [ "$stop_line" -le "$completion_line" ]; then
  echo "FAIL: completed test must trigger bounded driver shutdown" >&2
  exit 1
fi

grep -Fq '"capture_transport": "flutter_integration_test_onScreenshot"' "$script_file"

# The contract must not depend on retired screenKey scaffolding.
if grep -Fq "screenKey: marker" "$test_file"; then
  echo "FAIL: retired screenKey scaffolding still present" >&2
  exit 1
fi

echo "PASS: Flutter rendered-screenshot transport contract"
