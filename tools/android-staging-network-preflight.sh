#!/usr/bin/env bash
set -euo pipefail

: "${API_BASE_URL_STAGING:?API_BASE_URL_STAGING is required}"
ADB_SERIAL="${ANDROID_SERIAL:-emulator-5554}"

HOST="$(
  node --input-type=module -e '
    const url = new URL(process.env.API_BASE_URL_STAGING);
    if (url.protocol !== "https:") throw new Error("API_BASE_URL_STAGING must use HTTPS");
    process.stdout.write(url.hostname);
  '
)"

resolve_ipv4s() {
  getent ahostsv4 "$HOST" | awk '{print $1}' | sort -u | paste -sd, -
}

IPS="${STAGING_RESOLVED_IPS:-}"
if [ -z "$IPS" ]; then
  IPS="$(resolve_ipv4s || true)"
fi
[ -n "$IPS" ] || {
  echo "Unable to resolve staging host on the GitHub runner: $HOST" >&2
  exit 1
}

echo "Android staging network preflight: host=$HOST resolved_ipv4s=$IPS"

adb -s "$ADB_SERIAL" wait-for-device

if adb -s "$ADB_SERIAL" shell "ping -c 1 -W 2 '$HOST'" >/tmp/hope-android-dns-check.log 2>&1; then
  echo "Android guest DNS resolves $HOST."
  exit 0
fi

echo "Android guest DNS could not resolve $HOST; installing a temporary /system/etc/hosts mapping."

if ! adb -s "$ADB_SERIAL" root >/tmp/hope-adb-root.log 2>&1; then
  cat /tmp/hope-adb-root.log >&2 || true
  echo "adb root is required for the Android staging hostname fallback." >&2
  exit 1
fi

adb -s "$ADB_SERIAL" wait-for-device
adb -s "$ADB_SERIAL" remount

# adb remount enables overlayfs/verity state but may explicitly require a reboot
# before /system becomes writable. Reboot, re-root, and remount before editing hosts.
adb -s "$ADB_SERIAL" reboot
adb -s "$ADB_SERIAL" wait-for-device
adb -s "$ADB_SERIAL" root >/tmp/hope-adb-root-after-remount.log 2>&1
adb -s "$ADB_SERIAL" wait-for-device
adb -s "$ADB_SERIAL" remount
adb -s "$ADB_SERIAL" wait-for-device

IFS=',' read -r -a IP_ARRAY <<< "$IPS"
for ip in "${IP_ARRAY[@]}"; do
  [ -n "$ip" ] || continue
  adb -s "$ADB_SERIAL" shell "grep -Fq '$ip $HOST' /system/etc/hosts || echo '$ip $HOST' >> /system/etc/hosts"
done
adb -s "$ADB_SERIAL" shell sync

adb -s "$ADB_SERIAL" shell "ping -c 1 -W 2 '$HOST'" >/tmp/hope-android-host-check.log 2>&1 || {
  cat /tmp/hope-android-host-check.log >&2 || true
  echo "Android guest still cannot reach $HOST after hosts fallback." >&2
  exit 1
}

echo "Android staging hostname fallback is active for $HOST."
