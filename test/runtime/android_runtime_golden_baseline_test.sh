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

# Keep host-side framebuffer capture; do not regress to Flutter screenshot RPC.
require_line "$runtime" 'adb exec-out screencap -p'
require_line "$runtime" 'HOPE_ADB_SCREENSHOT_CAPTURE=true'
require_line "$runtime" 'HOPE_SCREENSHOT_SYNC_ROOT='
require_line "$test_file" 'bool.fromEnvironment('''HOPE_ADB_SCREENSHOT_CAPTURE''''
require_line "$test_file" 'adbScreenshotCapture'

# The integration test may retain a fallback implementation, but the ADB-mode
# branch must be explicit and short-circuit before that fallback.
require_line "$test_file" "if (_adbScreenshotCapture || _runtimeScreenshotSurfacePrepared)"
require_line "$test_file" "if (_adbScreenshotCapture) {"
require_line "$test_file" "await binding.takeScreenshot(marker);"


echo "PASS: Android runtime golden baseline (Run #322) is locked."
