#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-wallet-runtime.log"
apk="${HOPE_PREBUILT_APK:-${GITHUB_WORKSPACE:-$PWD}/build/app/outputs/flutter-apk/app-debug.apk}"

mkdir -p "$evidence_dir"
rm -f "$log_file"
: > "$log_file"

if [[ ! -s "$apk" ]]; then
  echo "Prebuilt APK is missing or empty: $apk" >&2
  exit 2
fi

set +e
stdbuf -oL -eL flutter test --no-pub \
  --use-application-binary="$apk" \
  integration_test/runtime/wallet_surface_evidence_test.dart \
  -r expanded 2>&1 | tee "$log_file" &
test_pid=$!
set -e

wait_for_marker() {
  local marker="$1"
  local timeout_seconds="$2"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if grep -q -- "$marker" "$log_file"; then
      return 0
    fi

    if ! kill -0 "$test_pid" 2>/dev/null; then
      break
    fi

    sleep 2
  done

  return 1
}

capture_screen() {
  local marker="$1"
  local output="$2"
  local timeout_seconds="$3"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if grep -q -- "$marker" "$log_file"; then
      adb wait-for-device
      adb exec-out screencap -p > "$evidence_dir/$output"
      return 0
    fi

    if ! kill -0 "$test_pid" 2>/dev/null; then
      break
    fi

    sleep 2
  done

  echo "Timed out waiting for screenshot marker after ${timeout_seconds}s: $marker" >&2
  echo "Collecting Android diagnostics before emulator cleanup..." >&2
  adb devices -l > "$evidence_dir/adb-devices-timeout.txt" 2>&1 || true
  adb shell pidof com.hope.marketplace > "$evidence_dir/app-pid-timeout.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$evidence_dir/activity-timeout.txt" 2>&1 || true
  adb shell logcat -d -t 1000 > "$evidence_dir/logcat-timeout.txt" 2>&1 || true
  return 1
}

if ! wait_for_marker "HOPE_TEST_STARTED:wallet-fa-rtl" 300; then
  echo "Timed out waiting for Wallet test body to start." >&2
  adb devices -l > "$evidence_dir/adb-devices-start-timeout.txt" 2>&1 || true
  adb shell pidof com.hope.marketplace > "$evidence_dir/app-pid-start-timeout.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$evidence_dir/activity-start-timeout.txt" 2>&1 || true
  adb shell logcat -d -t 1000 > "$evidence_dir/logcat-start-timeout.txt" 2>&1 || true
  exit 1
fi

capture_screen "HOPE_SCREENSHOT_READY:wallet-fa-rtl" "wallet-fa-rtl.png" 180
capture_screen "HOPE_SCREENSHOT_READY:wallet-en-ltr" "wallet-en-ltr.png" 120

set +e
wait "$test_pid"
test_status=$?
set -e

adb shell getprop ro.build.version.release > "$evidence_dir/android-version.txt"
adb shell getprop ro.product.model > "$evidence_dir/device-model.txt"
adb shell wm size > "$evidence_dir/viewport.txt"

cat > "$evidence_dir/metadata.json" <<EOF
{
  "workflow": "$GITHUB_WORKFLOW",
  "run_id": "$GITHUB_RUN_ID",
  "ref": "$GITHUB_REF_NAME",
  "sha": "$GITHUB_SHA",
  "surface": "WalletPage",
  "evidence_type": "rendered_android_runtime",
  "locales": ["fa-RTL", "en-LTR"],
  "theme": "light",
  "interactive_target_contract": "48px",
  "prebuilt_apk": true,
  "test_exit_code": $test_status
}
EOF

cat "$log_file"
exit "$test_status"
