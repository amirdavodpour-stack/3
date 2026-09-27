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
RUNTIME_APK="${GITHUB_WORKSPACE:-$PWD}/build/app/outputs/flutter-apk/app-debug.apk"
ADB_KILL_AFTER_SECONDS="${HOPE_ADB_KILL_AFTER_SECONDS:-5}"
SCREENSHOT_PRESENT_DELAY_SECONDS="${HOPE_SCREENSHOT_PRESENT_DELAY_SECONDS:-1}"
SCREENSHOT_FRESHNESS_TIMEOUT_SECONDS="${HOPE_SCREENSHOT_FRESHNESS_TIMEOUT_SECONDS:-15}"
FOCUS_CHECK_TIMEOUT_SECONDS="${HOPE_FOCUS_CHECK_TIMEOUT_SECONDS:-20}"
DRAW_CHECK_TIMEOUT_SECONDS="${HOPE_DRAW_CHECK_TIMEOUT_SECONDS:-120}"
DRIVER_CONNECT_TIMEOUT_SECONDS="${HOPE_DRIVER_CONNECT_TIMEOUT_SECONDS:-120}"
RUNTIME_TEST_TIMEOUT_SECONDS="${HOPE_RUNTIME_TEST_TIMEOUT_SECONDS:-180}"
RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-10}"
CAPTURE_LOCALE="${HOPE_CAPTURE_LOCALE:-}"

case "$CAPTURE_LOCALE" in
  fa|en) ;;
  *)
    echo "Unsupported HOPE_CAPTURE_LOCALE: $CAPTURE_LOCALE" >&2
    exit 2
    ;;
esac

echo "HOPE_RUNTIME_PREBUILD:$RUNTIME_APK"
flutter build apk --debug --no-pub \
  --target=integration_test/runtime/critical_screens_evidence_test.dart \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
  --dart-define=HOPE_ADB_SCREENSHOT_CAPTURE=true \
  --dart-define=HOPE_SCREENSHOT_SYNC_ROOT="/data/user/0/com.hope.marketplace/files/hope-screen-sync-${GITHUB_RUN_ID}"
test -s "$RUNTIME_APK"

# Keep the APK installed once so each fresh Flutter Drive session can read a
# per-session marker from app-private storage before the Dart test starts.
timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" \
  adb install -r "$RUNTIME_APK" >"${runner_temp}/hope-runtime-preinstall.log" 2>&1
adb shell am force-stop com.hope.marketplace || true
RUNTIME_CAPTURE_MARKER_FILE="/data/user/0/com.hope.marketplace/files/hope-screen-sync-${GITHUB_RUN_ID}/capture.marker"
adb shell run-as com.hope.marketplace mkdir -p "files/hope-screen-sync-${GITHUB_RUN_ID}" >/dev/null
adb shell run-as com.hope.marketplace rm -f "$RUNTIME_CAPTURE_MARKER_FILE" >/dev/null 2>&1 || true

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
if [ "$CAPTURE_LOCALE" = "fa" ]; then
  baseline_screens=("${screens[@]:0:15}")
elif [ "$CAPTURE_LOCALE" = "en" ]; then
  baseline_screens=("${screens[@]:15:15}")
fi

