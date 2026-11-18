#!/usr/bin/env bash
set -euo pipefail

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
SDKMANAGER="${SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
ATTEMPTS="${HOPE_ANDROID_EMULATOR_INSTALL_ATTEMPTS:-3}"
RETRY_DELAY="${HOPE_ANDROID_EMULATOR_INSTALL_RETRY_DELAY_SECONDS:-5}"
SYSTEM_IMAGE_PACKAGE="${HOPE_ANDROID_SYSTEM_IMAGE_PACKAGE:-system-images;android-35;default;x86_64}"
SYSTEM_IMAGE_PACKAGE_PATTERN='^system-images;android-[0-9]+;[A-Za-z0-9_-]+;[A-Za-z0-9_-]+$'
SYSTEM_IMAGE_PATH="${SDK_ROOT}/${SYSTEM_IMAGE_PACKAGE//;/\/}"
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
if [[ ! "$SYSTEM_IMAGE_PACKAGE" =~ $SYSTEM_IMAGE_PACKAGE_PATTERN ]]; then
  echo "FAIL: HOPE_ANDROID_SYSTEM_IMAGE_PACKAGE must be a canonical system-images package ID." >&2
  exit 2
fi
if [[ ! -x "$SDKMANAGER" ]]; then
  echo "FAIL: sdkmanager not found at $SDKMANAGER" >&2
  exit 2
fi

# The pinned runner installs these same packages again. Prewarm both here so a
# truncated Emulator OR System Image archive is recovered by one bounded retry.
yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true

for attempt in $(seq 1 "$ATTEMPTS"); do
  echo "HOPE_ANDROID_SDK_PACKAGES_INSTALL_ATTEMPT:$attempt/$ATTEMPTS"
  if "$SDKMANAGER" --install emulator "$SYSTEM_IMAGE_PACKAGE" --channel=0; then
    if [[ -x "$SDK_ROOT/emulator/emulator" ]] &&
      [[ -s "$SYSTEM_IMAGE_PATH/package.xml" ]] &&
      "$SDK_ROOT/emulator/emulator" -version; then
      echo "HOPE_ANDROID_SYSTEM_IMAGE_INSTALL_PASS:package=$SYSTEM_IMAGE_PACKAGE"
      echo "HOPE_ANDROID_EMULATOR_INSTALL_PASS:attempt=$attempt"
      exit 0
    fi
    status=1
  else
    status=$?
  fi
  echo "HOPE_ANDROID_EMULATOR_INSTALL_RETRYABLE_FAILURE:attempt=$attempt:status=$status" >&2
  if (( attempt < ATTEMPTS )); then
    # sdkmanager may leave a truncated download archive after a transport
    # interruption. Clear only ephemeral download/temp caches; never remove an
    # installed SDK package, platform, emulator binary, or cached AVD.
    if [[ -d "$CACHE_DIR" ]]; then
      find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    fi
    if [[ -d "$SDK_TEMP_DIR" ]]; then
      find "$SDK_TEMP_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    fi
    echo "HOPE_ANDROID_INSTALL_CACHE_RESET:attempt=$attempt"
    sleep "$RETRY_DELAY"
  fi
done

echo "HOPE_ANDROID_SDK_PACKAGES_INSTALL_FAIL:attempts=$ATTEMPTS" >&2
exit 1
