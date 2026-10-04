#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-critical-screens-runtime.log"
mkdir -p "$evidence_dir"
rm -f "$log_file"
: > "$log_file"

RUNTIME_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
export ANDROID_SERIAL="$RUNTIME_SERIAL"
source "${GITHUB_WORKSPACE:-$PWD}/tools/android-runtime-device-recovery.sh"
hope_android_device_ready "$RUNTIME_SERIAL"

ADB_TIMEOUT_SECONDS="${HOPE_ADB_TIMEOUT_SECONDS:-20}"
ADB_KILL_AFTER_SECONDS="${HOPE_ADB_KILL_AFTER_SECONDS:-5}"
SCREENSHOT_FRESHNESS_TIMEOUT_SECONDS="${HOPE_SCREENSHOT_FRESHNESS_TIMEOUT_SECONDS:-60}"
FOCUS_CHECK_TIMEOUT_SECONDS="${HOPE_FOCUS_CHECK_TIMEOUT_SECONDS:-8}"
DRAW_CHECK_TIMEOUT_SECONDS="${HOPE_DRAW_CHECK_TIMEOUT_SECONDS:-20}"
# Self-build can spend most of its startup budget in Gradle before VM-service appears.
# Proven prior baseline: assembleDebug reached ~297s on this runner profile.
DRIVER_CONNECT_TIMEOUT_SECONDS="${HOPE_DRIVER_CONNECT_TIMEOUT_SECONDS:-420}"
RUNTIME_TEST_TIMEOUT_SECONDS="${HOPE_RUNTIME_TEST_TIMEOUT_SECONDS:-900}"
RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-10}"
CAPTURE_LOCALE="${HOPE_CAPTURE_LOCALE:-}"
STRICT_RUNTIME_VALIDATION="${HOPE_RUNTIME_STRICT_VALIDATION:-0}"
CAPTURE_HOME_ONLY="${HOPE_CAPTURE_HOME_ONLY:-0}"
CAPTURE_AUTH_ONLY="${HOPE_CAPTURE_AUTH_ONLY:-0}"
SCREEN_INDEX="${HOPE_SCREEN_INDEX:--1}"
# bool.fromEnvironment only treats the string "true" as true. The workflow
# contract uses 1/0 for shell semantics, so normalize before passing it to Dart.
DART_CAPTURE_HOME_ONLY="false"
DART_CAPTURE_AUTH_ONLY="false"
if [ "$CAPTURE_AUTH_ONLY" = "1" ]; then
  DART_CAPTURE_AUTH_ONLY="true"
fi
if [ "$CAPTURE_HOME_ONLY" = "1" ]; then
  DART_CAPTURE_HOME_ONLY="true"
fi

case "$CAPTURE_LOCALE" in
  fa|en) ;;
  *)
    echo "Unsupported HOPE_CAPTURE_LOCALE: $CAPTURE_LOCALE" >&2
    exit 2
    ;;
esac

echo "HOPE_RUNTIME_DRIVER_BUILD_MODE:self-build"

adb shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled.txt" 2>&1 || true
adb shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services.txt" 2>&1 || true

capture_android_diagnostics() {
  local prefix="$1"
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb devices -l > "$evidence_dir/adb-devices-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb server-status > "$evidence_dir/adb-server-status-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell pidof com.hope.marketplace > "$evidence_dir/app-pid-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell dumpsys activity activities > "$evidence_dir/activity-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell dumpsys window windows > "$evidence_dir/window-$prefix.txt" 2>&1 || true
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" adb shell logcat -d -t 1000 > "$evidence_dir/logcat-$prefix.txt" 2>&1 || true
}


recover_external_android_error_dialog() {
  local prefix="$1"
  local window_dump="$evidence_dir/window-$prefix.txt"
  local error_package
  error_package="$(grep -E 'Application Not Responding:|Application Error:' "$window_dump" |
    sed -nE 's/.*Application (Not Responding|Error):[[:space:]]*([^[:space:]}]+).*/\2/p' |
    tail -n 1 || true)"

  if [ -z "$error_package" ]; then
    return 0
  fi

  if [ "$error_package" = "com.hope.marketplace" ]; then
    echo "Rendered evidence rejected: HOPE reports an Android ANR/application-error dialog." >&2
    return 1
  fi

  echo "HOPE_HOST_CAPTURE_EXTERNAL_ERROR_DIALOG:$prefix:$error_package"
  timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s \
    "$ADB_TIMEOUT_SECONDS"s adb shell input keyevent KEYCODE_BACK >/dev/null 2>&1 || true
  sleep 0.5
  return 0
}

