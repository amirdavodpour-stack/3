#!/usr/bin/env bash
set -euo pipefail

workflow=".github/workflows/hope-ui-runtime-evidence.yml"
runtime="tools/hope-wallet-runtime-evidence.sh"
test_file="integration_test/runtime/critical_screens_evidence_test.dart"
main_activity="android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt"

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
require_line "$workflow" "name: Test Android Emulator package retry contract"
require_line "$workflow" "run: bash test/runtime/android_emulator_install_retry_test.sh"
require_line "$workflow" "name: Prepare Android Emulator package with bounded retry"
require_line "$workflow" "run: bash tools/install-android-emulator-retry.sh"
prepare_line="$(grep -nF -- '- name: Prepare Android Emulator package with bounded retry' "$workflow" | cut -d: -f1 | head -n1)"
runtime_line="$(grep -nF -- '- name: Android runtime evidence' "$workflow" | cut -d: -f1 | head -n1)"
if [[ -z "$prepare_line" || -z "$runtime_line" || "$prepare_line" -ge "$runtime_line" ]]; then
  echo "FAIL: Android Emulator package must be prewarmed and validated before the pinned runner starts." >&2
  exit 1
fi
require_line "$workflow" "ram-size: 8192M"
require_line "$workflow" 'group: hope-ui-runtime-evidence-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}'
# A cached AVD can retain the app/TalkBack packages from a prior job's debug signing key.
# Always recreate user data before the runner installs the exact-HEAD APK.
require_line "$workflow" "force-avd-creation: true"
require_line "$workflow" "Recreate AVD user data from the cached API-35 system image on each run."
if grep -Fq 'uses: ReactiveCircus/android-emulator-runner@' "$workflow"; then
  printf 'FAIL: runtime golden baseline regressed to the non-certified ReactiveCircus runner.\n' >&2
  exit 1
fi

require_line "$workflow" "api-level: 35"
require_line "$workflow" "target: default"
require_line "$workflow" "profile: pixel_2"
require_line "$workflow" "fetch-depth: 2"
require_line "$workflow" "Align PR runtime checkout to exact feature HEAD"
require_line "$workflow" 'exact_head="$(git rev-parse HEAD^2)"'
require_line "$workflow" 'test "$(git rev-parse HEAD)" = "$exact_head"'
require_line "$workflow" "cores: 4"
require_line "$workflow" "emulator-options: -no-window -no-snapshot -gpu swiftshader -feature -Vulkan -noaudio -no-boot-anim -camera-back none -camera-front none -no-metrics"
require_line "$workflow" "-feature -Vulkan"
if grep -Fq -- '-gpu software' "$workflow"; then
  printf 'FAIL: runtime golden baseline still uses generic software GPU mode; use the runner-stable SwiftShader mode.\n' >&2
  exit 1
fi

require_line "$runtime" 'hope_android_app_activity_ready "$RUNTIME_SERIAL" com.hope.marketplace'
require_line "$runtime" "assert_hope_focused talkback-return"
require_line "$runtime" "HOPE_TALKBACK_FOREGROUND_RETURN_FAILED: launcher activity could not be resolved"
require_line "tools/android-runtime-device-recovery.sh" "cmd package resolve-activity --brief"
require_line "tools/android-runtime-device-recovery.sh" "HOPE_APP_ACTIVITY_LAUNCHED:"
require_line "test/runtime/android_runtime_adb_recovery_test.sh" "run_app_activity_recovery_case"
if grep -Fq 'adb shell am start -W -n com.hope.marketplace/.MainActivity' "$runtime"; then
  printf 'FAIL: TalkBack return path must resolve the installed launcher activity instead of hard-coding MainActivity.\\n' >&2
  exit 1
fi

# Screenshot production is locked to the current Flutter integration_test callback path.
driver_file="test_driver/hope_runtime_screenshot_driver.dart"

require_line "$test_file" "var _runtimeScreenshotSurfacePrepared = false;"
require_line "$test_file" "if (_runtimeScreenshotSurfacePrepared) {"
require_line "$test_file" "await binding.convertFlutterSurfaceToImage();"
require_line "$test_file" "_runtimeScreenshotSurfacePrepared = true;"
require_line "$test_file" "required bool forceFreshFrame,"
require_line "$test_file" "required int freshFramesRequired,"
require_line "$test_file" "'forceFreshFrame': forceFreshFrame,"
require_line "$test_file" "'freshFramesRequired': freshFramesRequired,"
require_line "$test_file" "int _runtimeFreshFrameCount(String marker)"
require_line "$test_file" "if (marker.startsWith('register-')) return 2;"
require_line "$test_file" "if (marker.startsWith('password-reset-')) return 1;"
require_line "$test_file" "freshFramesRequired: freshFrameCount,"
require_line "$main_activity" "call.argument<Int>(\"freshFramesRequired\")"
require_line "$main_activity" "freshFramesRequired.coerceIn(1, 2)"