capture_host_screenshot() {
  local marker="$1"
  local process_pid="$2"
  local request="files/hope-screen-sync-${GITHUB_RUN_ID}/$marker.ready"
  local output="$evidence_dir/$marker.png"
  local deadline=$((SECONDS + 180))

  while (( SECONDS < deadline )); do
    local ready_tmp="$(mktemp)"
    if timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" \
      adb exec-out run-as com.hope.marketplace cat "$request" >"$ready_tmp" 2>/dev/null; then
      rm -f "$ready_tmp"

      sleep "$SCREENSHOT_PRESENT_DELAY_SECONDS"

      if ! assert_hope_focused "$marker"; then
        echo "HOPE_HOST_CAPTURE_FAILED:$marker:focus" >&2
        return 1
      fi
      if ! assert_hope_rendered "$marker"; then
        echo "HOPE_HOST_CAPTURE_FAILED:$marker:draw-state" >&2
        return 1
      fi

      local freshness_deadline=$((SECONDS + SCREENSHOT_FRESHNESS_TIMEOUT_SECONDS))
      while (( SECONDS < freshness_deadline )); do
        local temp_output="${output}.tmp"
        rm -f "$temp_output"
        if ! timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${ADB_TIMEOUT_SECONDS}s" \
          adb exec-out screencap -p >"$temp_output" 2>"${output}.adb-error"; then
          rm -f "$temp_output"
          echo "HOPE_HOST_CAPTURE_FAILED:$marker:screencap" >&2
          return 1
        fi

        local magic
        magic="$(od -An -tx1 -N8 "$temp_output" | tr -d "[:space:]")"
        if [ "$magic" != "89504e470d0a1a0a" ]; then
          rm -f "$temp_output"
          echo "HOPE_HOST_CAPTURE_FAILED:$marker:invalid-png" >&2
          return 1
        fi

        local screenshot_hash
        screenshot_hash="$(sha256sum "$temp_output" | awk "{print \$1}")"
        if [ -z "${previous_host_screenshot_hash:-}" ] ||
           [ "$screenshot_hash" != "$previous_host_screenshot_hash" ]; then
          mv "$temp_output" "$output"
          rm -f "${output}.adb-error"
          previous_host_screenshot_hash="$screenshot_hash"
          adb exec-out run-as com.hope.marketplace rm -f "$request" >/dev/null 2>&1 || true
          echo "HOPE_HOST_SCREENSHOT_CAPTURED:$marker"
          return 0
        fi

        rm -f "$temp_output"
        sleep 0.25
      done

      echo "HOPE_HOST_CAPTURE_FAILED:$marker:stale-frame" >&2
      adb exec-out run-as com.hope.marketplace rm -f "$request" >/dev/null 2>&1 || true
      return 1
    fi
    rm -f "$ready_tmp"

    if ! kill -0 "$process_pid" 2>/dev/null; then
      echo "HOPE_HOST_CAPTURE_FAILED:$marker:driver-exited" >&2
      return 1
    fi
    sleep 0.2
  done

  echo "HOPE_HOST_CAPTURE_FAILED:$marker:timeout" >&2
  return 1
}
run_en_host_session() {
  local mode="$1"
  local marker="$2"
  local log_path="$runner_temp/hope-$marker-runtime.log"
  local process_pid
  local tail_pid
  local driver_status=0
  local capture_status=0

  # Seed the exact marker before Flutter launches the app. The Android route
  # path was not delivered to defaultRouteName on this driver path.
  # run-as starts in the app-private sandbox; use a sandbox-relative path
  # for the write because absolute /data/user/0 access is denied in this context.
  local runtime_marker_relative="files/hope-screen-sync-${GITHUB_RUN_ID}/capture.marker"
  timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s \
    adb shell run-as com.hope.marketplace sh -c "mkdir -p \"\$(dirname '$runtime_marker_relative')\" && printf '%s\\n' '$marker' > '$runtime_marker_relative'" >/dev/null

  rm -f "$log_path"
  : > "$log_path"

  set +e
  flutter drive --no-pub --no-dds \
    --use-application-binary="$RUNTIME_APK" \
    --driver=test_driver/hope_runtime_screenshot_driver.dart \
    --target=integration_test/runtime/critical_screens_evidence_test.dart \
    --route="/__hope_runtime_capture__/$CAPTURE_LOCALE/$marker" \
    >"$log_path" 2>&1 &
  process_pid=$!
  tail -n +1 -f "$log_path" &
  tail_pid=$!
  set -e

  if ! wait_for_driver_connection "$process_pid" "$log_path"; then
    capture_status=1
    echo "HOPE_HOST_RUNTIME_SESSION_TIMEOUT:driver-connect:$marker" >&2
    kill "$process_pid" >/dev/null 2>&1 || true
  else
    capture_host_screenshot "$marker" "$process_pid" || {
      capture_status=$?
      kill "$process_pid" >/dev/null 2>&1 || true
    }
  fi

  local completion_request="files/hope-screen-sync-$GITHUB_RUN_ID/test-complete.ready"
  local completion_status=1
  local completion_deadline=$((SECONDS + 30))
  while (( SECONDS < completion_deadline )); do
    if timeout --foreground --signal=TERM --kill-after="$ADB_KILL_AFTER_SECONDS"s "$ADB_TIMEOUT_SECONDS"s adb exec-out run-as com.hope.marketplace cat "$completion_request" >/dev/null 2>&1; then
      completion_status=0
      break
    fi
    if ! kill -0 "$process_pid" 2>/dev/null; then break; fi
    sleep 0.2
  done

  if [ "$completion_status" -ne 0 ]; then
    echo "HOPE_HOST_RUNTIME_COMPLETE_FAILED:test-body-complete-timeout:$marker" >&2
    capture_status=1
  fi

  local shutdown_deadline=$((SECONDS + RUNTIME_TEST_TIMEOUT_SECONDS))
  while kill -0 "$process_pid" 2>/dev/null; do
    if (( SECONDS >= shutdown_deadline )); then
      echo "HOPE_HOST_RUNTIME_SESSION_TIMEOUT:driver-shutdown:$marker" >&2
      kill "$process_pid" >/dev/null 2>&1 || true
      sleep 1
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
  fi

  kill "$tail_pid" >/dev/null 2>&1 || true
  wait "$tail_pid" >/dev/null 2>&1 || true

  if [ "$driver_status" -ne 0 ]; then
    echo "HOPE_HOST_RUNTIME_DRIVER_FAILED:exit=$driver_status:marker=$marker" >&2
    capture_android_diagnostics "$mode-$marker"
    return "$driver_status"
  fi
  return "$capture_status"
}
baseline_status=0
for marker in "${baseline_screens[@]}"; do
  run_en_host_session baseline "$marker" || baseline_status=$?
  if [ "$baseline_status" -ne 0 ]; then break; fi
done
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
  for marker in "${responsive_session_screens[@]}"; do
    run_en_host_session responsive "$marker" || responsive_status=$?
    if [ "$responsive_status" -ne 0 ]; then break; fi
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

  if [ "$responsive_status" -eq 0 ] &&     ! validate_capture_set "responsive-$CAPTURE_LOCALE" "$runner_temp/hope-responsive-runtime.log" "${responsive_target_screens[@]}"; then
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
  "capture_transport": "adb_exec_out_screencap_host_handshake",
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