#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-critical-screens-runtime.log"
active_runtime_log="$log_file"
mkdir -p "$evidence_dir"
rm -f "$log_file"
: > "$log_file"

capture_root="/data/user/0/com.hope.marketplace/files/hope-screen-captures-${GITHUB_RUN_ID}"
export HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root"
export HOPE_DRIVER_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"
ADB_TIMEOUT_SECONDS="${HOPE_ADB_TIMEOUT_SECONDS:-20}"
ADB_KILL_AFTER_SECONDS="${HOPE_ADB_KILL_AFTER_SECONDS:-5}"

adb shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled.txt" 2>&1 || true
adb shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services.txt" 2>&1 || true

set +e
# Use the historical host-driven Flutter Driver path. The external driver keeps
# the VM-service session alive through integrationDriver's final requestData().
flutter drive --no-pub --no-dds \
  --driver=test_driver/hope_runtime_screenshot_driver.dart \
  --target=integration_test/runtime/critical_screens_evidence_test.dart \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
  --dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root" \
  > "$log_file" 2>&1 &
test_pid=$!
set -e

capture_android_diagnostics() {
  local prefix="$1"
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb devices -l > "$evidence_dir/adb-devices-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell pidof com.hope.marketplace > "$evidence_dir/app-pid-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell dumpsys activity activities > "$evidence_dir/activity-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell dumpsys window windows > "$evidence_dir/window-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell logcat -d -t 1000 > "$evidence_dir/logcat-$prefix.txt" 2>&1 || true
}

verify_runtime_screenshot() {
  local marker="$1"
  local output="$2"
  local path="$evidence_dir/$output"
  if ! test -s "$path"; then
    echo "HOPE_HOST_CAPTURE_FAILED:$marker:missing-host-callback-file" >&2
    return 1
  fi

  local screenshot_magic
  screenshot_magic="$(od -An -tx1 -N8 "$path" | tr -d "[:space:]")"
  if [ "$screenshot_magic" != "89504e470d0a1a0a" ]; then
    echo "HOPE_HOST_CAPTURE_FAILED:$marker:invalid-png" >&2
    return 1
  fi

  echo "HOPE_HOST_SCREENSHOT_VERIFIED:$marker"
  return 0
}

verify_runtime_screenshots() {
  local verify_status=0
  for marker in "$@"; do
    verify_runtime_screenshot "$marker" "$marker.png" || verify_status=1
  done
  return "$verify_status"
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

set +e
wait "$test_pid"
baseline_status=$?
set -e

baseline_capture_status=0
verify_runtime_screenshots "${screens[@]}" || baseline_capture_status=$?

if [ "$baseline_status" -ne 0 ]; then
  test_status="$baseline_status"
elif [ "$baseline_capture_status" -ne 0 ]; then
  test_status="$baseline_capture_status"
else
  test_status=0
fi

if [ "$baseline_status" -eq 0 ] && [ "$baseline_capture_status" -eq 0 ]; then
  adb shell wm size 720x1280
  sleep 2
  : > "$runner_temp/hope-responsive-runtime.log"
  active_runtime_log="$runner_temp/hope-responsive-runtime.log"

set +e
HOPE_RESPONSIVE_ONLY=1 flutter drive --no-pub --no-dds \
  --driver=test_driver/hope_runtime_screenshot_driver.dart \
  --target=integration_test/runtime/critical_screens_evidence_test.dart \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
  --dart-define=HOPE_RESPONSIVE_ONLY=true \
  --dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root" \
  > "$runner_temp/hope-responsive-runtime.log" 2>&1 &
responsive_test_pid=$!
test_pid="$responsive_test_pid"
set -e

responsive_screens=(
  "responsive-720x1280-home-fa-rtl"
  "responsive-720x1280-jobs-fa-rtl"
  "responsive-720x1280-job-detail-fa-rtl"
  "responsive-720x1280-transactions-fa-rtl"
  "responsive-720x1280-wallet-fa-rtl"
  "responsive-720x1280-profile-fa-rtl"
  "responsive-720x1280-home-en-ltr"
  "responsive-720x1280-jobs-en-ltr"
  "responsive-720x1280-job-detail-en-ltr"
  "responsive-720x1280-wallet-en-ltr"
  "responsive-720x1280-profile-en-ltr"
  "responsive-720x1280-transactions-en-ltr"
)

set +e
wait "$responsive_test_pid"
responsive_status=$?
set -e

responsive_capture_status=0
verify_runtime_screenshots "${responsive_screens[@]}" || responsive_capture_status=$?

adb shell wm size reset || true
adb shell sleep 1 >/dev/null 2>&1 || true

if [ "$baseline_status" -eq 0 ]; then
  if [ "$responsive_status" -ne 0 ] && [ "$test_status" -eq 0 ]; then
    test_status="$responsive_status"
  elif [ "$responsive_capture_status" -ne 0 ] && [ "$test_status" -eq 0 ]; then
    test_status="$responsive_capture_status"
  fi
else
  responsive_status=1
  responsive_capture_status=1
fi

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
  "theme": "dark",
  "interactive_target_contract": "48px",
  "capture_transport": "flutter_driver_onScreenshot_host_callback_post_test",
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
