#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
test_file="$repo_root/integration_test/runtime/critical_screens_evidence_test.dart"
driver_file="$repo_root/test_driver/hope_runtime_screenshot_driver.dart"
script_file="$repo_root/tools/hope-wallet-runtime-evidence.sh"

grep -Fq 'await binding.takeScreenshot(marker);' "$test_file"
grep -Fq 'HOPE_SCREENSHOT_SOURCE:flutter-driver' "$test_file"
grep -Fq 'onScreenshot:' "$driver_file"
grep -Fq 'writeAsBytes(image, flush: true)' "$driver_file"
grep -Fq 'flutter drive --no-pub --no-dds' "$script_file"
grep -Fq 'HOPE_RUNTIME_DRIVER_BUILD_MODE:self-build' "$script_file"
# Self-build includes Flutter/Gradle compilation before VM-service connection.
grep -Fq 'DRIVER_CONNECT_TIMEOUT_SECONDS="${HOPE_DRIVER_CONNECT_TIMEOUT_SECONDS:-420}"' "$script_file"
grep -Fq 'emulator-options: -no-window -no-snapshot -gpu software' "$repo_root/.github/workflows/hope-ui-runtime-evidence.yml"
if grep -Fq -- '-gpu swiftshader_indirect' "$repo_root/.github/workflows/hope-ui-runtime-evidence.yml"; then
  echo "FAIL: runtime evidence must not use deprecated swiftshader_indirect GPU mode" >&2
  exit 1
fi
grep -Fq ': > "$log_path"' "$script_file"

if grep -Fq -- '--use-application-binary' "$script_file"; then
  echo "FAIL: runtime evidence must not use --use-application-binary" >&2
  exit 1
fi
if grep -Fq -- '--route=' "$script_file"; then
  echo "FAIL: runtime evidence must not use flutter drive route transport" >&2
  exit 1
fi
if grep -Fq 'platformDispatcher.defaultRouteName' "$test_file"; then
  echo "FAIL: runtime evidence must not use Android initial-route transport" >&2
  exit 1
fi
if grep -Fq 'wait_for_screenshot_file' "$script_file"; then
  echo "FAIL: runtime evidence must not poll screenshot files per marker" >&2
  exit 1
fi
if grep -Fq 'adb exec-out screencap -p' "$script_file"; then
  echo "FAIL: runtime evidence must not capture a later ADB framebuffer" >&2
  exit 1
fi
if grep -Fq 'HOPE_SCREENSHOT_SYNC_ROOT' "$test_file"; then
  echo "FAIL: target must not use app-private screenshot sync" >&2
  exit 1
fi

grep -Fq 'String.fromEnvironment' "$test_file"
grep -Fq "String.fromEnvironment('HOPE_CAPTURE_LOCALE', defaultValue: '')" "$test_file"
grep -Fq "String.fromEnvironment('HOPE_CAPTURE_MODE', defaultValue: 'baseline')" "$test_file"
grep -Fq 'IntegrationTestWidgetsFlutterBinding.ensureInitialized();' "$test_file"
grep -Fq -- '--dart-define=HOPE_CAPTURE_LOCALE="${CAPTURE_LOCALE}"' "$script_file"
grep -Fq -- '--dart-define=HOPE_CAPTURE_MODE="${launch_mode}"' "$script_file"
grep -Fq -- '--dart-define=HOPE_CAPTURE_HOME_ONLY="${DART_CAPTURE_HOME_ONLY}"' "$script_file"

grep -Fq 'run_host_batch_session responsive-a' "$script_file"
grep -Fq 'run_host_batch_session responsive-b' "$script_file"
grep -Fq 'run_host_batch_session responsive-c' "$script_file"
grep -Fq 'responsive-c) responsive_batch="3"' "$script_file"
# Baseline capture is partitioned into four sessions; Wallet is isolated in baseline-b.
# Wallet evidence uses direct capture immediately after the completed pumpWidget; no timed settle is required.
grep -Fq 'baseline-c) baseline_batch="c"' "$script_file"
grep -Fq 'run_host_batch_session baseline-d' "$script_file"
grep -Fq 'baseline-d) baseline_batch="d"' "$script_file"
grep -Fq 'baseline_first_screens=("${baseline_screens[@]:0:7}")' "$script_file"
grep -Fq 'baseline_second_screens=("${baseline_screens[@]:7:1}")' "$script_file"
grep -Fq 'baseline_third_screens=("${baseline_screens[@]:8:4}")' "$script_file"
grep -Fq 'baseline_fourth_screens=("${baseline_screens[@]:12:3}")' "$script_file"
grep -Fq 'HOPE_RUNTIME_TEST_BODY_COMPLETE' "$script_file"
grep -Fq 'if (child is WalletPage)' "$test_file"
wallet_block="$(sed -n '/if (child is WalletPage)/,/^[[:space:]]*}/p' "$test_file")"
if grep -Fq 'await tester.pump(const Duration' <<<"$wallet_block"; then
  echo "FAIL: Wallet runtime contract must not drive a timed tester.pump after pumpWidget" >&2
  exit 1
fi
grep -Fq "print('HOPE_RUNTIME_WALLET_DIRECT_CAPTURE:\$marker');" "$test_file"
login_block="$(sed -n '/if (child is LoginPage)/,/^[[:space:]]*}/p' "$test_file")"
if grep -Fq 'await tester.pump(const Duration' <<<"$login_block"; then
  echo "FAIL: Login runtime contract must not drive a timed tester.pump after pumpWidget" >&2
  exit 1
fi
grep -Fq "print('HOPE_RUNTIME_LOGIN_DIRECT_CAPTURE:\$marker');" "$test_file"
# Login must allow Flutter's Android screenshot surface to receive a settled frame before capture.
login_block="$(sed -n '/if (child is LoginPage)/,/^[[:space:]]*}/p' \"$test_file\")"
grep -Fq 'await tester.pumpAndSettle();' <<<\"$login_block\"
grep -Fq 'HOPE_HOST_SCREENSHOT_FLUSH_COMPLETE' "$script_file"
# Post-completion screenshot flush must be followed by normal integration_test driver teardown.
grep -Fq 'screenshot_flush_deadline' "$script_file"
grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT' "$script_file"
grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_FORCE_STOP' "$script_file"
if grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$script_file"; then
  echo "FAIL: runtime evidence still force-stops the driver after screenshot flush" >&2
  exit 1
fi
grep -Fq '"capture_transport": "flutter_integration_test_onScreenshot"' "$script_file"
grep -Fq 'RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-30}"' "$script_file"

echo "PASS: Flutter rendered-screenshot transport contract"
