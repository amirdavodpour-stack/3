#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
SDKMANAGER="${SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
ATTEMPTS="${HOPE_ANDROID_EMULATOR_INSTALL_ATTEMPTS:-3}"
RETRY_DELAY="${HOPE_ANDROID_EMULATOR_INSTALL_RETRY_DELAY_SECONDS:-5}"
CACHE_DIR="${HOME:?HOME must be set}/.android/cache"
SDK_TEMP_DIR="${SDK_ROOT}/.temp"

if [[ ! "$ATTEMPTS" =~ ^[1-5]$ ]]; then
  echo "FAIL: HOPE_ANDROID_EMULATOR_INSTALL_ATTEMPTS must be an integer from 1 to 5." >&2
  exit 2
fi
if [[ ! "$RETRY_DELAY" =~ ^[0-9]+$ ]] || (( RETRY_DELAY > 30 )); then
  echo "FAIL: HOPE_ANDROID_EMULATOR_INSTALL_RETRY_DELAY_SECONDS must be an integer from 0 to 30." >&2
  exit 2
fi
if [[ ! -x "$SDKMANAGER" ]]; then
  echo "FAIL: sdkmanager not found at $SDKMANAGER" >&2
  exit 2
fi

# Accepting licenses is idempotent. The pinned emulator-runner invokes the
# same package install again; prewarming makes that subsequent call a no-op
# when the package metadata is unchanged.
yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true

for attempt in $(seq 1 "$ATTEMPTS"); do
  echo "HOPE_ANDROID_EMULATOR_INSTALL_ATTEMPT:$attempt/$ATTEMPTS"
  if "$SDKMANAGER" --install emulator --channel=0; then
    if [[ -x "$SDK_ROOT/emulator/emulator" ]] &&
      "$SDK_ROOT/emulator/emulator" -version; then
      echo "HOPE_ANDROID_EMULATOR_INSTALL_PASS:attempt=$attempt"
      exit 0
    fi
    status=1
  else
    status=$?
  fi
  echo "HOPE_ANDROID_EMULATOR_INSTALL_RETRYABLE_FAILURE:attempt=$attempt:status=$status" >&2
  if (( attempt < ATTEMPTS )); then
    # sdkmanager can leave a truncated archive after a transport interruption.
    # Clear only ephemeral package download/temp caches, never installed SDK
    # components or the cached AVD, then allow a fresh download.
    if [[ -d "$CACHE_DIR" ]]; then
      find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    fi
    if [[ -d "$SDK_TEMP_DIR" ]]; then
      find "$SDK_TEMP_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    fi
    echo "HOPE_ANDROID_EMULATOR_INSTALL_CACHE_RESET:attempt=$attempt"
    sleep "$RETRY_DELAY"
  fi
done

echo "HOPE_ANDROID_EMULATOR_INSTALL_FAIL:attempts=$ATTEMPTS" >&2
exit 1
