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
# Baseline capture is intentionally split into three sessions; baseline-c must
# select only the final three screens instead of silently falling back to all.
grep -Fq 'baseline-c) baseline_batch="c"' "$script_file"
grep -Fq 'HOPE_RUNTIME_TEST_BODY_COMPLETE' "$script_file"
grep -Fq 'HOPE_RUNTIME_WALLET_FAST_SETTLE_DONE' "$test_file"
grep -Fq 'if (child is WalletPage)' "$test_file"
grep -Fq 'HOPE_HOST_SCREENSHOT_FLUSH_COMPLETE' "$script_file"
# Post-completion screenshot flush must not require the driver process to remain alive.
grep -Fq 'screenshot_flush_deadline' "$script_file"
grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$script_file"
grep -Fq '"capture_transport": "flutter_integration_test_onScreenshot"' "$script_file"

echo "PASS: Flutter rendered-screenshot transport contract"