assert_hope_focused() {
  local prefix="$1"
  local window_dump="$evidence_dir/window-$prefix.txt"
  local activity_dump="$evidence_dir/activity-$prefix.txt"
  local focus_deadline=$((SECONDS + FOCUS_CHECK_TIMEOUT_SECONDS))

  while (( SECONDS < focus_deadline )); do
    timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s \
      adb shell dumpsys window windows > "$window_dump" 2>&1 || true
    timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s \
      adb shell dumpsys activity activities > "$activity_dump" 2>&1 || true

    local current_focus
    local top_resumed
    current_focus="$(grep -E "mCurrentFocus=" "$window_dump" | tail -n 1 || true)"
    top_resumed="$(grep -E "topResumedActivity=" "$activity_dump" | tail -n 1 || true)"

    if ! recover_external_android_error_dialog "$prefix"; then
      capture_android_diagnostics "$prefix"
      return 1
    fi

    if grep -q "mCurrentFocus=.*com.hope.marketplace" <<< "$current_focus" ||
       grep -q "topResumedActivity=.*com.hope.marketplace/.MainActivity" <<< "$top_resumed"; then
      return 0
    fi

    sleep 0.2
  done

  echo "Rendered evidence rejected: HOPE app/MainActivity did not become focused/top-resumed within $FOCUS_CHECK_TIMEOUT_SECONDS seconds." >&2
  capture_android_diagnostics "$prefix"
  return 1
}

