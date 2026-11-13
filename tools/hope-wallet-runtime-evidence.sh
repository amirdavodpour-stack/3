#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-critical-screens-runtime.log"
mkdir -p "$evidence_dir"
# Every artifact describes this run only; do not count stale screenshots.
find "$evidence_dir" -maxdepth 1 -type f -name '*.png' -delete
rm -f "$log_file"
: > "$log_file"

RUNTIME_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
TALKBACK_PACKAGE="${HOPE_TALKBACK_PACKAGE:-com.android.talkback}"
TALKBACK_SERVICE_COMPONENT="${TALKBACK_PACKAGE}/com.google.android.marvin.talkback.TalkBackService"
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
RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-30}"
BODY_COMPLETION_TIMEOUT_SECONDS="${HOPE_RUNTIME_BODY_COMPLETION_TIMEOUT_SECONDS:-90}"
if [[ ! "$BODY_COMPLETION_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Invalid HOPE_RUNTIME_BODY_COMPLETION_TIMEOUT_SECONDS: $BODY_COMPLETION_TIMEOUT_SECONDS" >&2
  exit 2
fi
CAPTURE_LOCALE="${HOPE_CAPTURE_LOCALE:-}"
CAPTURE_THEME="${HOPE_CAPTURE_THEME:-dark}"
CAPTURE_TEXT_SCALE="${HOPE_CAPTURE_TEXT_SCALE:-1.0}"
STRICT_RUNTIME_VALIDATION="${HOPE_RUNTIME_STRICT_VALIDATION:-0}"
CAPTURE_HOME_ONLY="${HOPE_CAPTURE_HOME_ONLY:-0}"
# bool.fromEnvironment only treats the string "true" as true. The workflow
# contract uses 1/0 for shell semantics, so normalize before passing it to Dart.
DART_CAPTURE_HOME_ONLY="false"
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
case "$CAPTURE_THEME" in
  dark|light) ;;
  *)
    echo "Unsupported HOPE_CAPTURE_THEME: $CAPTURE_THEME" >&2
    exit 2
    ;;
esac
case "$CAPTURE_TEXT_SCALE" in
  1.0|1.25|1.5|2.0) ;;
  *)
    echo "Unsupported HOPE_CAPTURE_TEXT_SCALE: $CAPTURE_TEXT_SCALE" >&2
    exit 2
    ;;
esac

echo "HOPE_RUNTIME_DRIVER_BUILD_MODE:self-build"
echo "HOPE_RUNTIME_CAPTURE_THEME:$CAPTURE_THEME"
echo "HOPE_RUNTIME_CAPTURE_TEXT_SCALE:$CAPTURE_TEXT_SCALE"

adb shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled-before.txt" 2>&1 || true
adb shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services-before.txt" 2>&1 || true
if ! bash tools/hope-disable-talkback.sh; then
  echo "HOPE_TALKBACK_DISABLE_FAILED: cannot guarantee overlay-free visual capture." >&2
  exit 12
fi
talkback_setup_status=0

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
  local native_screenshot_hash
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
    native_screenshot_hash=""
    if [ "$log_path" != "/dev/null" ] && [ -r "$log_path" ]; then
      native_screenshot_hash="$(grep -F "HOPE_SCREENSHOT_CAPTURE_COMPLETE:$marker:bytes=" "$log_path" |
        sed -nE 's/.*:sha256=([0-9a-f]{64}).*/\1/p' | tail -n 1 || true)"
    fi
    if [ -n "$native_screenshot_hash" ]; then
      if [ "$native_screenshot_hash" != "$screenshot_hash" ]; then
        echo "HOPE_HOST_CAPTURE_FAILED:$set_name:$marker:native-host-digest-mismatch:native=$native_screenshot_hash:host=$screenshot_hash" >&2
        return 1
      fi
      echo "HOPE_HOST_CAPTURE_DIGEST_MATCH:$marker:$screenshot_hash"
    else
      echo "HOPE_HOST_CAPTURE_DIGEST_UNAVAILABLE:$marker"
      if [ "$log_path" != "/dev/null" ]; then
        echo "HOPE_HOST_CAPTURE_FAILED:$set_name:$marker:native-digest-missing" >&2
        return 1
      fi
    fi
    if [ -n "${seen_screenshot_hashes[$screenshot_hash]+x}" ]; then
      echo "HOPE_HOST_CAPTURE_FAILED:$set_name:$marker:duplicate-png-hash:$screenshot_hash:matches:${seen_screenshot_hashes[$screenshot_hash]}" >&2
      return 1
    fi
    seen_screenshot_hashes[$screenshot_hash]="$marker"
    echo "HOPE_HOST_SCREENSHOT_VALIDATED:$marker:$screenshot_hash"
  done

  return 0
}

