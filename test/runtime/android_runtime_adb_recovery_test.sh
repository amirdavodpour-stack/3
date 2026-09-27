#!/usr/bin/env bash
set -euo pipefail

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

run_recovery_case
run_failure_case

echo "PASS: Android ADB recovery contract"
