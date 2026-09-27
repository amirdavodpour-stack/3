#!/usr/bin/env bash
set -euo pipefail

workflow=".github/workflows/hope-ui-runtime-evidence.yml"
runtime="tools/hope-wallet-runtime-evidence.sh"
test_file="integration_test/runtime/critical_screens_evidence_test.dart"

require_line() {
  local file="$1" expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    printf 'FAIL: runtime golden baseline drift in %s; missing: %s\n' "$file" "$expected" >&2
    exit 1
  fi
}

# Locked to exact successful Run #322 / SHA 4ad34dbf8c71f7dde5f8f7a51cea53c0d9b4351b.
require_line "$workflow" "api-level: 35"
require_line "$workflow" "target: default"
require_line "$workflow" "profile: pixel_2"
require_line "$workflow" "cores: 4"
require_line "$workflow" "ram-size: 4096M"
require_line "$workflow" "emulator-options: -no-window -no-snapshot -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none -camera-front none -no-metrics"

# Screenshot production is locked to the proven direct Android framebuffer path.
driver_file="test_driver/hope_runtime_screenshot_driver.dart"

require_line "$test_file" "const _adbScreenshotCapture"
require_line "$test_file" "if (!_adbScreenshotCapture)"
require_line "$test_file" "await binding.takeScreenshot(marker);"
require_line "$test_file" "HOPE_SCREENSHOT_CAPTURE_START:"
require_line "$test_file" "HOPE_SCREENSHOT_READY:"
require_line "$driver_file" "integrationDriver("
require_line "$driver_file" "onScreenshot:"
require_line "$runtime" 'flutter drive --no-pub --no-dds'
require_line "$runtime" 'HOPE_ADB_SCREENSHOT_CAPTURE=true'
require_line "$runtime" 'adb exec-out screencap -p'
require_line "$runtime" 'capture_host_screenshot'

# Runtime evidence must reject byte-identical PNGs under different screen names.
require_line "$runtime" 'duplicate-png-hash'



echo "PASS: Android runtime screenshot baseline contract is locked."