validate_semantics_set() {
  local set_name="$1"
  local log_path="$2"
  shift 2
  local marker
  for marker in "$@"; do
    if ! grep -Fq -- "HOPE_T10_SEMANTICS_PASS:$marker:" "$log_path"; then
      echo "HOPE_T10_SEMANTICS_FAILED:$set_name:$marker:missing-pass-marker" >&2
      return 1
    fi
    echo "HOPE_T10_SEMANTICS_VALIDATED:$marker"
  done
  return 0
}

validate_scroll_end_set() {
  local set_name="$1"
  local log_path="$2"
  shift 2
  local marker
  for marker in "$@"; do
    if ! grep -Fq -- "HOPE_T10_SCROLL_END_PASS:$marker:" "$log_path"; then
      echo "HOPE_T10_SCROLL_END_FAILED:$set_name:$marker:missing-pass-marker" >&2
      return 1
    fi
    echo "HOPE_T10_SCROLL_END_VALIDATED:$marker"
  done
  return 0
}

extended_screens_fa=(
  "financial-insights-fa-rtl"
  "job-satisfaction-fa-rtl"
  "candidate-matches-fa-rtl"
  "chat-fa-rtl"
)
extended_screens_en=(
  "financial-insights-en-ltr"
  "job-satisfaction-en-ltr"
  "candidate-matches-en-ltr"
  "chat-en-ltr"
)

