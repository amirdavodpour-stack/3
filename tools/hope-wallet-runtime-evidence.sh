#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-critical-screens-runtime.log"
mkdir -p "$evidence_dir"
rm -f "$log_file"
: > "$log_file"

ADB_TIMEOUT_SECONDS="${HOPE_ADB_TIMEOUT_SECONDS:-20}"
ADB_KILL_AFTER_SECONDS="${HOPE_ADB_KILL_AFTER_SECONDS:-5}"
DRIVER_CONNECT_TIMEOUT_SECONDS="${HOPE_DRIVER_CONNECT_TIMEOUT_SECONDS:-900}"
RUNTIME_TEST_TIMEOUT_SECONDS="${HOPE_RUNTIME_TEST_TIMEOUT_SECONDS:-900}"
RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-15}"
CAPTURE_LOCALE="${HOPE_CAPTURE_LOCALE:-}"

case "$CAPTURE_LOCALE" in
  fa|en) ;;
  *)
    echo "Unsupported HOPE_CAPTURE_LOCALE: $CAPTURE_LOCALE" >&2
    exit 2
    ;;
esac

adb shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled.txt" 2>&1 || true
adb shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services.txt" 2>&1 || true

capture_android_diagnostics() {
  local prefix="$1"
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb devices -l > "$evidence_dir/adb-devices-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell pidof com.hope.marketplace > "$evidence_dir/app-pid-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell dumpsys activity activities > "$evidence_dir/activity-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell dumpsys window windows > "$evidence_dir/window-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell logcat -d -t 1000 > "$evidence_dir/logcat-$prefix.txt" 2>&1 || true
}


