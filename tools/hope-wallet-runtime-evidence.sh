#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-critical-screens-runtime.log"
mkdir -p "$evidence_dir"
rm -f "$log_file"
: > "$log_file"

ack_dir="$runner_temp/hope-screen-acks"
rm -rf "$ack_dir"
mkdir -p "$ack_dir"

adb shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled.txt" 2>&1 || true
adb shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services.txt" 2>&1 || true

set +e
stdbuf -oL -eL env HOPE_SCREENSHOT_ACK_DIR="$ack_dir" flutter test --no-pub \
  integration_test/runtime/critical_screens_evidence_test.dart \
  -r expanded 2>&1 | tee "$log_file" &
test_pid=$!
set -e

capture_android_diagnostics() {
  local prefix="$1"
  adb devices -l > "$evidence_dir/adb-devices-$prefix.txt" 2>&1 || true
  adb shell pidof com.hope.marketplace > "$evidence_dir/app-pid-$prefix.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$evidence_dir/activity-$prefix.txt" 2>&1 || true
  adb shell dumpsys window windows > "$evidence_dir/window-$prefix.txt" 2>&1 || true
  adb shell logcat -d -t 1000 > "$evidence_dir/logcat-$prefix.txt" 2>&1 || true
}

assert_hope_focused() {
  local prefix="$1"
  local window_dump="$evidence_dir/window-$prefix.txt"

  adb shell dumpsys window windows > "$window_dump" 2>&1 || true
  local current_focus
  current_focus="$(grep -E "mCurrentFocus=" "$window_dump" | tail -n 1 || true)"

  if [ -n "$current_focus" ]; then
    if ! grep -q "mCurrentFocus=.*com.hope.marketplace" <<< "$current_focus"; then
      echo "Rendered evidence rejected: HOPE app is not the focused Android window." >&2
      capture_android_diagnostics "$prefix"
      return 1
    fi
  else
    local activity_dump="$evidence_dir/activity-$prefix.txt"
    adb shell dumpsys activity activities > "$activity_dump" 2>&1 || true
    if ! grep -q "topResumedActivity=.*com.hope.marketplace/.MainActivity" "$activity_dump"; then
      echo "Rendered evidence rejected: HOPE MainActivity is not the top resumed Android activity." >&2
      capture_android_diagnostics "$prefix"
      return 1
    fi
  fi

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
      # Capture as soon as the marker appears. The Flutter harness intentionally
      # holds after the marker, so a long host-side settle delay can let the test
      # advance to the next screen before screencap runs.
      adb wait-for-device
      assert_hope_focused "$prefix"
      adb exec-out screencap -p > "$evidence_dir/$output"
      adb shell rm -f /sdcard/hope-ui-hierarchy.xml >/dev/null 2>&1 || true
      adb shell uiautomator dump /sdcard/hope-ui-hierarchy.xml >/dev/null 2>&1 || true
      adb exec-out cat /sdcard/hope-ui-hierarchy.xml > "$evidence_dir/ui-hierarchy-$prefix.xml" 2>/dev/null || true
      : > "$ack_dir/$marker"
      return 0
    fi

    if ! kill -0 "$test_pid" 2>/dev/null; then
      break
    fi

    sleep 0.2
  done

  echo "Timed out waiting for screenshot marker after ${timeout_seconds}s: $marker" >&2
  capture_android_diagnostics "$prefix-timeout"
  return 1
}

screens=(
  "home-fa-rtl"
  "jobs-fa-rtl"
  "job-detail-fa-rtl"
  "applications-fa-rtl"
  "saved-searches-fa-rtl"
  "transactions-fa-rtl"
  "transaction-detail-fa-rtl"
  "wallet-fa-rtl"
  "profile-fa-rtl"
  "notifications-fa-rtl"
  "offers-fa-rtl"
  "create-job-fa-rtl"
  "login-fa-rtl"
  "register-fa-rtl"
  "password-reset-fa-rtl"
  "home-en-ltr"
  "jobs-en-ltr"
  "job-detail-en-ltr"
  "applications-en-ltr"
  "saved-searches-en-ltr"
  "transactions-en-ltr"
  "transaction-detail-en-ltr"
  "wallet-en-ltr"
  "profile-en-ltr"
  "notifications-en-ltr"
  "offers-en-ltr"
  "create-job-en-ltr"
  "login-en-ltr"
  "register-en-ltr"
  "password-reset-en-ltr"
)

