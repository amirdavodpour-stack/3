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
grep -Fq 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script_file"
grep -Fq 'flutter drive --no-pub --no-dds' "$script_file"
if grep -Fq 'wait_for_screenshot_file "$marker"' "$script_file"; then
  echo "FAIL: host must not race each Flutter screenshot callback before test completion" >&2
  exit 1
fi
grep -Fq 'wait_for_screenshot_file' "$script_file"
grep -Fq 'HOPE_HOST_SCREENSHOT_READY' "$script_file"
wait_body="$(sed -n '/^wait_for_screenshot_file()/,/^}/p' "$script_file")"
if [ -z "$wait_body" ]; then
  echo "FAIL: screenshot wait function is missing" >&2
  exit 1
fi
if grep -Fq 'assert_hope_focused' <<<"$wait_body"; then
  echo "FAIL: post-capture focus validation is stale and can inspect a later screen" >&2
  exit 1
fi
if grep -Fq 'assert_hope_rendered' <<<"$wait_body"; then
  echo "FAIL: post-capture draw validation is stale and can inspect a later screen" >&2
  exit 1
fi
if grep -Fq 'adb exec-out screencap -p' "$script_file"; then
  echo "FAIL: host still captures a later framebuffer snapshot" >&2
  exit 1
fi
if grep -Fq 'HOPE_ADB_SCREENSHOT_CAPTURE=true' "$script_file"; then
  echo "FAIL: build still enables retired ADB screenshot mode" >&2
  exit 1
fi

# The Android build itself must also be bounded; otherwise a Gradle stall hides the real runtime state.
grep -Fq 'RUNTIME_BUILD_TIMEOUT_SECONDS="${HOPE_RUNTIME_BUILD_TIMEOUT_SECONDS:-420}"' "$script_file"
build_block="$(sed -n '/^echo "HOPE_RUNTIME_PREBUILD/,/^test -s "$RUNTIME_APK"/p' "$script_file")"
grep -Fq 'timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${RUNTIME_BUILD_TIMEOUT_SECONDS}s"' <<<"$build_block"
grep -Fq 'flutter build apk --debug --no-pub' <<<"$build_block"

# The bounded runtime timeout must wrap the actual Flutter Driver process.
grep -Fq 'RUNTIME_TEST_TIMEOUT_SECONDS="${HOPE_RUNTIME_TEST_TIMEOUT_SECONDS:-180}"' "$script_file"
driver_block="$(sed -n '/^run_host_batch_session()/,/^echo "HOPE_RUNTIME_CAPTURE_LOCALE/p' "$script_file")"
grep -Fq 'timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${RUNTIME_TEST_TIMEOUT_SECONDS}s"' <<<"$driver_block"
grep -Fq 'flutter drive --no-pub --no-dds' <<<"$driver_block"

# Runtime screenshot evidence must explicitly disable custom Flutter animations through MediaQuery.
grep -Fq "disableAnimations: true" "$test_file"
# The current Work Center/Transactions surface uses a bounded fast capture path to avoid a second headless pump deadlock.
# Login is the first auth surface in the baseline and must use the deterministic runtime-only host path.
grep -Fq 'if (child is LoginPage)' "$test_file"
# Responsive evidence is split into two independent Flutter Driver sessions to limit emulator/session pressure.
grep -Fq 'run_host_batch_session responsive-a responsive' "$script_file"
grep -Fq 'run_host_batch_session responsive-b responsive' "$script_file"
grep -Fq 'platformDispatcher.defaultRouteName' "$test_file"
binding_init_line="$(grep -Fn 'IntegrationTestWidgetsFlutterBinding.ensureInitialized();' "$test_file" | head -n1 | cut -d: -f1)"
route_line="$(grep -Fn 'platformDispatcher.defaultRouteName' "$test_file" | head -n1 | cut -d: -f1)"
if [ -z "$binding_init_line" ] || [ -z "$route_line" ] || [ "$route_line" -le "$binding_init_line" ]; then
  echo "FAIL: runtime capture route must be read only after IntegrationTestWidgetsFlutterBinding is initialized" >&2
  exit 1
fi
grep -Fq -- '--route="/__hope_runtime_capture__/$locale/$launch_mode"' "$script_file"
grep -Fq -- '--dart-define=HOPE_RESPONSIVE_ONLY' "$script_file"
grep -Fq -- '--dart-define=HOPE_RESPONSIVE_BATCH' "$script_file"
grep -Fq 'String.fromEnvironment' "$test_file"
grep -Fq 'HOPE_RUNTIME_LOGIN_FAST_SETTLE_DONE:$marker' "$test_file"

grep -Fq 'if (child is TransactionsPage)' "$test_file"
grep -Fq 'HOPE_RUNTIME_TRANSACTION_FAST_SETTLE_DONE:$marker' "$test_file"
grep -Fq 'await tester.pump(const Duration(milliseconds: 1200));' "$test_file"

grep -Fq 'HOPE_RUNTIME_TEST_BODY_COMPLETE' "$script_file"
grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$script_file"
completion_line="$(grep -Fn 'if [ "$completion_status" -eq 0 ]; then' "$script_file" | head -n1 | cut -d: -f1)"
stop_line="$(grep -Fn 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$script_file" | head -n1 | cut -d: -f1)"
flush_line="$(grep -Fn 'HOPE_HOST_SCREENSHOT_FLUSH_COMPLETE' "$script_file" | head -n1 | cut -d: -f1)"
if [ -z "$completion_line" ] || [ -z "$flush_line" ] || [ -z "$stop_line" ] ||
   [ "$flush_line" -le "$completion_line" ] || [ "$stop_line" -le "$flush_line" ]; then
  echo "FAIL: screenshot callbacks must flush after test completion and before driver shutdown" >&2
  exit 1
fi

grep -Fq '"capture_transport": "flutter_integration_test_onScreenshot"' "$script_file"

# The contract must not depend on retired screenKey scaffolding.
if grep -Fq "screenKey: marker" "$test_file"; then
  echo "FAIL: retired screenKey scaffolding still present" >&2
  exit 1
fi

if grep -Fq 'tester.binding.endOfFrame' "$test_file"; then
  echo "FAIL: runtime screenshot harness must not wait on endOfFrame in the headless driver path" >&2
  exit 1
fi

echo "PASS: Flutter rendered-screenshot transport contract"