screens=(
  "login-fa-rtl"
  "home-fa-rtl"
  "jobs-fa-rtl"
  "job-detail-fa-rtl"
  "applications-fa-rtl"
  "saved-searches-fa-rtl"
  "transactions-fa-rtl"
  "wallet-fa-rtl"
  "transaction-detail-fa-rtl"
  "profile-fa-rtl"
  "notifications-fa-rtl"
  "offers-fa-rtl"
  "create-job-fa-rtl"
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
elif [ "$CAPTURE_LOCALE" = "fa" ]; then
  baseline_screens=("${screens[@]:0:15}" "${extended_screens_fa[@]}")
elif [ "$CAPTURE_LOCALE" = "en" ]; then
  baseline_screens=("${screens[@]:15:15}" "${extended_screens_en[@]}")
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
  local semantics_only="false"
  case "$mode" in
    semantics-only) launch_mode="baseline"; semantics_only="true" ;;
    semantics-responsive-a) launch_mode="responsive-a"; semantics_only="true" ;;
    semantics-responsive-b) launch_mode="responsive-b"; semantics_only="true" ;;
    semantics-responsive-c) launch_mode="responsive-c"; semantics_only="true" ;;
  esac
  case "$launch_mode" in
    baseline-a) baseline_batch="a" ;;
    baseline-b) baseline_batch="b" ;;
    baseline-c) baseline_batch="c" ;;
    baseline-d) baseline_batch="d" ;;
  esac
  if [ "$launch_mode" = "responsive-a" ] || [ "$launch_mode" = "responsive-b" ] || [ "$launch_mode" = "responsive-c" ]; then
    responsive_only="true"
    case "$launch_mode" in
      responsive-a) responsive_batch="1" ;;
      responsive-b) responsive_batch="2" ;;
      responsive-c) responsive_batch="3" ;;
    esac
  elif [ "$CAPTURE_HOME_ONLY" = "1" ] && [ "$launch_mode" = "baseline" ]; then
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

  # One Flutter Driver session owns the whole screen batch. Each screenshot
  # is produced by integration_test's onScreenshot callback, so the artifact
  # is tied to the exact Flutter render request instead of a later framebuffer.
  set +e
  export HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"
  # CI runtime evidence runs on the x86_64 Linux emulator software graphics stack.
  # Flutter 3.47 enables Impeller by default on Android API 29+; current Flutter/emulator
  # evidence shows materially worse raster stability in this environment. Keep the opt-out
  # scoped to this debug evidence lane; product builds retain their normal renderer.
  HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir" \
  timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s" "${RUNTIME_TEST_TIMEOUT_SECONDS}s" \
  flutter drive --keep-app-running --no-pub --no-dds --no-enable-impeller \
    --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
    --dart-define=HOPE_CAPTURE_LOCALE="${CAPTURE_LOCALE}" \
    --dart-define=HOPE_CAPTURE_TEXT_SCALE="${CAPTURE_TEXT_SCALE}" \
    --dart-define=HOPE_CAPTURE_THEME="${CAPTURE_THEME}" \
    --dart-define=HOPE_TALKBACK_REQUIRED=true \
    --dart-define=HOPE_T10_SEMANTICS_ONLY="${semantics_only}" \
    --dart-define=HOPE_CAPTURE_HOME_ONLY="${DART_CAPTURE_HOME_ONLY}" \
    --dart-define=HOPE_CAPTURE_MODE="${launch_mode}" \
    --dart-define=HOPE_BASELINE_BATCH="${baseline_batch}" \
    --dart-define=HOPE_RESPONSIVE_ONLY="${responsive_only}" \
    --dart-define=HOPE_RESPONSIVE_BATCH="${responsive_batch}" \
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
  elif ! assert_hope_focused "$mode" || ! assert_hope_rendered "$mode"; then
    capture_status=1
    echo "HOPE_HOST_RUNTIME_FOCUS_OR_SURFACE_FAILED:$mode" >&2
    kill "$process_pid" >/dev/null 2>&1 || true
  else
    echo "HOPE_HOST_RUNTIME_FOCUS_AND_SURFACE_VERIFIED:$mode"
    # integration_test's onScreenshot callback owns the host-side PNG write.
    # Waiting on each marker here creates a race with the Flutter Driver
    # command/response cycle. The final capture-set validator below checks all
    # expected files after the test body reports completion.
    :
  fi

  local completion_status=1
  # The prior exact-head baseline completed its capture set, but its completion
  # marker arrived ~87ms after the old 60-second deadline. Keep the wait bounded
  # while allowing slow native PixelCopy/Driver teardown to flush the final marker.
  local completion_deadline=$((SECONDS + BODY_COMPLETION_TIMEOUT_SECONDS))
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
    if [ "$semantics_only" = "true" ]; then
      echo "HOPE_T10_SEMANTICS_ONLY_BODY_COMPLETE:$mode"
      echo "HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT:$mode"
    else
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
        sleep 0.2
      done
      if [ "$screenshot_flush_status" -ne 0 ]; then
        echo "HOPE_HOST_SCREENSHOT_FLUSH_FAILED:$mode" >&2
        capture_status=1
      fi
      if [ "$screenshot_flush_status" -eq 0 ]; then
        echo "HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT:$mode"
      else
        echo "HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT_AFTER_CAPTURE_FAILURE:$mode"
      fi
    fi
  fi

  local shutdown_deadline=$((SECONDS + RUNTIME_SHUTDOWN_GRACE_SECONDS))
  while kill -0 "$process_pid" 2>/dev/null; do
    if (( SECONDS >= shutdown_deadline )); then
      echo "HOPE_HOST_RUNTIME_DRIVER_NATURAL_EXIT_TIMEOUT:$mode" >&2
      echo "HOPE_HOST_RUNTIME_DRIVER_FORCE_STOP:$mode" >&2
      kill -KILL "$process_pid" >/dev/null 2>&1 || true
      driver_status=124
      break
    fi
    sleep 0.2
  done
  if ! kill -0 "$process_pid" 2>/dev/null; then
    echo "HOPE_HOST_RUNTIME_DRIVER_NATURAL_EXIT_COMPLETE:$mode"
  fi

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
  run_host_batch_session baseline "${baseline_screens[@]}" || baseline_status=$?
  if [ "$baseline_status" -eq 0 ] &&
     ! validate_capture_set "baseline-$CAPTURE_LOCALE" "$runner_temp/hope-baseline-runtime.log" "${baseline_screens[@]}"; then
    baseline_status=1
  fi
else
  baseline_status=0
  # Preserve the proven single-session baseline first. If the long-lived
  # VM-service dies only at the final auth tail, recover just that missing
  # tail in a fresh Driver session instead of mutating product/UI code.
  run_host_batch_session baseline "${baseline_screens[@]}" || baseline_status=$?

  if [ "$baseline_status" -ne 0 ] && [ "$CAPTURE_LOCALE" = "fa" ]; then
    # baseline-d is the existing certified tail batch: create-job, register,
    # password-reset. Keep the already-captured offers screenshot untouched.
    auth_tail_screens=(
      "create-job-fa-rtl"
      "register-fa-rtl"
      "password-reset-fa-rtl"
    )
    auth_tail_complete=0
    for marker in "${auth_tail_screens[@]}"; do
      if ! test -s "$evidence_dir/$marker.png"; then
        auth_tail_complete=1
        break
      fi
    done
    if [ "$auth_tail_complete" -eq 1 ] && test -s "$evidence_dir/create-job-fa-rtl.png"; then
      echo "HOPE_HOST_RUNTIME_TAIL_RECOVERY_START:baseline-auth-tail"
      hope_android_device_ready "$RUNTIME_SERIAL"
      run_host_batch_session baseline-d "${auth_tail_screens[@]}" || true
      # Preserve native marker + SHA-256 evidence for auth PNGs rewritten by recovery.
      if [ -s "$runner_temp/hope-baseline-d-runtime.log" ]; then
        cat "$runner_temp/hope-baseline-d-runtime.log" >> "$runner_temp/hope-baseline-runtime.log"
      fi
    fi
  fi

  if ! validate_capture_set "baseline-$CAPTURE_LOCALE" "$runner_temp/hope-baseline-runtime.log" "${baseline_screens[@]}"; then
    baseline_status=1
  fi
