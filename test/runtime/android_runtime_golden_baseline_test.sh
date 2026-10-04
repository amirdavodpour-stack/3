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

# Locked to the proven Android emulator geometry from Run #322.\n# Screenshot bytes are produced by integration_test and persisted by the\n# Flutter driver callback; the old host-framebuffer transport is retired.
require_line "$workflow" "api-level: 35"
require_line "$workflow" "target: default"
require_line "$workflow" "profile: pixel_2"
require_line "$workflow" "cores: 4"
require_line "$workflow" "ram-size: 4096M"
require_line "$workflow" "emulator-options: -no-window -no-snapshot -gpu swangle -noaudio -no-boot-anim -camera-back none -camera-front none -no-metrics"
if grep -Fq -- '-gpu swiftshader_indirect' "$workflow"; then
  printf 'FAIL: runtime golden baseline still uses deprecated swiftshader_indirect GPU mode.\n' >&2
  exit 1
fi

# Screenshot production is locked to the current Flutter integration_test callback path.
driver_file="test_driver/hope_runtime_screenshot_driver.dart"

require_line "$test_file" "await binding.convertFlutterSurfaceToImage();"
require_line "$test_file" "await binding.takeScreenshot(marker);"
require_line "$test_file" "HOPE_SCREENSHOT_CAPTURE_START:"
require_line "$test_file" "HOPE_SCREENSHOT_SOURCE:flutter-driver:"
require_line "$test_file" "HOPE_SCREENSHOT_READY:"
require_line "$test_file" "IntegrationTestWidgetsFlutterBinding.ensureInitialized();"
require_line "$test_file" "String.fromEnvironment('HOPE_CAPTURE_LOCALE', defaultValue: '')"
require_line "$test_file" "String.fromEnvironment('HOPE_CAPTURE_MODE', defaultValue: 'baseline')"
require_line "$driver_file" "integrationDriver("
require_line "$driver_file" "onScreenshot:"
require_line "$driver_file" "writeAsBytes(image, flush: true)"
require_line "$runtime" 'flutter drive --no-pub --no-dds'
require_line "$runtime" 'HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT'
require_line "$runtime" 'HOPE_HOST_RUNTIME_DRIVER_FORCE_STOP'
if grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$runtime"; then
  printf 'FAIL: runtime baseline still force-stops the driver after screenshot flush.\n' >&2
  exit 1
fi
require_line "$runtime" 'RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-30}"'
require_line "$runtime" 'HOPE_RUNTIME_DRIVER_BUILD_MODE:self-build'
require_line "$runtime" '--dart-define=HOPE_CAPTURE_LOCALE="${CAPTURE_LOCALE}"'
require_line "$runtime" '--dart-define=HOPE_CAPTURE_MODE="${launch_mode}"'
require_line "$runtime" '--dart-define=HOPE_CAPTURE_HOME_ONLY="${DART_CAPTURE_HOME_ONLY}"'
if grep -Fq -- '--use-application-binary' "$runtime"; then
  printf 'FAIL: runtime baseline still bypasses flutter drive target compilation.
' >&2
  exit 1
fi
if grep -Fq -- '--route=' "$runtime"; then
  printf 'FAIL: runtime baseline still configures capture through route transport.
' >&2
  exit 1
fi
if grep -Fq 'HOPE_ADB_SCREENSHOT_CAPTURE=true' "$runtime"; then
  printf 'FAIL: retired ADB screenshot mode is still part of the runtime baseline.\n' >&2
  exit 1
fi
if grep -Fq 'adb exec-out screencap -p' "$runtime"; then
  printf 'FAIL: runtime baseline still captures a later Android framebuffer.\n' >&2
  exit 1
fi

# Runtime evidence must reject byte-identical PNGs under different screen names.
require_line "$runtime" 'duplicate-png-hash'



echo "PASS: Android runtime screenshot baseline contract is locked."
