#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-wallet-runtime.log"
mkdir -p "$evidence_dir"
rm -f "$log_file"
: > "$log_file"

set +e
stdbuf -oL -eL flutter test --no-pub \
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

capture_android_diagnostics() {
  local prefix="$1"
  adb devices -l > "$evidence_dir/adb-devices-${prefix}.txt" 2>&1 || true
  adb shell pidof com.hope.marketplace > "$evidence_dir/app-pid-${prefix}.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$evidence_dir/activity-${prefix}.txt" 2>&1 || true
  adb shell dumpsys window windows > "$evidence_dir/window-${prefix}.txt" 2>&1 || true
  adb shell logcat -d -t 1000 > "$evidence_dir/logcat-${prefix}.txt" 2>&1 || true
}

assert_hope_focused() {
  local prefix="$1"
  local window_dump="$evidence_dir/window-${prefix}.txt"

  adb shell dumpsys window windows > "$window_dump" 2>&1 || true

  local current_focus
  current_focus="$(grep -E "mCurrentFocus=" "$window_dump" | tail -n 1 || true)"

  if ! grep -q "mCurrentFocus=.*com.hope.marketplace" <<< "$current_focus"; then
    echo "Rendered evidence rejected: HOPE app is not the focused Android window." >&2
    capture_android_diagnostics "$prefix"
    return 1
  fi

  # An Android ANR dialog can itself contain the HOPE package name
  # (e.g. "Application Not Responding: com.hope.marketplace"), so checking only
  # for the package name is insufficient. Reject any visible ANR/error dialog
  # before accepting a screenshot as rendered evidence.
  if grep -qiE "Application Not Responding:|AppErrorDialog|Application Error" "$window_dump"; then
    echo "Rendered evidence rejected: Android reports an ANR/application-error dialog." >&2
    capture_android_diagnostics "$prefix"
    return 1
  fi
}

capture_screen() {
  local marker="$1"
  local output="$2"
  local prefix="$3"
  local timeout_seconds="$4"
  local deadline=$((SECONDS + timeout_seconds))

  while (( SECONDS < deadline )); do
    if grep -q -- "$marker" "$log_file"; then
      adb wait-for-device
      if ! assert_hope_focused "$prefix"; then
        return 1
      fi
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
  capture_android_diagnostics "$prefix-timeout"
  return 1
}

if ! wait_for_marker "HOPE_TEST_STARTED:wallet-fa-rtl" 1200; then
  echo "Timed out waiting for Wallet test body to start." >&2
  capture_android_diagnostics "start-timeout"
  exit 1
fi

capture_screen "HOPE_SCREENSHOT_READY:wallet-fa-rtl" "wallet-fa-rtl.png" "wallet-fa-rtl" 180
capture_screen "HOPE_SCREENSHOT_READY:wallet-en-ltr" "wallet-en-ltr.png" "wallet-en-ltr" 120

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
  "prebuilt_apk": false,
  "test_exit_code": $test_status
}
EOF

cat "$log_file"
exit "$test_status"