fi
if [ "$baseline_status" -ne 0 ]; then
  test_status="$baseline_status"
else
  test_status=0
fi

if [ "$baseline_status" -eq 0 ] && [ "$CAPTURE_HOME_ONLY" != "1" ]; then
  adb shell wm size 720x1280
  # wm size changes physical pixels, not density. Keep the responsive fixture at
  # 360x640 logical dp (320 dpi) rather than accidentally shrinking a Pixel 2 to
  # ~274x488dp and producing misleading typography/clipping evidence.
  adb shell wm density 320
  adb shell wm density > "$evidence_dir/responsive-density.txt" 2>&1 || true
  sleep 2
  : > "$runner_temp/hope-responsive-runtime.log"

  responsive_status=0
  if [ "$CAPTURE_LOCALE" = "en" ]; then
    responsive_session_screens=(
      "responsive-720x1280-home-en-ltr"
      "responsive-720x1280-jobs-en-ltr"
      "responsive-720x1280-job-detail-en-ltr"
      "responsive-720x1280-transactions-en-ltr"
      "responsive-720x1280-wallet-en-ltr"
      "responsive-720x1280-profile-en-ltr"
      "responsive-720x1280-financial-insights-en-ltr"
    )
  else
    responsive_session_screens=(
      "responsive-720x1280-home-fa-rtl"
      "responsive-720x1280-jobs-fa-rtl"
      "responsive-720x1280-job-detail-fa-rtl"
      "responsive-720x1280-transactions-fa-rtl"
      "responsive-720x1280-wallet-fa-rtl"
      "responsive-720x1280-profile-fa-rtl"
      "responsive-720x1280-financial-insights-fa-rtl"
    )
  fi
  # Split the responsive capture set across three fresh Flutter Driver sessions.
  # Transactions and Wallet previously shared one long-lived VM-service session;
  # isolate Transactions so Wallet gets a fresh driver/emulator boundary.
  responsive_first_status=0
  responsive_second_status=0
  responsive_third_status=0
  responsive_first_screens=("${responsive_session_screens[@]:0:3}")
  responsive_second_screens=("${responsive_session_screens[@]:3:1}")
  responsive_third_screens=("${responsive_session_screens[@]:4:3}")

  run_host_batch_session responsive-a "${responsive_first_screens[@]}" || responsive_first_status=$?
  if [ "$responsive_first_status" -eq 0 ] && \
     ! validate_capture_set "responsive-$CAPTURE_LOCALE-a" "$runner_temp/hope-responsive-a-runtime.log" "${responsive_first_screens[@]}"; then
    responsive_first_status=1
  fi

  if [ "$responsive_first_status" -eq 0 ]; then
    hope_android_device_ready "$RUNTIME_SERIAL"
    run_host_batch_session responsive-b "${responsive_second_screens[@]}" || responsive_second_status=$?
    if [ "$responsive_second_status" -eq 0 ] && \
       ! validate_capture_set "responsive-$CAPTURE_LOCALE-b" "$runner_temp/hope-responsive-b-runtime.log" "${responsive_second_screens[@]}"; then
      responsive_second_status=1
    fi
  fi

  if [ "$responsive_second_status" -eq 0 ] && [ "$responsive_first_status" -eq 0 ]; then
    hope_android_device_ready "$RUNTIME_SERIAL"
    run_host_batch_session responsive-c "${responsive_third_screens[@]}" || responsive_third_status=$?
    if [ "$responsive_third_status" -eq 0 ] && \
       ! validate_capture_set "responsive-$CAPTURE_LOCALE-c" "$runner_temp/hope-responsive-c-runtime.log" "${responsive_third_screens[@]}"; then
      responsive_third_status=1
    fi
  fi

  if [ "$responsive_first_status" -ne 0 ]; then
    responsive_status="$responsive_first_status"
  elif [ "$responsive_second_status" -ne 0 ]; then
    responsive_status="$responsive_second_status"
  elif [ "$responsive_third_status" -ne 0 ]; then
    responsive_status="$responsive_third_status"
  else
    responsive_status=0
  fi

  responsive_screens=(
    "responsive-720x1280-home-fa-rtl"
    "responsive-720x1280-jobs-fa-rtl"
    "responsive-720x1280-job-detail-fa-rtl"
    "responsive-720x1280-transactions-fa-rtl"
    "responsive-720x1280-wallet-fa-rtl"
    "responsive-720x1280-profile-fa-rtl"
    "responsive-720x1280-financial-insights-fa-rtl"
    "responsive-720x1280-home-en-ltr"
    "responsive-720x1280-jobs-en-ltr"
    "responsive-720x1280-job-detail-en-ltr"
    "responsive-720x1280-transactions-en-ltr"
    "responsive-720x1280-wallet-en-ltr"
    "responsive-720x1280-profile-en-ltr"
    "responsive-720x1280-financial-insights-en-ltr"
  )

  responsive_target_screens=("${responsive_screens[@]}")
  if [ "$CAPTURE_LOCALE" = "fa" ]; then
    responsive_target_screens=("${responsive_screens[@]:0:7}")
  elif [ "$CAPTURE_LOCALE" = "en" ]; then
    responsive_target_screens=("${responsive_screens[@]:7:7}")
  fi

  adb shell wm size reset || true
  adb shell wm density reset || true
  adb shell sleep 1 >/dev/null 2>&1 || true

  if [ "$responsive_status" -eq 0 ] && \
     ! validate_capture_set "responsive-$CAPTURE_LOCALE-combined" "/dev/null" "${responsive_target_screens[@]}"; then
    responsive_status=1
  fi

  if [ "$responsive_status" -ne 0 ] && [ "$test_status" -eq 0 ]; then
    test_status="$responsive_status"
  fi
