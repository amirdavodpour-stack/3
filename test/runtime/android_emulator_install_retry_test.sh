#!/usr/bin/env bash
set -euo pipefail

ROOT="$PWD"
installer="$ROOT/tools/install-android-emulator-retry.sh"

run_case() (
  local success_at="$1"
  local expected_status="$2"
  local expected_attempts="$3"
  local tmp status attempts

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  export HOME="$tmp/home"
  export ANDROID_HOME="$tmp/sdk"
  export FAKE_STATE_FILE="$tmp/attempts"
  export FAKE_SUCCESS_AT="$success_at"
  mkdir -p "$HOME/.android/cache" "$ANDROID_HOME/.temp" "$ANDROID_HOME/cmdline-tools/latest/bin"
  printf 'stale-download-cache' > "$HOME/.android/cache/stale-package.zip"
  printf 'partial-package' > "$ANDROID_HOME/.temp/package.partial"

  cat > "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" <<'FAKE_SDKMANAGER'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == *"--licenses"* ]]; then
  exit 0
fi

attempt=0
if [[ -f "$FAKE_STATE_FILE" ]]; then
  attempt="$(cat "$FAKE_STATE_FILE")"
fi
attempt=$((attempt + 1))
printf '%s\n' "$attempt" > "$FAKE_STATE_FILE"

if (( attempt >= FAKE_SUCCESS_AT )); then
  mkdir -p "$ANDROID_HOME/emulator"
  cat > "$ANDROID_HOME/emulator/emulator" <<'FAKE_EMULATOR'
#!/usr/bin/env bash
echo 'Android Emulator test-stub'
FAKE_EMULATOR
  chmod +x "$ANDROID_HOME/emulator/emulator"
  exit 0
fi

mkdir -p "$HOME/.android/cache" "$ANDROID_HOME/.temp"
printf 'corrupt zip' > "$HOME/.android/cache/truncated-emulator.zip"
printf 'partial install' > "$ANDROID_HOME/.temp/emulator.partial"
echo 'Error on ZipFile unknown archive.' >&2
exit 1
FAKE_SDKMANAGER
  chmod +x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

  if HOPE_ANDROID_EMULATOR_INSTALL_RETRY_DELAY_SECONDS=0 \
     HOPE_ANDROID_EMULATOR_INSTALL_ATTEMPTS=3 \
     bash "$installer" > "$tmp/output.log" 2>&1; then
    status=0
  else
    status=$?
  fi

  attempts="$(cat "$FAKE_STATE_FILE")"
  if [[ "$status" != "$expected_status" || "$attempts" != "$expected_attempts" ]]; then
    cat "$tmp/output.log" >&2
    echo "FAIL: expected status=$expected_status attempts=$expected_attempts; got status=$status attempts=$attempts" >&2
    return 1
  fi

  if [[ "$expected_status" == "0" ]]; then
    grep -Fq "HOPE_ANDROID_EMULATOR_INSTALL_PASS:attempt=$expected_attempts" "$tmp/output.log"
    grep -Fq "Android Emulator test-stub" "$tmp/output.log"
    [[ ! -e "$HOME/.android/cache/truncated-emulator.zip" ]]
    [[ ! -e "$ANDROID_HOME/.temp/emulator.partial" ]]
    echo "PASS: corrupted package cache is cleared and install succeeds on retry"
  else
    grep -Fq "HOPE_ANDROID_EMULATOR_INSTALL_FAIL:attempts=3" "$tmp/output.log"
    echo "PASS: emulator package install fails closed after the bounded retry count"
  fi
)

bash -n "$installer"
run_case 2 0 2
run_case 99 1 3
echo "PASS: Android Emulator installer retry contract"
