#!/usr/bin/env bash
set -euo pipefail
trap 'status=$?; printf "FAIL: Android ADB recovery test at line %s (status=%s): %s\\n" "$LINENO" "$status" "$BASH_COMMAND" >&2; exit "$status"' ERR

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tools/android-runtime-device-recovery.sh"

run_recovery_case() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/bin"
  export LOG="$tmp/adb.log"
  export STATE_FILE="$tmp/state"
  export PATH="$tmp/bin:$PATH"
  : > "$LOG"
  echo 0 > "$STATE_FILE"

  cat > "$tmp/bin/adb" <<'ADB'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${LOG:?}"
case "$*" in
  *" get-state")
    n=$(cat "${STATE_FILE:?}")
    n=$((n + 1))
    echo "$n" > "$STATE_FILE"
    case "$n" in
      1) echo offline ;;
      2) echo device ;;
      *) echo device ;;
    esac
    ;;
  *" shell getprop sys.boot_completed")
    n=$(cat "${STATE_FILE:?}")
    if [ "$n" -lt 3 ]; then echo 0; else echo 1; fi
    ;;
  *" reconnect offline") exit 0 ;;
  *" kill-server") exit 0 ;;
  *" start-server") exit 0 ;;
  *) echo "unexpected adb command: $*" >&2; exit 1 ;;
esac
ADB
  chmod +x "$tmp/bin/adb"

  HOPE_ADB_RECOVERY_DELAY_SECONDS=0     hope_android_device_ready emulator-5554

  grep -Fq -- "reconnect offline" "$LOG"
  grep -Fq -- "shell getprop sys.boot_completed" "$LOG"
}

run_failure_case() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/bin"
  export LOG="$tmp/adb.log"
  export PATH="$tmp/bin:$PATH"
  : > "$LOG"

  cat > "$tmp/bin/adb" <<'ADB'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${LOG:?}"
case "$*" in
  *" get-state") echo offline ;;
  *" reconnect offline") exit 0 ;;
  *" kill-server") exit 0 ;;
  *" start-server") exit 0 ;;
  *) echo "unexpected adb command: $*" >&2; exit 1 ;;
esac
ADB
  chmod +x "$tmp/bin/adb"

  if HOPE_ADB_RECOVERY_DELAY_SECONDS=0        HOPE_ADB_RECOVERY_ATTEMPTS=3        hope_android_device_ready emulator-5554; then
    echo "FAIL: perpetual offline device unexpectedly became ready" >&2
    return 1
  fi

  grep -Fq -- "kill-server" "$LOG"
  grep -Fq -- "start-server" "$LOG"
}


run_app_activity_recovery_case() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/bin"
  export LOG="$tmp/adb.log"
  export STATE_FILE="$tmp/resolve-state"
  export PATH="$tmp/bin:$PATH"
  : > "$LOG"
  echo 0 > "$STATE_FILE"
  printf 'fake-apk' > "$tmp/runtime.apk"

  cat > "$tmp/bin/adb" <<'ADB'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${LOG:?}"
case "$*" in
  *" shell pm path com.hope.marketplace")
    echo "package:/data/app/com.hope.marketplace/base.apk"
    ;;
  *" shell cmd package resolve-activity --brief "*)
    n="$(cat "${STATE_FILE:?}")"
    n=$((n + 1))
    echo "$n" > "$STATE_FILE"
    if [ "$n" -eq 1 ]; then
      echo "No activity found"
    else
      echo "com.hope.marketplace/.MainActivity"
    fi
    ;;
  *" install -r "*)
    echo "Success"
    ;;
  *" shell am start -W -n com.hope.marketplace/.MainActivity")
    echo "Starting: Intent { cmp=com.hope.marketplace/.MainActivity }"
    echo "Status: ok"
    ;;
  *" shell dumpsys package com.hope.marketplace")
    echo "Package [com.hope.marketplace]"
    ;;
  *" shell cmd package query-activities "*)
    echo "com.hope.marketplace/.MainActivity"
    ;;
  *)
    echo "unexpected adb command: $*" >&2
    exit 1
    ;;
esac
ADB
  chmod +x "$tmp/bin/adb"

  hope_android_app_activity_ready emulator-5554 com.hope.marketplace "$tmp/runtime.apk" > "$tmp/result.txt"
  grep -Fq "HOPE_APP_ACTIVITY_UNRESOLVED: reinstalling exact runtime APK once" "$tmp/result.txt"
  grep -Fq "HOPE_APP_ACTIVITY_LAUNCHED:com.hope.marketplace/.MainActivity" "$tmp/result.txt"
  grep -Fq -- "install -r $tmp/runtime.apk" "$LOG"
  grep -Fq -- "shell am start -W -n com.hope.marketplace/.MainActivity" "$LOG"
}


run_app_package_missing_case() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  mkdir -p "$tmp/bin"
  export LOG="$tmp/adb.log"
  export PATH="$tmp/bin:$PATH"
  : > "$LOG"
  printf 'fake-apk' > "$tmp/runtime.apk"

  cat > "$tmp/bin/adb" <<'ADB'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${LOG:?}"
case "$*" in
  *" shell pm path com.hope.marketplace")
    echo "Unknown package: com.hope.marketplace"
    ;;
  *" install -r "*)
    echo "Success"
    ;;
  *" shell cmd package resolve-activity --brief "*)
    echo "com.hope.marketplace/.MainActivity"
    ;;
  *" shell am start -W -n com.hope.marketplace/.MainActivity")
    echo "Starting: Intent { cmp=com.hope.marketplace/.MainActivity }"
    echo "Status: ok"
    ;;
  *)
    echo "unexpected adb command: $*" >&2
    exit 1
    ;;
esac
ADB
  chmod +x "$tmp/bin/adb"

  hope_android_app_activity_ready emulator-5554 com.hope.marketplace "$tmp/runtime.apk" > "$tmp/result.txt"
  grep -Fq "HOPE_APP_PACKAGE_MISSING: reinstalling exact runtime APK" "$tmp/result.txt"
  grep -Fq "HOPE_APP_ACTIVITY_LAUNCHED:com.hope.marketplace/.MainActivity" "$tmp/result.txt"
  grep -Fq -- "install -r $tmp/runtime.apk" "$LOG"
}

run_recovery_case
echo "PASS: ADB online recovery case"
run_failure_case
echo "PASS: ADB offline failure case"
run_app_activity_recovery_case
echo "PASS: launcher activity resolution recovery case"
run_app_package_missing_case
echo "PASS: missing package reinstall case"

echo "PASS: Android ADB recovery, launcher-activity, and package-reinstall contracts"