fi

# Visual PNGs are captured first with the accessibility service explicitly unbound.
# Then run the same screen set with real TalkBack attached, emitting no PNG payloads.
talkback_setup_status=0
if ! bash tools/hope-enable-talkback.sh; then
  echo "HOPE_TALKBACK_SETUP_FAILED: TalkBack must be bound with touch exploration enabled." >&2
  talkback_setup_status=1
fi
if [[ "$talkback_setup_status" -eq 0 ]]; then
  if ! hope_android_app_activity_ready "$RUNTIME_SERIAL" com.hope.marketplace \
    "build/app/outputs/flutter-apk/app-debug.apk" > "$evidence_dir/hope-talkback-return-to-app.txt" 2>&1; then
    cat "$evidence_dir/hope-talkback-return-to-app.txt" >&2 || true
    echo "HOPE_TALKBACK_FOREGROUND_RETURN_FAILED: launcher activity could not be resolved and foregrounded after TalkBack setup." >&2
    capture_android_diagnostics talkback-return
    talkback_setup_status=1
  else
    cat "$evidence_dir/hope-talkback-return-to-app.txt"
    if ! assert_hope_focused talkback-return; then
      echo "HOPE_TALKBACK_FOREGROUND_RETURN_FAILED: MainActivity did not gain verified foreground focus after TalkBack setup." >&2
      talkback_setup_status=1
    else
      echo "HOPE_RUNTIME_APP_FOREGROUND_AFTER_TALKBACK:true"
    fi
  fi
