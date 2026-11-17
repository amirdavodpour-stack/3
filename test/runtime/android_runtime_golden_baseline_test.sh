#!/usr/bin/env bash
# [runtime-capture-fa] exact-head rerun after #1844 guard-only drift.
# [runtime-capture-fa] certify Wave II grouped visual convergence: dark foundation + opportunity hierarchy + finance/profile composition.
# [runtime-capture-fa] exact-head guard sync after #1844 stale auth-recovery assertion.
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

# Locked to the proven Android emulator geometry from Run #322.
# Screenshot bytes are produced by integration_test and persisted by the
# Flutter driver callback; the old host-framebuffer transport is retired.
# The only runtime path with a fully green 15-screen certification is the pinned
# soloturn runner used by Run #35741811401. Keep this infrastructure contract locked;
# the maintained ReactiveCircus action is not equivalent for this lane.
require_line "$workflow" "repository: soloturn/android-emulator-runner"
require_line "$workflow" "ref: ab495a9b42f2af30f5222bd978136f9b0a85b68a"
require_line "$workflow" "uses: ./.ci/android-emulator-runner"
require_line "$workflow" "ram-size: 8192M"
require_line "$workflow" "force-avd-creation: false"
if grep -Fq 'uses: ReactiveCircus/android-emulator-runner@' "$workflow"; then
  printf 'FAIL: runtime golden baseline regressed to the non-certified ReactiveCircus runner.\n' >&2
  exit 1
fi

require_line "$workflow" "api-level: 35"
require_line "$workflow" "target: default"
require_line "$workflow" "profile: pixel_2"
require_line "$workflow" "cores: 4"
require_line "$workflow" "emulator-options: -no-window -no-snapshot -gpu swiftshader_indirect -feature -Vulkan -noaudio -no-boot-anim -camera-back none -camera-front none -no-metrics"
require_line "$workflow" "-feature -Vulkan"
if grep -Fq -- '-gpu software' "$workflow"; then
  printf 'FAIL: runtime golden baseline still uses generic software GPU mode; use the runner-stable swiftshader_indirect mode.\n' >&2
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
require_line "$runtime" 'flutter drive --no-enable-impeller --no-pub --no-dds'
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
  printf 'FAIL: runtime baseline still bypasses flutter drive target compilation.\n' >&2
  exit 1
fi
if grep -Fq -- '--route=' "$runtime"; then
  printf 'FAIL: runtime baseline still configures capture through route transport.\n' >&2
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
require_line "$runtime" 'baseline-g) baseline_batch="g"'
require_line "$test_file" "_baselineBatch == 'g'"
require_line "$runtime" 'run_host_batch_session baseline-g "create-job-fa-rtl"'
require_line "$runtime" 'run_host_batch_session baseline-e "register-fa-rtl"'
require_line "$runtime" 'run_host_batch_session baseline-f "password-reset-fa-rtl"'
require_line "$runtime" 'HOPE_HOST_RUNTIME_PARTITIONED_BASELINE_START:fa'
require_line "$runtime" 'run_host_batch_session baseline-a "${baseline_screens[@]:0:7}"'
require_line "$runtime" 'run_host_batch_session baseline-b "${baseline_screens[@]:7:1}"'
require_line "$runtime" 'run_host_batch_session baseline-c "${baseline_screens[@]:8:4}"'
require_line "$runtime" 'run_host_batch_session baseline-g "create-job-fa-rtl"'
require_line "$runtime" 'run_host_batch_session baseline-e "register-fa-rtl"'
require_line "$runtime" 'run_host_batch_session baseline-f "password-reset-fa-rtl"'
require_line "$runtime" 'HOPE_HOST_RUNTIME_PARTITIONED_BASELINE_START:fa'
if grep -Fq '&& test -s "$evidence_dir/create-job-fa-rtl.png"' "$runtime"; then
  printf 'FAIL: auth-tail recovery is gated on a screenshot that cannot exist when the long session dies before onScreenshot flush.\n' >&2
  exit 1
fi
require_line "$runtime" 'duplicate-png-hash'

# Wave I regression guard: the work/finance focus strip must consume counts
# from the surrounding build scope, not a nested LayoutBuilder, and its panel
# padding must remain EdgeInsets-compatible with PremiumPanel.
transactions_file="lib/features/transactions/transactions_page.dart"
layout_line="$(grep -n '^[[:space:]]*LayoutBuilder(' "$transactions_file" | head -n1 | cut -d: -f1)"
active_count_line="$(grep -n 'final activeCount = _countWorkCenterActive(items);' "$transactions_file" | head -n1 | cut -d: -f1)"
if [[ -z "$layout_line" || -z "$active_count_line" || "$active_count_line" -ge "$layout_line" ]]; then
  printf 'FAIL: transactions visual-wave counts are scoped inside LayoutBuilder; they must be available to the focus strip.\\n' >&2
  exit 1
fi
require_line "$transactions_file" 'padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),'

echo "PASS: Android runtime screenshot baseline contract is locked."

# [runtime-capture-fa] validate Vulkan-disabled emulator capture after native surface-conversion failure.

# [runtime-capture-fa] re-trigger exact-head Vulkan-disabled transport validation.

# [runtime-capture-fa] current-head rerun after debug transport forensics.

# [runtime-capture-fa] verify aligned baseline/responsive partition contract at exact HEAD.

# [runtime-capture-fa] exact-head runtime validation after baseline/responsive alignment forensic check.

# [runtime-capture-fa] certify compile-scope recovery after Wave I forensic failure.

# [runtime-capture-fa] certify grouped Wave III finance, notifications and offers hierarchy after #1856 screenshot review.