assert_hope_rendered() {
  local prefix="$1"
  local window_dump="$evidence_dir/window-$prefix.txt"
  local activity_dump="$evidence_dir/activity-$prefix.txt"
  local draw_deadline=$((SECONDS + DRAW_CHECK_TIMEOUT_SECONDS))

  while (( SECONDS < draw_deadline )); do
    timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s \
      adb shell dumpsys window windows > "$window_dump" 2>&1 || true
    timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s \
      adb shell dumpsys activity activities > "$activity_dump" 2>&1 || true

    local main_window
    local splash_window
    main_window="$(awk '/Window #[0-9]+ Window\{.*com\.hope\.marketplace\/com\.hope\.marketplace\.MainActivity\}/{flag=1; next} /^  Window #[0-9]+ /{if(flag){exit}} flag{print}' "$window_dump")"
    splash_window="$(awk '/Window #[0-9]+ Window\{.*Splash Screen com\.hope\.marketplace/{flag=1; next} /^  Window #[0-9]+ /{if(flag){exit}} flag{print}' "$window_dump")"

    if grep -q "packageName=com.hope.marketplace processName=com.hope.marketplace" "$activity_dump" \
       && grep -q "reportedDrawn=true reportedVisible=true" "$activity_dump" \
       && grep -q "Surface: shown=true" <<< "$main_window" \
       && ! grep -q "Surface: shown=true" <<< "$splash_window" \
       && ! grep -q "isVisible=true" <<< "$splash_window"; then
      return 0
    fi

    if ! recover_external_android_error_dialog "$prefix"; then
      capture_android_diagnostics "$prefix"
      return 1
    fi

    sleep 0.2
  done

  echo "Rendered evidence rejected: MainActivity remained behind the Android splash/was not fully drawn." >&2
  capture_android_diagnostics "$prefix"
  return 1
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
  local screenshot_hash
  declare -A seen_screenshot_hashes=()

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

    screenshot_hash="$(sha256sum "$source" | awk '{print $1}')"
    if [ -n "${seen_screenshot_hashes[$screenshot_hash]+x}" ]; then
      echo "HOPE_HOST_CAPTURE_FAILED:$set_name:$marker:duplicate-png-hash:$screenshot_hash:matches:${seen_screenshot_hashes[$screenshot_hash]}" >&2
      return 1
    fi
    seen_screenshot_hashes[$screenshot_hash]="$marker"
    echo "HOPE_HOST_SCREENSHOT_VALIDATED:$marker:$screenshot_hash"
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
  "jobs-en-ltr"  "job-detail-en-ltr"
  "applications-en-ltr"  "saved-searches-en-ltr"
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
if [ "$CAPTURE_HOME_ONLY" = "1" ]; then
  baseline_screens=("home-${CAPTURE_LOCALE}-rtl")
elif [ "$CAPTURE_AUTH_ONLY" = "1" ]; then
  if [ "$CAPTURE_LOCALE" = "fa" ]; then
    baseline_screens=("login-fa-rtl" "register-fa-rtl" "password-reset-fa-rtl")
  else
    baseline_screens=("login-en-ltr" "register-en-ltr" "password-reset-en-ltr")
  fi
elif [ "$CAPTURE_LOCALE" = "fa" ]; then
  baseline_screens=("${screens[@]:0:15}")
elif [ "$CAPTURE_LOCALE" = "en" ]; then
  baseline_screens=("${screens[@]:15:15}")
fi

run_host_batch_session() {
  local mode="$1"
  shift
  local -a markers=("$@")
  local log_path="$runner_temp/hope-$mode-runtime.log"
  local launch_mode="$mode"
  local responsive_only="false"
  local responsive_batch="all"
  local baseline_batch="all"
  case "$mode" in
    baseline-a) baseline_batch="a" ;;
    baseline-b) baseline_batch="b" ;;
    auth-only) launch_mode="auth-only" ;;
  esac
  if [ "$mode" = "responsive-a" ] || [ "$mode" = "responsive-b" ] || [ "$mode" = "responsive-single" ]; then
    responsive_only="true"
    case "$mode" in
      responsive-a) responsive_batch="1" ;;
      responsive-b) responsive_batch="2" ;;
      responsive-single) responsive_batch="all" ;;
    esac
  elif [ "$CAPTURE_HOME_ONLY" = "1" ] && [ "$mode" = "baseline" ]; then
    launch_mode="home-only"
  fi
  local process_pid
  local tail_pid
  local driver_status=0
  local capture_status=0

  # Pre-create the logfile before starting the background process so the log follower
  # cannot race the child shell's redirection and fail with ENOENT.
  mkdir -p "$runner_temp"
  : > "$log_path"

  # One Flutter Driver session owns the configured capture set. Isolated modes
  # use SCREEN_INDEX to capture exactly one page, limiting VM-service/Android
  # surface lifetime while retaining the official integration_test transport.
  set +e
  export HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"
  HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" \
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${RUNTIME_TEST_TIMEOUT_SECONDS}s" \
  flutter drive --no-pub --no-dds \
    --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
    --dart-define=HOPE_CAPTURE_LOCALE="${CAPTURE_LOCALE}" \
    --dart-define=HOPE_CAPTURE_HOME_ONLY="${DART_CAPTURE_HOME_ONLY}" \
    --dart-define=HOPE_CAPTURE_AUTH_ONLY="${DART_CAPTURE_AUTH_ONLY}" \
    --dart-define=HOPE_CAPTURE_MODE="${launch_mode}" \
    --dart-define=HOPE_BASELINE_BATCH="${baseline_batch}" \
    --dart-define=HOPE_RESPONSIVE_ONLY="${responsive_only}" \
    --dart-define=HOPE_RESPONSIVE_BATCH="${responsive_batch}" \
    --dart-define=HOPE_SCREEN_INDEX="${SCREEN_INDEX}" \
    --driver=test_driver/hope_runtime_screenshot_driver.dart \
    --target=integration_test/runtime/critical_screens_evidence_test.dart \
    >"$log_path" 2>&1 &
  process_pid=$!
  tail -n +1 -f "$log_path" &
  tail_pid=$!
  set -e

  if ! wait_for_driver_connection "$process_pid" "$log_path"; then
    capture_status=1
    echo "HOPE_HOST_RUNTIME_SESSION_TIMEOUT:driver-connect:$mode" >&2
    kill "$process_pid" >/dev/null 2>&1 || true
  else
    # integration_test's onScreenshot callback owns the host-side PNG write.
    # Waiting on each marker here creates a race with the Flutter Driver
    # command/response cycle. The final capture-set validator below checks all
    # expected files after the test body reports completion.
    :
  fi

  local completion_status=1
  local completion_deadline=$((SECONDS + 60))
  while (( SECONDS < completion_deadline )); do
    if grep -Fq -- 'HOPE_RUNTIME_TEST_BODY_COMPLETE' "$log_path"; then
      completion_status=0
      break
    fi
    if ! kill -0 "$process_pid" 2>/dev/null; then break; fi
    sleep 0.2
  done

  if [ "$completion_status" -ne 0 ]; then
    echo "HOPE_HOST_RUNTIME_COMPLETE_FAILED:test-body-complete-timeout:$mode" >&2
    capture_status=1
  fi

  if [ "$completion_status" -eq 0 ]; then
    # The official integration_test driver processes screenshot payloads after
    # the test result/no-op response is returned. Wait for the host files to be
    # written before terminating the driver; otherwise screenshots can be lost
    # even though the Flutter test body completed successfully.
    local screenshot_flush_deadline=$((SECONDS + SCREENSHOT_FRESHNESS_TIMEOUT_SECONDS))
    local screenshot_flush_status=1
    while (( SECONDS < screenshot_flush_deadline )); do
      screenshot_flush_status=0
      for marker in "${markers[@]}"; do
        if ! test -s "$evidence_dir/$marker.png"; then
          screenshot_flush_status=1
          break
        fi
      done
      if [ "$screenshot_flush_status" -eq 0 ]; then
        echo "HOPE_HOST_SCREENSHOT_FLUSH_COMPLETE:$mode"
        break
      fi
      if ! kill -0 "$process_pid" 2>/dev/null; then
        screenshot_flush_status=1
        break
      fi
      sleep 0.2
    done
    if [ "$screenshot_flush_status" -ne 0 ]; then
      echo "HOPE_HOST_SCREENSHOT_FLUSH_FAILED:$mode" >&2
      capture_status=1
    fi
    echo "HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE:$mode"
    kill "$process_pid" >/dev/null 2>&1 || true
  fi

  local shutdown_deadline=$((SECONDS + RUNTIME_SHUTDOWN_GRACE_SECONDS))
  while kill -0 "$process_pid" 2>/dev/null; do
    if (( SECONDS >= shutdown_deadline )); then
      echo "HOPE_HOST_RUNTIME_SESSION_TIMEOUT:driver-shutdown:$mode" >&2
      kill -KILL "$process_pid" >/dev/null 2>&1 || true
      driver_status=124
      break
    fi
    sleep 0.2
  done

  if [ "$driver_status" -eq 0 ]; then
    set +e
    wait "$process_pid"
    driver_status=$?
    set -e
    if [ "$completion_status" -eq 0 ] && { [ "$driver_status" -eq 0 ] || [ "$driver_status" -eq 143 ] || [ "$driver_status" -eq 130 ]; }; then
      driver_status=0
    fi
  fi

  kill "$tail_pid" >/dev/null 2>&1 || true
  wait "$tail_pid" >/dev/null 2>&1 || true

  if [ "$driver_status" -ne 0 ]; then
    echo "HOPE_HOST_RUNTIME_DRIVER_FAILED:exit=$driver_status:mode=$mode" >&2
    capture_android_diagnostics "$mode"
    return "$driver_status"
  fi
  return "$capture_status"
}
echo "HOPE_RUNTIME_CAPTURE_LOCALE:$CAPTURE_LOCALE"
baseline_status=0
if [ "$CAPTURE_HOME_ONLY" = "1" ]; then
  SCREEN_INDEX=0
  session_status=0
  run_host_batch_session baseline-single "${baseline_screens[@]}" || session_status=$?
  if [ "$session_status" -eq 0 ] &&
     ! validate_capture_set "baseline-$CAPTURE_LOCALE" "$runner_temp/hope-baseline-single-runtime.log" "${baseline_screens[@]}"; then
    session_status=1
  fi
  baseline_status="$session_status"