fi
semantics_status=0
if [ "$CAPTURE_HOME_ONLY" != "1" ] && [ "$talkback_setup_status" -eq 0 ]; then
  run_host_batch_session semantics-only "${baseline_screens[@]}" || semantics_status=$?
  if [ "$semantics_status" -eq 0 ] && ! validate_semantics_set "baseline-$CAPTURE_LOCALE" "$runner_temp/hope-semantics-only-runtime.log" "${baseline_screens[@]}"; then semantics_status=1; fi
  scroll_suffix="en-ltr"
  if [ "$CAPTURE_LOCALE" = "fa" ]; then scroll_suffix="fa-rtl"; fi
  semantics_scroll_end_screens=(
    "home-$scroll_suffix" "jobs-$scroll_suffix" "job-detail-$scroll_suffix"
    "transactions-$scroll_suffix" "transaction-detail-$scroll_suffix"
    "wallet-$scroll_suffix" "profile-$scroll_suffix" "create-job-$scroll_suffix"
    "financial-insights-$scroll_suffix" "job-satisfaction-$scroll_suffix"
  )
  if [ "$semantics_status" -eq 0 ] && ! validate_scroll_end_set "baseline-$CAPTURE_LOCALE" "$runner_temp/hope-semantics-only-runtime.log" "${semantics_scroll_end_screens[@]}"; then semantics_status=1; fi

  if [ "$CAPTURE_LOCALE" = "en" ]; then
    semantics_responsive_screens=(
      "responsive-720x1280-home-en-ltr" "responsive-720x1280-jobs-en-ltr"
      "responsive-720x1280-job-detail-en-ltr" "responsive-720x1280-transactions-en-ltr"
      "responsive-720x1280-wallet-en-ltr" "responsive-720x1280-profile-en-ltr"
      "responsive-720x1280-financial-insights-en-ltr"
    )
  else
    semantics_responsive_screens=(
      "responsive-720x1280-home-fa-rtl" "responsive-720x1280-jobs-fa-rtl"
      "responsive-720x1280-job-detail-fa-rtl" "responsive-720x1280-transactions-fa-rtl"
      "responsive-720x1280-wallet-fa-rtl" "responsive-720x1280-profile-fa-rtl"
      "responsive-720x1280-financial-insights-fa-rtl"
    )
  fi
  semantics_responsive_first=("${semantics_responsive_screens[@]:0:3}")
  semantics_responsive_second=("${semantics_responsive_screens[@]:3:1}")
  semantics_responsive_third=("${semantics_responsive_screens[@]:4:3}")
  if [ "$semantics_status" -eq 0 ]; then
    # The image-capture pass reset the emulator to its default size. Reapply
    # the exact responsive viewport for service-bound semantics T10 as well.
    adb shell wm size 720x1280
    adb shell wm density 320
    adb shell sleep 1 >/dev/null 2>&1 || true
    echo "HOPE_T10_RESPONSIVE_SEMANTICS_VIEWPORT_BEGIN:720x1280:320dpi"
    run_host_batch_session semantics-responsive-a "${semantics_responsive_first[@]}" || semantics_status=$?
    if [ "$semantics_status" -eq 0 ] && ! validate_semantics_set "responsive-$CAPTURE_LOCALE-a" "$runner_temp/hope-semantics-responsive-a-runtime.log" "${semantics_responsive_first[@]}"; then semantics_status=1; fi
    if [ "$semantics_status" -eq 0 ]; then
      hope_android_device_ready "$RUNTIME_SERIAL"
      run_host_batch_session semantics-responsive-b "${semantics_responsive_second[@]}" || semantics_status=$?
      if [ "$semantics_status" -eq 0 ] && ! validate_semantics_set "responsive-$CAPTURE_LOCALE-b" "$runner_temp/hope-semantics-responsive-b-runtime.log" "${semantics_responsive_second[@]}"; then semantics_status=1; fi
    fi
    if [ "$semantics_status" -eq 0 ]; then
      hope_android_device_ready "$RUNTIME_SERIAL"
      run_host_batch_session semantics-responsive-c "${semantics_responsive_third[@]}" || semantics_status=$?
      if [ "$semantics_status" -eq 0 ] && ! validate_semantics_set "responsive-$CAPTURE_LOCALE-c" "$runner_temp/hope-semantics-responsive-c-runtime.log" "${semantics_responsive_third[@]}"; then semantics_status=1; fi
    fi
    adb shell wm size reset || true
    adb shell wm density reset || true
    adb shell sleep 1 >/dev/null 2>&1 || true
    echo "HOPE_T10_RESPONSIVE_SEMANTICS_VIEWPORT_END"
  fi
else
  semantics_status=1
fi
if [ "$semantics_status" -ne 0 ] && [ "$test_status" -eq 0 ]; then test_status="$semantics_status"; fi

adb shell getprop ro.build.version.release > "$evidence_dir/android-version.txt" 2>&1 || true
adb shell getprop ro.product.model > "$evidence_dir/device-model.txt" 2>&1 || true
adb shell wm size > "$evidence_dir/viewport.txt" 2>&1 || true
printf '%s\n' '720x1280 physical pixels' > "$evidence_dir/responsive-viewport.txt"
printf '%s\n' '360x640 logical dp at 320 dpi' > "$evidence_dir/responsive-logical-viewport.txt"
CAPTURED_BASELINE_SCREENS="$(find "$evidence_dir" -maxdepth 1 -type f -name '*.png' ! -name 'scroll-end-*' ! -name 'responsive-*' | wc -l | tr -d ' ')"
CAPTURED_RESPONSIVE_SCREENS="$(find "$evidence_dir" -maxdepth 1 -type f -name 'responsive-*.png' | wc -l | tr -d ' ')"
if [ "$CAPTURE_HOME_ONLY" = "1" ]; then
  CAPTURED_LOCALE_LABEL="fa-RTL home-only"
