#!/usr/bin/env bash
set -euo pipefail

: "${API_BASE_URL_STAGING:?API_BASE_URL_STAGING is required}"

ADB_SERIAL="${ANDROID_SERIAL:-emulator-5554}"
ARTIFACT_DIR="${ANDROID_CERT_ARTIFACT_DIR:-docs/audit/android-emulator}"
mkdir -p "$ARTIFACT_DIR"

HOST="$(node --input-type=module -e 'const u=new URL(process.env.API_BASE_URL_STAGING); if(u.protocol!=="https:") throw new Error("API_BASE_URL_STAGING must use HTTPS"); process.stdout.write(u.hostname);')"

resolve_ipv4s() {
  getent ahostsv4 "$HOST" | awk '{print $1}' | sort -u | paste -sd, -
}

IPS="${STAGING_RESOLVED_IPS:-}"
if [ -z "$IPS" ]; then
  IPS="$(resolve_ipv4s || true)"
fi
[ -n "$IPS" ] || { echo "Unable to resolve staging host on runner: $HOST" >&2; exit 1; }

echo "Android staging network preflight: host=$HOST resolved_ipv4s=$IPS"

wait_for_online_device() {
  adb -s "$ADB_SERIAL" wait-for-device
  for _ in $(seq 1 90); do
    state="$(adb -s "$ADB_SERIAL" get-state 2>/dev/null || true)"
    [ "$state" = "device" ] && return 0
    adb -s "$ADB_SERIAL" reconnect offline >/dev/null 2>&1 || true
    adb -s "$ADB_SERIAL" reconnect device >/dev/null 2>&1 || true
    sleep 2
  done
  echo "Android emulator did not become ADB-online in time." >&2
  adb devices -l >&2 || true
  return 1
}

collect_diagnostics() {
  adb -s "$ADB_SERIAL" devices -l >"$ARTIFACT_DIR/adb-devices.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" get-state >"$ARTIFACT_DIR/adb-state.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell getprop >"$ARTIFACT_DIR/getprop.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell dumpsys connectivity >"$ARTIFACT_DIR/connectivity.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell dumpsys netstats detail >"$ARTIFACT_DIR/netstats.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell ip addr show >"$ARTIFACT_DIR/ip-addr.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell ip rule show >"$ARTIFACT_DIR/ip-rule.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell ip route show table all >"$ARTIFACT_DIR/ip-route-all.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell ip route show >"$ARTIFACT_DIR/ip-route.txt" 2>&1 || true
  adb -s "$ADB_SERIAL" shell logcat -d -t 500 >"$ARTIFACT_DIR/logcat-tail.txt" 2>&1 || true
}

recover_guest_network() {
  echo "Applying non-destructive Android connectivity recovery..." >&2
  adb -s "$ADB_SERIAL" shell 'settings put global airplane_mode_on 0' >/dev/null 2>&1 || true
  adb -s "$ADB_SERIAL" shell 'cmd connectivity airplane-mode disable' >/dev/null 2>&1 || true
  adb -s "$ADB_SERIAL" shell 'svc wifi enable' >/dev/null 2>&1 || true
  adb -s "$ADB_SERIAL" shell 'cmd wifi set-wifi-enabled enabled' >/dev/null 2>&1 || true
  adb -s "$ADB_SERIAL" shell 'svc data enable' >/dev/null 2>&1 || true
  adb -s "$ADB_SERIAL" shell 'cmd connectivity reevaluate' >/dev/null 2>&1 || true
}

wait_for_online_device

echo "Collecting Android network state before route checks..."
adb -s "$ADB_SERIAL" shell ip route show table all >"$ARTIFACT_DIR/ip-route-initial.txt" 2>&1 || true
adb -s "$ADB_SERIAL" shell ip rule show >"$ARTIFACT_DIR/ip-rule-initial.txt" 2>&1 || true
adb -s "$ADB_SERIAL" shell ip addr show >"$ARTIFACT_DIR/ip-addr-initial.txt" 2>&1 || true
adb -s "$ADB_SERIAL" shell dumpsys connectivity >"$ARTIFACT_DIR/connectivity-initial.txt" 2>&1 || true
adb -s "$ADB_SERIAL" shell getprop | grep -E 'net\.dns|^\[dhcp\.|^\[wifi\.' >"$ARTIFACT_DIR/dns-properties.txt" 2>&1 || true
adb -s "$ADB_SERIAL" shell cmd connectivity reevaluate >/tmp/hope-android-reevaluate.log 2>&1 || true

TARGET_IP="$(printf '%s' "$IPS" | cut -d',' -f1)"
ROUTE_OK=false
ROUTE_LOOKUP=""