else
  for SCREEN_POSITION in "${!baseline_screens[@]}"; do
    marker="${baseline_screens[$SCREEN_POSITION]}"
    if [ "$CAPTURE_AUTH_ONLY" = "1" ]; then
      case "$marker" in
        login-*) SCREEN_INDEX=12 ;;
        register-*) SCREEN_INDEX=13 ;;
        password-reset-*) SCREEN_INDEX=14 ;;
        *) SCREEN_INDEX="$SCREEN_POSITION" ;;
      esac
    else
      SCREEN_INDEX="$SCREEN_POSITION"
    fi
    session_status=0
    run_host_batch_session "$([ "$CAPTURE_AUTH_ONLY" = "1" ] && echo auth-only || echo baseline-single)" "$marker" || session_status=$?
    if [ "$session_status" -eq 0 ] &&
       ! validate_capture_set "baseline-$CAPTURE_LOCALE-$SCREEN_INDEX" "$runner_temp/hope-baseline-single-runtime.log" "$marker"; then
      session_status=1
    fi
    if [ "$session_status" -ne 0 ]; then
      baseline_status="$session_status"
      break
    fi
    hope_android_device_ready "$RUNTIME_SERIAL" || true
  done
fi

if [ "$baseline_status" -ne 0 ]; then
  test_status="$baseline_status"