wait_for_driver_connection() {
  local process_pid="$1"
  local log_path="$2"
  local deadline=$((SECONDS + DRIVER_CONNECT_TIMEOUT_SECONDS))

  while (( SECONDS < deadline )); do
    if grep -Fq -- 'VMServiceFlutterDriver: Connected to Flutter application.' "$log_path"; then
      return 0
    fi
    if ! kill -0 "$process_pid" 2>/dev/null; then
      echo "HOPE_HOST_DRIVER_FAILED:process-exited-before-driver-connection" >&2
      return 1
    fi
    sleep 0.2
  done

  echo "HOPE_HOST_DRIVER_FAILED:driver-connection-timeout" >&2
  capture_android_diagnostics "driver-connect"
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

baseline_screens=("${screens[@]}")
if [ "$CAPTURE_LOCALE" = "fa" ]; then
  baseline_screens=("${screens[@]:0:15}")
elif [ "$CAPTURE_LOCALE" = "en" ]; then
  baseline_screens=("${screens[@]:15:15}")
fi

run_en_host_session() {
  local mode="$1"
  shift
  local log_path="$log_file"
  [ "$mode" = "responsive" ] && log_path="$runner_temp/hope-responsive-runtime.log"
  local driver_status=0
  local timeout_seconds="$RUNTIME_TEST_TIMEOUT_SECONDS"
  set +e

  if [ "$mode" = "responsive" ]; then
    timeout --foreground --signal=TERM --kill-after=30s "${timeout_seconds}s" \
      env HOPE_CAPTURE_LOCALE="$CAPTURE_LOCALE" \
        HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" \
        flutter drive --no-pub --no-dds \
        --driver=test_driver/hope_runtime_screenshot_driver.dart \
        --target=integration_test/runtime/critical_screens_evidence_test.dart \
        --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
        --dart-define=HOPE_CAPTURE_LOCALE="$CAPTURE_LOCALE" \
        --dart-define=HOPE_RESPONSIVE_ONLY=true \
        > "$log_path" 2>&1
    driver_status=$?
  else
    timeout --foreground --signal=TERM --kill-after=30s "${timeout_seconds}s" \
      env HOPE_CAPTURE_LOCALE="$CAPTURE_LOCALE" \
        HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" \
        flutter drive --no-pub --no-dds \
        --driver=test_driver/hope_runtime_screenshot_driver.dart \
        --target=integration_test/runtime/critical_screens_evidence_test.dart \
        --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
        --dart-define=HOPE_CAPTURE_LOCALE="$CAPTURE_LOCALE" \
        > "$log_path" 2>&1
    driver_status=$?
  fi

  set -e

  # integration_test's extended driver receives screenshot bytes from
  # reportData only after the integration test has completed; therefore the
  # host must not block the Flutter test waiting for individual screenshot files.
  if [ "$driver_status" -ne 0 ]; then
    echo "HOPE_HOST_RUNTIME_DRIVER_FAILED:exit=$driver_status" >&2
    capture_android_diagnostics "${mode}-driver"
    return "$driver_status"
  fi

  return 0
}

baseline_status=0
run_en_host_session baseline "${baseline_screens[@]}" || baseline_status=$?
if [ "$baseline_status" -eq 0 ] &&
   ! validate_capture_set "baseline-$CAPTURE_LOCALE" "$log_file" "${baseline_screens[@]}"; then
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

  responsive_status=0
  if [ "$CAPTURE_LOCALE" = "en" ]; then
    run_en_host_session responsive       "responsive-720x1280-home-en-ltr"       "responsive-720x1280-jobs-en-ltr"       "responsive-720x1280-job-detail-en-ltr"       "responsive-720x1280-wallet-en-ltr"       "responsive-720x1280-profile-en-ltr"       "responsive-720x1280-transactions-en-ltr" || responsive_status=$?
  else
    run_en_host_session responsive       "responsive-720x1280-home-fa-rtl"       "responsive-720x1280-jobs-fa-rtl"       "responsive-720x1280-job-detail-fa-rtl"       "responsive-720x1280-transactions-fa-rtl"       "responsive-720x1280-wallet-fa-rtl"       "responsive-720x1280-profile-fa-rtl" || responsive_status=$?
  fi
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

  responsive_target_screens=("${responsive_screens[@]}")
  if [ "$CAPTURE_LOCALE" = "fa" ]; then
    responsive_target_screens=("${responsive_screens[@]:0:6}")
  elif [ "$CAPTURE_LOCALE" = "en" ]; then
    responsive_target_screens=("${responsive_screens[@]:6:6}")
  fi

  if [ "$responsive_status" -eq 0 ] &&
     ! validate_capture_set "responsive-$CAPTURE_LOCALE" "$runner_temp/hope-responsive-runtime.log" "${responsive_target_screens[@]}"; then
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

if [ "$CAPTURE_LOCALE" = "fa" ]; then
  CAPTURED_BASELINE_SCREENS=15
  CAPTURED_RESPONSIVE_SCREENS=6
  CAPTURED_LOCALE_LABEL="fa-RTL"
elif [ "$CAPTURE_LOCALE" = "en" ]; then
  CAPTURED_BASELINE_SCREENS=15
  CAPTURED_RESPONSIVE_SCREENS=6
  CAPTURED_LOCALE_LABEL="en-LTR"
else
  CAPTURED_BASELINE_SCREENS=30
  CAPTURED_RESPONSIVE_SCREENS=12
  CAPTURED_LOCALE_LABEL="fa-RTL,en-LTR"
fi

cat > "$evidence_dir/metadata.json" <<EOF
{
  "workflow": "$GITHUB_WORKFLOW",
  "run_id": "$GITHUB_RUN_ID",
  "ref": "$GITHUB_REF_NAME",
  "sha": "$GITHUB_SHA",
  "evidence_type": "rendered_android_runtime",
  "screens": $CAPTURED_BASELINE_SCREENS,
  "responsive_screens": $CAPTURED_RESPONSIVE_SCREENS,
  "responsive_viewport": "720x1280",
  "capture_locale": "$CAPTURE_LOCALE",
  "locales": ["$CAPTURED_LOCALE_LABEL"],
  "theme": "dark",
  "interactive_target_contract": "48px",
  "capture_transport": "integration_test_binding_takeScreenshot_driver_onScreenshot",
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
