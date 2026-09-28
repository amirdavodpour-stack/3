#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
test_file="$repo_root/integration_test/runtime/critical_screens_evidence_test.dart"
script_file="$repo_root/tools/hope-wallet-runtime-evidence.sh"

# The runtime path is intentionally split into:
# Flutter IntegrationTest screenshot publication -> app-private READY marker ->
# host validation/capture. Keep this contract aligned with the actual harness.
grep -Fq "const _adbScreenshotCapture" "$test_file"
grep -Fq "String.fromEnvironment('HOPE_SCREENSHOT_SYNC_ROOT'" "$test_file"
grep -Fq "while (await request.exists())" "$test_file"
grep -Fq "await binding.takeScreenshot(marker);" "$test_file"
grep -Fq "HOPE_SCREENSHOT_READY:" "$test_file"
grep -Fq "HOPE_RUNTIME_TEST_BODY_COMPLETE" "$test_file"

grep -Fq "HOPE_ADB_SCREENSHOT_CAPTURE=true" "$script_file"
grep -Fq "HOPE_SCREENSHOT_SYNC_ROOT" "$script_file"
grep -Fq "capture_host_screenshot" "$script_file"
grep -Fq "assert_hope_focused" "$script_file"
grep -Fq "assert_hope_rendered" "$script_file"
grep -Fq "adb exec-out screencap -p" "$script_file"
grep -Fq "89504e470d0a1a0a" "$script_file"
grep -Fq "duplicate-png-hash" "$script_file"
grep -Fq "packageName=com.hope.marketplace" "$script_file"
grep -Fq "reportedDrawn=true reportedVisible=true" "$script_file"

# The contract must not depend on retired screenKey scaffolding.
if grep -Fq "screenKey: marker" "$test_file"; then
  echo "FAIL: retired screenKey scaffolding still present" >&2
  exit 1
fi

echo "PASS: current Android rendered-screenshot transport contract"
