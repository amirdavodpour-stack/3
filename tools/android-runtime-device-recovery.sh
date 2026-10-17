#!/usr/bin/env bash

# The emulator runner waits for boot completion, but the ADB transport can
# still transiently report "offline" when the custom test script starts.
# Keep this recovery bounded and explicit so the first Flutter/Driver command
# only starts after an online, boot-complete transport is observed.
hope_android_device_ready() {
  local serial="${1:-${ANDROID_SERIAL:-emulator-5554}}"
  local attempts="${HOPE_ADB_RECOVERY_ATTEMPTS:-12}"
  local delay="${HOPE_ADB_RECOVERY_DELAY_SECONDS:-2}"
  local offline_streak=0
  local attempt state booted

  for ((attempt = 1; attempt <= attempts; attempt++)); do
    state="$(adb -s "$serial" get-state 2>&1 || true)"

    case "$state" in
      device)
        offline_streak=0
        booted="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
        if [[ "$booted" == "1" ]]; then
          echo "HOPE_ADB_READY:serial=$serial attempt=$attempt"
          return 0
        fi
        echo "HOPE_ADB_BOOTING:serial=$serial attempt=$attempt" >&2
        ;;
      offline)
        offline_streak=$((offline_streak + 1))
        echo "HOPE_ADB_OFFLINE:serial=$serial attempt=$attempt streak=$offline_streak; reconnecting" >&2
        adb reconnect offline >/dev/null 2>&1 || true
        if ((offline_streak == 2 || offline_streak == 5)); then
          echo "HOPE_ADB_SERVER_RESET:serial=$serial offline_streak=$offline_streak" >&2
          adb kill-server >/dev/null 2>&1 || true
          adb start-server >/dev/null 2>&1 || true
        fi
        ;;
      *)
        offline_streak=0
        echo "HOPE_ADB_STATE:$state serial=$serial attempt=$attempt" >&2
        ;;
    esac

    sleep "$delay"
  done

  echo "HOPE_ADB_READY_FAILED:serial=$serial attempts=$attempts" >&2
  return 1
}


# Restore the HOPE launcher after Flutter Driver sessions before the bound
# TalkBack semantics pass. Flutter's repeated install/driver lifecycle can leave
# the package registered without a resolvable launcher activity on API 35.
# Resolve the manifest-declared launcher dynamically; if resolution is stale,
# reinstall the already-built exact debug APK once, then fail with diagnostics.
hope_android_app_activity_ready() {
  local serial="${1:-${ANDROID_SERIAL:-emulator-5554}}"
  local package="${2:-com.hope.marketplace}"
  local apk="${3:-build/app/outputs/flutter-apk/app-debug.apk}"
  local package_path activity launch_output

  if [[ ! -s "$apk" ]]; then
    echo "FAIL: HOPE debug APK is unavailable for launcher recovery: $apk" >&2
    return 1
  fi

  package_path="$(adb -s "$serial" shell pm path "$package" 2>&1 | tr -d '\r' || true)"
  if ! grep -Eq '^package:' <<<"$package_path"; then
    echo "HOPE_APP_PACKAGE_MISSING: reinstalling exact runtime APK for $package"
    if ! adb -s "$serial" install -r "$apk"; then
      echo "FAIL: could not reinstall HOPE runtime APK after package disappeared." >&2
      return 1
    fi
  fi

  activity="$(adb -s "$serial" shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$package" 2>&1 |
    tr -d '\r' | grep -F "$package/" | tail -n 1 || true)"
  if [[ -z "$activity" ]]; then
    echo "HOPE_APP_ACTIVITY_UNRESOLVED: reinstalling exact runtime APK once"
    adb -s "$serial" shell dumpsys package "$package" 2>&1 || true
    adb -s "$serial" install -r "$apk" || {
      echo "FAIL: could not reinstall HOPE APK to recover launcher resolution." >&2
      return 1
    }
    activity="$(adb -s "$serial" shell cmd package resolve-activity --brief \
      -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$package" 2>&1 |
      tr -d '\r' | grep -F "$package/" | tail -n 1 || true)"
  fi

  case "$activity" in
    "$package/"*) ;;
    *)
      echo "FAIL: launcher activity still cannot be resolved for $package." >&2
      adb -s "$serial" shell cmd package query-activities --brief \
        -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$package" 2>&1 || true
      adb -s "$serial" shell dumpsys package "$package" 2>&1 || true
      return 1
      ;;
  esac

  if ! launch_output="$(adb -s "$serial" shell am start -W -n "$activity" 2>&1)" ||
     ! grep -Fq 'Status: ok' <<<"$launch_output"; then
    printf '%s\n' "$launch_output" >&2
    echo "FAIL: resolved HOPE launcher activity did not start: $activity" >&2
    adb -s "$serial" shell dumpsys activity activities 2>&1 || true
    return 1
  fi
  printf '%s\n' "$launch_output"
  echo "HOPE_APP_ACTIVITY_LAUNCHED:$activity"
}