require_line "$test_file" "HOPE_T10_SEMANTICS_ONLY_SCREEN_COMPLETE:"
require_line "$test_file" "'HOPE_T10_SEMANTICS_ONLY',"
require_line "$test_file" "HOPE_SCREENSHOT_CAPTURE_START:"
require_line "$test_file" "HOPE_SCREENSHOT_SOURCE:native-primary:"
require_line "$test_file" "HOPE_SCREENSHOT_READY:"
require_line "$test_file" "IntegrationTestWidgetsFlutterBinding.ensureInitialized();"
require_line "$test_file" "String.fromEnvironment('HOPE_CAPTURE_LOCALE', defaultValue: '')"
require_line "$test_file" "String.fromEnvironment('HOPE_CAPTURE_MODE', defaultValue: 'baseline')"
require_line "$driver_file" "integrationDriver("
require_line "$driver_file" "onScreenshot:"
require_line "$driver_file" "writeAsBytes(image, flush: true)"
require_line "$runtime" 'flutter drive --keep-app-running --no-pub --no-dds --no-enable-impeller'
if ! awk '
/timeout --foreground --signal=TERM/ {
  continued=(substr($0, length($0), 1) == "\\")
  next
}
continued && /flutter drive --keep-app-running --no-pub --no-dds --no-enable-impeller/ {
  found=1
  exit
}
{ continued=0 }
END { exit(found ? 0 : 1) }
' "$runtime"; then
  printf 'FAIL: runtime driver command is not directly continued from timeout; shell command structure drifted.\n' >&2
  exit 1
fi
require_line "$runtime" 'HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT'
require_line "$runtime" 'HOPE_HOST_RUNTIME_DRIVER_FORCE_STOP'
if grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$runtime"; then
  printf 'FAIL: runtime baseline still force-stops the driver after screenshot flush.\n' >&2
  exit 1
fi
require_line "$runtime" 'RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-30}"'
require_line "$runtime" 'HOPE_RUNTIME_DRIVER_BUILD_MODE:self-build'
require_line "$runtime" 'bash tools/hope-disable-talkback.sh'
require_line "$runtime" 'bash tools/hope-enable-talkback.sh'
require_line "$runtime" '--dart-define=HOPE_T10_SEMANTICS_ONLY="${semantics_only}"'
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
require_line "$runtime" 'duplicate-png-hash'
require_line "$runtime" 'validate_semantics_set'
require_line "$runtime" 'validate_scroll_end_set'
require_line "$test_file" "'transaction-detail', 'create-job', 'financial-insights',"
require_line "$runtime" '"financial-insights-$scroll_suffix" "job-satisfaction-$scroll_suffix"'
require_line "$runtime" '"$scroll_end_screens" -ne 10'
require_line "$workflow" 'test "${png_count}" -ge 35'
require_line "$workflow" '.scroll_end_screens == 10'
require_line "$runtime" 'talkback_semantics_mode": "separate_bound_service_pass'
require_line "$runtime" 'HOPE_T10_RESPONSIVE_SEMANTICS_VIEWPORT_BEGIN:720x1280:320dpi'
require_line "$runtime" 'HOPE_T10_RESPONSIVE_SEMANTICS_VIEWPORT_END'

# Preserve full-precision diagnostics for transformed semantics bounds; keep the exact 48dp gate.
require_line "$test_file" "targetBounds.width.toStringAsPrecision(17)"
require_line "$test_file" "targetBounds.height.toStringAsPrecision(17)"
require_line "$test_file" "_semanticsTransformChain(node)"
require_line "$test_file" "rootMatrix="
require_line "$test_file" "const tapTargetBoundsToleranceDp = 1e-6;"
require_line "$test_file" "targetBounds.width < 48 - tapTargetBoundsToleranceDp ||"
require_line "$test_file" "targetBounds.height < 48 - tapTargetBoundsToleranceDp"

echo "PASS: Android runtime screenshot baseline contract is locked."

# [runtime-capture-fa] validate Vulkan-disabled emulator capture after native surface-conversion failure.

# [runtime-capture-fa] re-trigger exact-head Vulkan-disabled transport validation.

# [runtime-capture-fa] current-head rerun after debug transport forensics.

# [runtime-capture-fa] verify aligned baseline/responsive partition contract at exact HEAD.

# [runtime-capture-fa] exact-head runtime validation after baseline/responsive alignment forensic check.
