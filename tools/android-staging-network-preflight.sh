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

wait_for_online_device() {
  adb -s "$ADB_SERIAL" wait-for-device
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

# Do not remount /system or edit /system/etc/hosts during certification.
# API 35 emulator images can lose their guest network after an overlayfs
# remount/reboot cycle. The emulator runner already supports explicit DNS
# servers, so the certification should validate the real DNS path directly.
for _ in $(seq 1 45); do
  if adb -s "$ADB_SERIAL" shell "host -t A '$HOST'" >/tmp/hope-android-dns-check.log 2>&1; then
    echo "Android guest DNS resolves $HOST."
    cat /tmp/hope-android-dns-check.log
    exit 0
  fi
  sleep 2
done

echo "Android guest DNS could not resolve $HOST after 90 seconds." >&2
echo "Runner-resolved IPv4s: $IPS" >&2
echo "Android DNS properties:" >&2
adb -s "$ADB_SERIAL" shell getprop | grep -Ei '(^|\[)net\.dns|dns[._-]?(1|2|3|4)' >&2 || true
echo "Android connectivity state:" >&2
adb -s "$ADB_SERIAL" shell dumpsys connectivity 2>/dev/null | head -n 120 >&2 || true
echo "Android routes/interfaces:" >&2
adb -s "$ADB_SERIAL" shell ip addr show >&2 || true
adb -s "$ADB_SERIAL" shell ip route show >&2 || true

IFS=',' read -r -a IP_ARRAY <<< "$IPS"
for ip in "${IP_ARRAY[@]}"; do
  [ -n "$ip" ] || continue
  if adb -s "$ADB_SERIAL" shell "ping -c 1 -W 2 '$ip'" >/tmp/hope-android-ip-check.log 2>&1; then
    echo "Android guest can reach staging IP $ip but cannot resolve $HOST." >&2
    cat /tmp/hope-android-ip-check.log >&2 || true
  fi
done

exit 1
