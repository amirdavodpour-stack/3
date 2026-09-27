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
