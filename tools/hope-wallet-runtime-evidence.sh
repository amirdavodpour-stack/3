#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-critical-screens-runtime.log"
active_runtime_log="$log_file"
mkdir -p "$evidence_dir"
rm -f "$log_file"
: > "$log_file"

ADB_TIMEOUT_SECONDS="${HOPE_ADB_TIMEOUT_SECONDS:-20}"
ADB_KILL_AFTER_SECONDS="${HOPE_ADB_KILL_AFTER_SECONDS:-5}"
CAPTURE_CHECK_TIMEOUT_SECONDS="${HOPE_CAPTURE_CHECK_TIMEOUT_SECONDS:-2}"
FOCUS_CHECK_TIMEOUT_SECONDS="${HOPE_FOCUS_CHECK_TIMEOUT_SECONDS:-5}"

adb shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled.txt" 2>&1 || true
adb shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services.txt" 2>&1 || true

set +e
# Track the Flutter PID directly. A background pipeline stores the tee PID in $!,
# which can outlive Flutter and makes timeout/exit detection flaky.
flutter test --no-pub \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
  --dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root" \
  integration_test/runtime/critical_screens_evidence_test.dart \
  -r expanded > "$log_file" 2>&1 &
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

assert_hope_focused() {
  local prefix="$1"
  local window_dump="$evidence_dir/window-$prefix.txt"
  local activity_dump="$evidence_dir/activity-$prefix.txt"
  local focus_deadline=$((SECONDS + FOCUS_CHECK_TIMEOUT_SECONDS))

  while (( SECONDS < focus_deadline )); do
    timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s adb shell dumpsys window windows > "$window_dump" 2>&1 || true
    timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s adb shell dumpsys activity activities > "$activity_dump" 2>&1 || true

    local current_focus
    local top_resumed
    current_focus="$(grep -E "mCurrentFocus=" "$window_dump" | tail -n 1 || true)"
    top_resumed="$(grep -E "topResumedActivity=" "$activity_dump" | tail -n 1 || true)"

    if grep -qiE "Application Not Responding:|AppErrorDialog|Application Error" "$window_dump"; then
      echo "Rendered evidence rejected: Android reports an ANR/application-error dialog." >&2
      capture_android_diagnostics "$prefix"
      return 1
    fi

    if grep -q "mCurrentFocus=.*com.hope.marketplace" <<< "$current_focus" ||
       grep -q "topResumedActivity=.*com.hope.marketplace/.MainActivity" <<< "$top_resumed"; then
      return 0
    fi

    sleep 0.2
  done

  if [ -n "$current_focus" ] &&
     ! grep -q "mCurrentFocus=.*com.hope.marketplace" <<< "$current_focus"; then
    echo "Rendered evidence rejected: HOPE app is not the focused Android window after ${FOCUS_CHECK_TIMEOUT_SECONDS}s." >&2
  else
    echo "Rendered evidence rejected: HOPE MainActivity is not the top resumed Android activity after ${FOCUS_CHECK_TIMEOUT_SECONDS}s." >&2
  fi
  capture_android_diagnostics "$prefix"
  return 1
}

validate_capture_set() {
  local set_name="$1"
  local log_path="$2"
  shift 2

  local marker
  local source
  local screenshot_magic
  for marker in "$@"; do
    if ! grep -Fq -- "HOPE_SCREENSHOT_READY:$marker" "$log_path"; then
      echo "HOPE_HOST_CAPTURE_FAILED:$set_name:$marker:missing-marker" >&2
      return 1
    fi

    source="$evidence_dir/$marker.png"
    if ! test -s "$source"; then
      echo "HOPE_HOST_CAPTURE_FAILED:$set_name:$marker:file-missing" >&2
      return 1
    fi

    screenshot_magic="$(od -An -tx1 -N8 "$source" | tr -d '[:space:]')"
    if [ "$screenshot_magic" != "89504e470d0a1a0a" ]; then
      echo "HOPE_HOST_CAPTURE_FAILED:$set_name:$marker:invalid-png" >&2
      return 1
    fi

    echo "HOPE_HOST_SCREENSHOT_VALIDATED:$marker"
  done

  return 0
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
HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" flutter drive   --no-pub   --no-dds   --driver=test_driver/hope_runtime_screenshot_driver.dart   --target=integration_test/runtime/critical_screens_evidence_test.dart   --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}"   --dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"   > "$log_file" 2>&1
baseline_status=$?
set -e

if [ "$baseline_status" -eq 0 ] &&
   ! validate_capture_set "baseline" "$log_file" "${screens[@]}"; then
  baseline_status=1
fi

if [ "$baseline_status" -ne 0 ]; then
  test_status="$baseline_status"
else
  test_status=0
fi

if [ "$baseline_status" -eq 0 ]; then
  adb shell wm size 720x1280
  sleep 2
  : > "$runner_temp/hope-responsive-runtime.log"

  set +e
  HOPE_RESPONSIVE_ONLY=1 HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" flutter drive     --no-pub     --no-dds     --driver=test_driver/hope_runtime_screenshot_driver.dart     --target=integration_test/runtime/critical_screens_evidence_test.dart     --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}"     --dart-define=HOPE_RESPONSIVE_ONLY=true     --dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"     > "$runner_temp/hope-responsive-runtime.log" 2>&1
  responsive_status=$?
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

  if [ "$responsive_status" -eq 0 ] &&
     ! validate_capture_set "responsive" "$runner_temp/hope-responsive-runtime.log" "${responsive_screens[@]}"; then
    responsive_status=1
  fi

  adb shell wm size reset || true
  adb shell sleep 1 >/dev/null 2>&1 || true

  if [ "$responsive_status" -ne 0 ] && [ "$test_status" -eq 0 ]; then
    test_status="$responsive_status"
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