elif [ "$CAPTURE_LOCALE" = "fa" ]; then
  CAPTURED_LOCALE_LABEL="fa-RTL"
elif [ "$CAPTURE_LOCALE" = "en" ]; then
  CAPTURED_LOCALE_LABEL="en-LTR"
else
  CAPTURED_LOCALE_LABEL="fa-RTL,en-LTR"
fi

visual_capture_accessibility_disabled=false
if [[ "$(tr -d '\r\n' < "$evidence_dir/accessibility-disabled-for-capture.txt" 2>/dev/null || true)" == "true" ]]; then
  visual_capture_accessibility_disabled=true
else
  echo "HOPE_VISUAL_ACCESSIBILITY_DISABLE_NOT_VERIFIED" >&2
  test_status=1
fi
talkback_enabled=false
if [[ "$(tr -d '\r\n' < "$evidence_dir/accessibility-enabled.txt" 2>/dev/null || true)" == "1" ]]; then
  talkback_enabled=true
fi
talkback_service_bound=false
if [[ "$(tr -d '\r\n' < "$evidence_dir/talkback-service-bound.txt" 2>/dev/null || true)" == "true" ]]; then
  talkback_service_bound=true
fi
talkback_touch_exploration_enabled=false
if [[ "$(tr -d '\r\n' < "$evidence_dir/touch-exploration-enabled.txt" 2>/dev/null || true)" == "true" ]]; then
  talkback_touch_exploration_enabled=true
fi
talkback_semantics_screens=0
talkback_semantics_output="$(grep -h 'HOPE_T10_SEMANTICS_PASS:' "$runner_temp"/hope-semantics*-runtime.log 2>/dev/null || true)"
talkback_target_bounds_screens=0
talkback_target_bounds_checked=0
talkback_target_bounds_failures=0
talkback_target_bounds_min_width_dp=0
talkback_target_bounds_min_height_dp=0
talkback_target_bounds_pass_output="$(grep -h 'HOPE_T10_TARGET_BOUNDS_PASS:' "$runner_temp"/hope-semantics*-runtime.log 2>/dev/null || true)"
talkback_target_bounds_fail_output="$(grep -h 'HOPE_T10_TARGET_BOUNDS_FAIL:' "$runner_temp"/hope-semantics*-runtime.log 2>/dev/null || true)"
if [[ -n "$talkback_target_bounds_pass_output" ]]; then
  talkback_target_bounds_screens="$(printf '%s\n' "$talkback_target_bounds_pass_output" | sed -n 's/.*HOPE_T10_TARGET_BOUNDS_PASS:\([^:]*\).*/\1/p' | grep -v '^scroll-end-' | sort -u | wc -l | tr -d ' ')"
  talkback_target_bounds_checked="$(printf '%s\n' "$talkback_target_bounds_pass_output" | sed -n 's/.*targets=\([0-9][0-9]*\):.*/\1/p' | awk '{ total += $1 } END { print total + 0 }')"
  target_bounds_with_controls="$(printf '%s\n' "$talkback_target_bounds_pass_output" | grep -E 'targets=[1-9][0-9]*:' || true)"
  if [[ -n "$target_bounds_with_controls" ]]; then
    talkback_target_bounds_min_width_dp="$(printf '%s\n' "$target_bounds_with_controls" | sed -n 's/.*minWidthDp=\([0-9.]*\).*/\1/p' | sort -n | head -n 1)"
    talkback_target_bounds_min_height_dp="$(printf '%s\n' "$target_bounds_with_controls" | sed -n 's/.*minHeightDp=\([0-9.]*\).*/\1/p' | sort -n | head -n 1)"
  fi
fi
if [[ -n "$talkback_target_bounds_fail_output" ]]; then
  talkback_target_bounds_failures="$(printf '%s\n' "$talkback_target_bounds_fail_output" | wc -l | tr -d ' ')"
fi
talkback_target_bounds_minimum_size_ok=false
if awk -v width="$talkback_target_bounds_min_width_dp" -v height="$talkback_target_bounds_min_height_dp" 'BEGIN { exit !(width >= 48 && height >= 48) }'; then
  talkback_target_bounds_minimum_size_ok=true
fi
if [[ -n "$talkback_semantics_output" ]]; then
  talkback_semantics_screens="$(printf '%s\n' "$talkback_semantics_output" | sed -n 's/.*HOPE_T10_SEMANTICS_PASS:\([^:]*\).*/\1/p' | grep -v '^scroll-end-' | sort -u | wc -l | tr -d ' ')"