first_marker_timeout=900

for index in "${!screens[@]}"; do
  marker="${screens[$index]}"
  timeout_seconds=120
  if [ "$index" -eq 0 ]; then
    timeout_seconds="$first_marker_timeout"
  fi
  capture_screen "HOPE_SCREENSHOT_READY:$marker" "$marker.png" "$marker" "$timeout_seconds"
done

set +e
wait "$test_pid"
baseline_status=$?
set -e

if [ "$baseline_status" -ne 0 ]; then
  test_status="$baseline_status"
else
  test_status=0
fi

if [ "$baseline_status" -eq 0 ]; then
  adb shell wm size 720x1280
  sleep 2
  rm -rf "$ack_dir"
  mkdir -p "$ack_dir"
  : > "$runner_temp/hope-responsive-runtime.log"

set +e
HOPE_RESPONSIVE_ONLY=1 stdbuf -oL -eL env HOPE_SCREENSHOT_ACK_DIR="$ack_dir" flutter test --no-pub \
  integration_test/runtime/critical_screens_evidence_test.dart \
  -r expanded 2>&1 | tee -a "$log_file" "$runner_temp/hope-responsive-runtime.log" &
responsive_test_pid=$!
test_pid="$responsive_test_pid"
set -e

responsive_screens=(
  "responsive-720x1280-home-fa-rtl"
  "responsive-720x1280-jobs-fa-rtl"
  "responsive-720x1280-job-detail-fa-rtl"
  "responsive-720x1280-wallet-fa-rtl"
  "responsive-720x1280-profile-fa-rtl"
  "responsive-720x1280-transactions-fa-rtl"
  "responsive-720x1280-home-en-ltr"
  "responsive-720x1280-jobs-en-ltr"
  "responsive-720x1280-job-detail-en-ltr"
  "responsive-720x1280-wallet-en-ltr"
  "responsive-720x1280-profile-en-ltr"
  "responsive-720x1280-transactions-en-ltr"
)

for marker in "${responsive_screens[@]}"; do
  capture_screen "HOPE_SCREENSHOT_READY:$marker" "$marker.png" "$marker" 180
done

set +e
wait "$responsive_test_pid"
responsive_status=$?
set -e

adb shell wm size reset || true
adb shell sleep 1 >/dev/null 2>&1 || true

if [ "$baseline_status" -eq 0 ]; then
  if [ "$responsive_status" -ne 0 ] && [ "$test_status" -eq 0 ]; then
    test_status="$responsive_status"
  fi
else
  responsive_status=1
fi

adb shell getprop ro.build.version.release > "$evidence_dir/android-version.txt" 2>&1 || true
adb shell getprop ro.product.model > "$evidence_dir/device-model.txt" 2>&1 || true
adb shell wm size > "$evidence_dir/viewport.txt" 2>&1 || true
printf '%s\n' '720x1280' > "$evidence_dir/responsive-viewport.txt"

cat > "$evidence_dir/metadata.json" <<EOF
{
  "workflow": "$GITHUB_WORKFLOW",
  "run_id": "$GITHUB_RUN_ID",
  "ref": "$GITHUB_REF_NAME",
  "sha": "$GITHUB_SHA",
  "evidence_type": "rendered_android_runtime",
  "screens": 30,
  "responsive_screens": 12,
  "responsive_viewport": "720x1280",
  "locales": ["fa-RTL", "en-LTR"],
  "theme": "light",
  "interactive_target_contract": "48px",
  "prebuilt_apk": false,
  "test_exit_code": $test_status,
  "screen_set": [
    "HomePage",
    "JobsPage",
    "JobDetailPage",
    "MyApplicationsPage",
    "SavedSearchesPage",
    "TransactionsPage",
    "TransactionPage",
    "WalletPage",
    "ProfilePage",
    "NotificationsPage",
    "OffersPage",
    "CreateJobPage",
    "LoginPage",
    "RegisterPage",
    "PasswordResetPage"
  ]
}
EOF

cat "$log_file"
exit "$test_status"