for _ in $(seq 1 30); do
  ROUTE_LOOKUP="$(adb -s "$ADB_SERIAL" shell "ip route get '$TARGET_IP'" 2>&1 | tr -d '\r' || true)"
  if [ -n "$ROUTE_LOOKUP" ] && ! printf '%s\n' "$ROUTE_LOOKUP" | grep -Eq '(^|[[:space:]])(unreachable|prohibit|blackhole|throw)([[:space:]]|$)'; then
    if printf '%s\n' "$ROUTE_LOOKUP" | grep -Eq '(^|[[:space:]])dev[[:space:]]+[[:alnum:]_.-]+'; then
      ROUTE_OK=true
      break
    fi
  fi
  recover_guest_network
  sleep 2
done

printf '%s\n' "$ROUTE_LOOKUP" >"$ARTIFACT_DIR/ip-route-get.txt"

if [ "$ROUTE_OK" != "true" ]; then
  echo "Android emulator has no usable route to staging target $TARGET_IP." >&2
  collect_diagnostics
  echo "--- ip rule show ---" >&2
  cat "$ARTIFACT_DIR/ip-rule.txt" >&2 || true
  echo "--- ip route show table all ---" >&2
  cat "$ARTIFACT_DIR/ip-route-all.txt" >&2 || true
  echo "--- ip route get $TARGET_IP ---" >&2
  cat "$ARTIFACT_DIR/ip-route-get.txt" >&2 || true
  echo "--- connectivity ---" >&2
  cat "$ARTIFACT_DIR/connectivity.txt" >&2 || true
  exit 1
fi

echo "Android emulator has a usable route to staging target $TARGET_IP."
cat "$ARTIFACT_DIR/ip-route-get.txt"

DNS_OK=false
for _ in $(seq 1 12); do
  if adb -s "$ADB_SERIAL" shell "host -W 3 -t A '$HOST'" >"$ARTIFACT_DIR/dns-check.txt" 2>&1; then
    DNS_OK=true
    break
  fi
  adb -s "$ADB_SERIAL" shell cmd connectivity reevaluate >/dev/null 2>&1 || true
  sleep 2
done

if [ "$DNS_OK" != "true" ]; then
  echo "Primary emulator DNS path did not resolve $HOST; attempting targeted netd resolver recovery." >&2

  net_id="$(adb -s "$ADB_SERIAL" shell 'cmd connectivity get-active-network 2>/dev/null' | tr -d '\r' | grep -Eo '[0-9]+' | head -n 1 || true)"
  if [ -z "$net_id" ]; then
    net_id="$(adb -s "$ADB_SERIAL" shell dumpsys connectivity 2>/dev/null | grep -Eio '((Active default network|mActiveDefaultNetwork)[^0-9]*[0-9]+)' | grep -Eo '[0-9]+' | tail -n 1 | tr -d '\r' || true)"
  fi

  if [ -n "$net_id" ] && adb -s "$ADB_SERIAL" root >/tmp/hope-adb-root-dns.log 2>&1; then
    cat /tmp/hope-adb-root-dns.log >&2 || true
    wait_for_online_device
    adb -s "$ADB_SERIAL" shell "ndc resolver setnetdns '$net_id' '' 8.8.8.8 8.8.4.4" >"$ARTIFACT_DIR/ndc-setnetdns.txt" 2>&1 || true
    adb -s "$ADB_SERIAL" shell "ndc resolver flushnet '$net_id'" >"$ARTIFACT_DIR/ndc-flushnet.txt" 2>&1 || true
    adb -s "$ADB_SERIAL" shell "cmd connectivity reevaluate" >"$ARTIFACT_DIR/connectivity-reevaluate.txt" 2>&1 || true
    sleep 3
    for _ in $(seq 1 12); do
      if adb -s "$ADB_SERIAL" shell "host -W 3 -t A '$HOST'" >"$ARTIFACT_DIR/dns-check.txt" 2>&1; then
        DNS_OK=true
        break
      fi
      sleep 2
    done
  else
    echo "No active network id was available for resolver recovery." >&2
    cat /tmp/hope-adb-root-dns.log >&2 2>/dev/null || true
  fi
fi

if [ "$DNS_OK" = "true" ]; then
  echo "Android guest DNS resolves $HOST."
  cat "$ARTIFACT_DIR/dns-check.txt"
else
  echo "Android guest DNS did not resolve $HOST during preflight; continuing to the real Flutter HTTPS smoke test." >&2
  echo "Runner-resolved IPv4s: $IPS" >&2
  cat "$ARTIFACT_DIR/dns-check.txt" >&2 2>/dev/null || true
fi

exit 0