fi
scroll_end_screens=0
scroll_end_output="$(grep -h 'HOPE_T10_SCROLL_END_PASS:' "$runner_temp"/hope-semantics*-runtime.log 2>/dev/null || true)"
if [[ -n "$scroll_end_output" ]]; then
  scroll_end_screens="$(printf '%s\n' "$scroll_end_output" | sed -n 's/.*HOPE_T10_SCROLL_END_PASS:\([^:]*\).*/\1/p' | sort -u | wc -l | tr -d ' ')"
fi
talkback_source_sha="$(tr -d '\r\n' < "$evidence_dir/talkback-source-sha.txt" 2>/dev/null || true)"
talkback_apk_sha256="$(tr -d '\r\n' < "$evidence_dir/talkback-apk-sha256.txt" 2>/dev/null || true)"
talkback_required=false
if [[ "${HOPE_TALKBACK_REQUIRED:-0}" == "1" ]]; then
  talkback_required=true
  if [[ "$talkback_setup_status" -ne 0 || "$talkback_enabled" != "true" || "$talkback_service_bound" != "true" || "$talkback_touch_exploration_enabled" != "true" || "$talkback_semantics_screens" -ne 26 || "$scroll_end_screens" -ne 10 || "$talkback_target_bounds_screens" -ne 26 || "$talkback_target_bounds_checked" -lt 1 || "$talkback_target_bounds_failures" -ne 0 || "$talkback_target_bounds_minimum_size_ok" != "true" ]]; then
    echo "HOPE_T10_ACCEPTANCE_FAILED: setup=$talkback_setup_status enabled=$talkback_enabled bound=$talkback_service_bound touch_exploration=$talkback_touch_exploration_enabled semantics=$talkback_semantics_screens scroll_end=$scroll_end_screens target_bounds_screens=$talkback_target_bounds_screens target_bounds_checked=$talkback_target_bounds_checked target_bounds_failures=$talkback_target_bounds_failures target_min_width_dp=$talkback_target_bounds_min_width_dp target_min_height_dp=$talkback_target_bounds_min_height_dp" >&2
    test_status=1
  fi
fi

cat > "$evidence_dir/metadata.json" <<EOF
{
  "workflow": "$GITHUB_WORKFLOW",
  "run_id": "$GITHUB_RUN_ID",
  "ref": "$GITHUB_REF_NAME",
  "sha": "${HOPE_RUNTIME_EXACT_HEAD:-$GITHUB_SHA}",
  "evidence_type": "rendered_android_runtime",
  "screens": $CAPTURED_BASELINE_SCREENS,
  "responsive_screens": $CAPTURED_RESPONSIVE_SCREENS,
  "responsive_viewport": "720x1280 physical pixels",
  "responsive_logical_viewport": "360x640dp",
  "responsive_density_dpi": 320,
  "capture_locale": "$CAPTURE_LOCALE",
  "text_scale": $CAPTURE_TEXT_SCALE,
  "locales": ["$CAPTURED_LOCALE_LABEL"],
  "theme": "$CAPTURE_THEME",
  "interactive_target_contract": "48px",
  "capture_transport": "native_android_pixelcopy",
  "visual_capture_accessibility_service": "disabled",
  "visual_capture_talkback_enabled": false,
  "visual_capture_accessibility_disable_verified": $visual_capture_accessibility_disabled,
  "talkback_semantics_mode": "separate_bound_service_pass",
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
    "PasswordResetPage",
    "FinancialInsightsPage",
    "JobSatisfactionPage",
    "EmployerCandidateMatchesPage",
    "ChatPage"
  ],
  "target_extension_screens": 4,
  "talkback_required": $talkback_required,
  "talkback_enabled": $talkback_enabled,
  "talkback_service_bound": $talkback_service_bound,
  "talkback_touch_exploration_enabled": $talkback_touch_exploration_enabled,
  "talkback_target_bounds_screens": $talkback_target_bounds_screens,
  "talkback_target_bounds_checked": $talkback_target_bounds_checked,
  "talkback_target_bounds_failures": $talkback_target_bounds_failures,
  "talkback_target_bounds_min_width_dp": $talkback_target_bounds_min_width_dp,
  "talkback_target_bounds_min_height_dp": $talkback_target_bounds_min_height_dp,
  "talkback_package": "$TALKBACK_PACKAGE",
  "talkback_service_component": "$TALKBACK_SERVICE_COMPONENT",
  "talkback_source_sha": "$talkback_source_sha",
  "talkback_apk_sha256": "$talkback_apk_sha256",
  "talkback_semantics_screens": $talkback_semantics_screens,
  "scroll_end_screens": $scroll_end_screens
}
EOF

cat "$log_file"
exit "$test_status"