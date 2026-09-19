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

wait_for_online_device() {
  for _ in $(seq 1 90); do
    state="$(adb -s "$ADB_SERIAL" get-state 2>/dev/null || true)"
    if [ "$state" = "device" ]; then
      return 0
    fi
    adb -s "$ADB_SERIAL" reconnect offline >/dev/null 2>&1 || true
    adb -s "$ADB_SERIAL" reconnect device >/dev/null 2>&1 || true
    sleep 2
  done
  echo "Android emulator did not become ADB-online in time (state=$(adb -s "$ADB_SERIAL" get-state 2>&1 || true))." >&2
  adb devices -l >&2 || true
  exit 1
}

wait_for_online_device

if adb -s "$ADB_SERIAL" shell "host -t A '$HOST'" >/tmp/hope-android-dns-check.log 2>&1; then
  echo "Android guest DNS resolves $HOST."
  cat /tmp/hope-android-dns-check.log
  exit 0
fi

echo "Android guest DNS could not resolve $HOST; installing a temporary /system/etc/hosts mapping."

if ! adb -s "$ADB_SERIAL" root >/tmp/hope-adb-root.log 2>&1; then
  cat /tmp/hope-adb-root.log >&2 || true
  echo "adb root is required for the Android staging hostname fallback." >&2
  exit 1
fi

# Follow Android's supported overlayfs sequence: root -> disable-verity -> reboot -> root -> remount.
adb -s "$ADB_SERIAL" disable-verity >/tmp/hope-disable-verity.log 2>&1 || {
  cat /tmp/hope-disable-verity.log >&2 || true
  echo "adb disable-verity failed." >&2
  exit 1
}
cat /tmp/hope-disable-verity.log

adb -s "$ADB_SERIAL" reboot
adb -s "$ADB_SERIAL" wait-for-device
wait_for_online_device
adb -s "$ADB_SERIAL" root >/tmp/hope-adb-root-after-reboot.log 2>&1 || {
  cat /tmp/hope-adb-root-after-reboot.log >&2 || true
  echo "adb root failed after overlayfs reboot." >&2
  exit 1
}
cat /tmp/hope-adb-root-after-reboot.log
adb -s "$ADB_SERIAL" wait-for-device
wait_for_online_device
adb -s "$ADB_SERIAL" remount
adb -s "$ADB_SERIAL" wait-for-device

# Reboot after remount rather than issuing stop/start to the Android framework. On
# GitHub-hosted API 35 images, stop/start can leave wlan0/eth0 administratively down;
# a clean reboot restores the emulator network stack while preserving the writable
# overlayfs state for the hosts mapping below.
adb -s "$ADB_SERIAL" reboot
adb -s "$ADB_SERIAL" wait-for-device
wait_for_online_device

# Remounting can restart system services; require a working route before host-file validation.
NETWORK_READY=false
for _ in $(seq 1 45); do
  if adb -s "$ADB_SERIAL" shell "ping -c 1 -W 2 1.1.1.1" >/tmp/hope-android-network-check.log 2>&1; then
    NETWORK_READY=true
    break
  fi
  sleep 2
done

if [ "$NETWORK_READY" != "true" ]; then
  echo "Android guest has no working network route after overlayfs remount/framework restart." >&2
  cat /tmp/hope-android-network-check.log >&2 || true
  adb -s "$ADB_SERIAL" shell ip addr show >&2 || true
  adb -s "$ADB_SERIAL" shell ip route show >&2 || true
  exit 1
fi

IFS=',' read -r -a IP_ARRAY <<< "$IPS"
for ip in "${IP_ARRAY[@]}"; do
  [ -n "$ip" ] || continue
  adb -s "$ADB_SERIAL" shell "grep -Fq '$ip $HOST' /system/etc/hosts || echo '$ip $HOST' >> /system/etc/hosts"
done
adb -s "$ADB_SERIAL" shell sync

adb -s "$ADB_SERIAL" shell "host -t A '$HOST'" >/tmp/hope-android-host-check.log 2>&1 || {
  cat /tmp/hope-android-host-check.log >&2 || true
  echo "Android guest still cannot resolve $HOST after hosts fallback." >&2
  exit 1
}

cat /tmp/hope-android-host-check.log
echo "Android staging hostname fallback is active for $HOST."