else
  test_status=0
fi

if [ "$baseline_status" -eq 0 ] && [ "$CAPTURE_HOME_ONLY" != "1" ] && [ "$CAPTURE_AUTH_ONLY" != "1" ]; then
  adb shell wm size 720x1280
  sleep 2
  : > "$runner_temp/hope-responsive-runtime.log"

  responsive_status=0
  if [ "$CAPTURE_LOCALE" = "en" ]; then
    responsive_session_screens=(
      "responsive-720x1280-home-en-ltr"
      "responsive-720x1280-jobs-en-ltr"
      "responsive-720x1280-job-detail-en-ltr"
      "responsive-720x1280-wallet-en-ltr"
      "responsive-720x1280-profile-en-ltr"
      "responsive-720x1280-transactions-en-ltr"
    )
  else
    responsive_session_screens=(
      "responsive-720x1280-home-fa-rtl"
      "responsive-720x1280-jobs-fa-rtl"
      "responsive-720x1280-job-detail-fa-rtl"
      "responsive-720x1280-transactions-fa-rtl"
      "responsive-720x1280-wallet-fa-rtl"
      "responsive-720x1280-profile-fa-rtl"
    )
  fi

  for SCREEN_INDEX in "${!responsive_session_screens[@]}"; do
    marker="${responsive_session_screens[$SCREEN_INDEX]}"
    session_status=0
    run_host_batch_session responsive-single "$marker" || session_status=$?
    if [ "$session_status" -eq 0 ] &&
       ! validate_capture_set "responsive-$CAPTURE_LOCALE-$SCREEN_INDEX" "$runner_temp/hope-responsive-single-runtime.log" "$marker"; then
      session_status=1
    fi
    if [ "$session_status" -ne 0 ]; then
      responsive_status="$session_status"
      break
    fi
    hope_android_device_ready "$RUNTIME_SERIAL" || true
  done

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

  adb shell wm size reset || true
  adb shell sleep 1 >/dev/null 2>&1 || true

  if [ "$responsive_status" -eq 0 ] &&
     ! validate_capture_set "responsive-$CAPTURE_LOCALE-combined" "/dev/null" "${responsive_target_screens[@]}"; then
    responsive_status=1
  fi

  if [ "$responsive_status" -ne 0 ] && [ "$test_status" -eq 0 ]; then
    test_status="$responsive_status"
  fi
fi
adb shell getprop ro.build.version.release > "$evidence_dir/android-version.txt" 2>&1 || true
adb shell getprop ro.product.model > "$evidence_dir/device-model.txt" 2>&1 || true
adb shell wm size > "$evidence_dir/viewport.txt" 2>&1 || true
printf '%s\n' '720x1280' > "$evidence_dir/responsive-viewport.txt"

if [ "$CAPTURE_HOME_ONLY" = "1" ]; then
  CAPTURED_BASELINE_SCREENS=1
  CAPTURED_RESPONSIVE_SCREENS=0
  CAPTURED_LOCALE_LABEL="fa-RTL home-only"
elif [ "$CAPTURE_AUTH_ONLY" = "1" ]; then
  CAPTURED_BASELINE_SCREENS=3
  CAPTURED_RESPONSIVE_SCREENS=0
  CAPTURED_LOCALE_LABEL="${CAPTURE_LOCALE}-auth-only"
elif [ "$CAPTURE_LOCALE" = "fa" ]; then
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
  "capture_transport": "flutter_integration_test_onScreenshot",
  "capture_session_scope": "one-screenshot-per-flutter-driver-session",
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