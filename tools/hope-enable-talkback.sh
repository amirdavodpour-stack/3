#!/usr/bin/env bash
set -euo pipefail
evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
serial="${ANDROID_SERIAL:-emulator-5554}"
apk_path="${HOPE_TALKBACK_APK:-$runner_temp/hope-talkback.apk}"
expected_source_sha="229212fdf5842191d0a93fc95d9ca1423b346866"
source_sha="${HOPE_TALKBACK_SOURCE_SHA:-}"
talkback_package="${HOPE_TALKBACK_PACKAGE:-com.android.talkback}"
component="$talkback_package/com.google.android.marvin.talkback.TalkBackService"
preferences_activity="$talkback_package/com.android.talkback.TalkBackPreferencesActivity"
mkdir -p "$evidence_dir"
printf '%s\n' 'false' > "$evidence_dir/talkback-service-bound.txt"
printf '%s\n' 'false' > "$evidence_dir/touch-exploration-enabled.txt"
if [[ "${HOPE_TALKBACK_REQUIRED:-0}" != "1" ]]; then
  echo "FAIL: T10 requires HOPE_TALKBACK_REQUIRED=1; refusing an uninstrumented runtime." >&2
  exit 2
fi
if [[ "$source_sha" != "$expected_source_sha" ]]; then
  echo "FAIL: TalkBack source SHA mismatch (expected $expected_source_sha, got $source_sha)." >&2
  exit 3
fi
if [[ ! -s "$apk_path" ]]; then
  echo "FAIL: TalkBack APK was not built at $apk_path." >&2
  exit 4
fi
printf '%s\n' "$source_sha" > "$evidence_dir/talkback-source-sha.txt"
sha256sum "$apk_path" | awk '{print $1}' > "$evidence_dir/talkback-apk-sha256.txt"
if ! adb -s "$serial" install -r "$apk_path" > "$evidence_dir/talkback-install.txt" 2>&1; then
  cat "$evidence_dir/talkback-install.txt" >&2
  exit 5
fi
adb -s "$serial" shell pm path "$talkback_package" > "$evidence_dir/talkback-package-path.txt" 2>&1
if ! grep -Fq 'package:' "$evidence_dir/talkback-package-path.txt"; then
  echo "FAIL: $talkback_package is not installed on the emulator." >&2
  exit 6
fi
# A sideloaded APK starts in Android's stopped/not-launched state. Explicitly open
# its exported service-settings activity before enabling it, so the system can
# start the service rather than leaving it indefinitely in "Binding services".
if ! adb -s "$serial" shell am start -W -n "$preferences_activity" > "$evidence_dir/talkback-launch.txt" 2>&1 ||
   ! grep -Fq 'Status: ok' "$evidence_dir/talkback-launch.txt"; then
  cat "$evidence_dir/talkback-launch.txt" >&2 || true
  echo "FAIL: TalkBack settings activity could not be launched to clear fresh-install stopped state." >&2
  exit 7
fi
adb -s "$serial" shell dumpsys package "$talkback_package" > "$evidence_dir/talkback-package-info.txt" 2>&1 || true
# Secure settings alone are not accepted; verify the exact component inside the
# Bound services block. A component listed only under Binding services is pending,
# not proof that Android has connected the accessibility service.
adb -s "$serial" shell settings put secure enabled_accessibility_services "$component"
adb -s "$serial" shell settings put secure accessibility_enabled 1
# A bound service is not sufficient for touch exploration. Ask Android to enable
# the secure setting, then independently verify the authoritative dumpsys state.
adb -s "$serial" shell settings put secure touch_exploration_enabled 1
bound=false
touch_exploration_enabled=false
for attempt in $(seq 1 30); do
  adb -s "$serial" shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled.txt" 2>&1 || true
  adb -s "$serial" shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services.txt" 2>&1 || true
  adb -s "$serial" shell dumpsys accessibility > "$evidence_dir/accessibility-bound-services.txt" 2>&1 || true
  enabled_value="$(tr -d '\r\n' < "$evidence_dir/accessibility-enabled.txt" 2>/dev/null || true)"
  services_value="$(tr -d '\r\n' < "$evidence_dir/accessibility-services.txt" 2>/dev/null || true)"
  touch_exploration_value="$(grep -Eo 'touchExplorationEnabled=(true|false)' "$evidence_dir/accessibility-bound-services.txt" | tail -n 1 | cut -d= -f2 || true)"
  if [[ "$touch_exploration_value" == "true" ]]; then
    touch_exploration_enabled=true
  else
    touch_exploration_enabled=false
  fi
  bound_services_block="$(
    awk '
      /^[[:space:]]*Bound services:/ { in_bound = 1; print; next }
      in_bound && /^[[:space:]]*(Enabled services|Binding services|Crashed services):/ { exit }
      in_bound { print }
    ' "$evidence_dir/accessibility-bound-services.txt"
  )"
  bound_service_confirmed=false
  if grep -Fq "$component" <<<"$bound_services_block"; then
    bound_service_confirmed=true
  # Android 15/API 35 may report a bound service by its TalkBack label rather
  # than componentName. Corroborate the exact enabled component above and
  # require no pending/crashed binding before accepting this label-only form.
  elif (grep -Fq "Service[label=TalkBack," <<<"$bound_services_block" ||
        grep -Fq "Service[label=TalkBack_" <<<"$bound_services_block") &&
       grep -Fq "Binding services:{}" "$evidence_dir/accessibility-bound-services.txt" &&
       grep -Fq "Crashed services:{}" "$evidence_dir/accessibility-bound-services.txt"; then
    bound_service_confirmed=true
  fi
  if [[ "$enabled_value" == "1" ]] &&
     grep -Fq "$talkback_package" <<<"$services_value" &&
     grep -Fq 'com.google.android.marvin.talkback.TalkBackService' <<<"$services_value" &&
     [[ "$bound_service_confirmed" == "true" ]]; then
    bound=true
    if [[ "$touch_exploration_enabled" == "true" ]]; then
      break
    fi
  fi
  sleep 1
done
printf '%s\n' "$bound" > "$evidence_dir/talkback-service-bound.txt"
printf '%s\n' "$touch_exploration_enabled" > "$evidence_dir/touch-exploration-enabled.txt"
if [[ "$bound" != "true" ]]; then
  echo "FAIL: TalkBack did not bind; secure setting values are insufficient evidence." >&2
  grep -Ei -C 3 'accessibility|talkback|bound service' "$evidence_dir/accessibility-bound-services.txt" >&2 || true
  exit 8
fi
if [[ "$touch_exploration_enabled" != "true" ]]; then
  echo "FAIL: TalkBack is bound but touch exploration remains disabled; refusing T10 interaction evidence." >&2
  grep -Ei -C 3 'touchExplorationEnabled|accessibility|talkback|bound service' "$evidence_dir/accessibility-bound-services.txt" >&2 || true
  exit 9
fi
echo "HOPE_TALKBACK_SERVICE_BOUND:true"
echo "HOPE_TOUCH_EXPLORATION_ENABLED:true"
echo "HOPE_TALKBACK_SOURCE_SHA:$source_sha"
echo "HOPE_TALKBACK_APK_SHA256:$(cat "$evidence_dir/talkback-apk-sha256.txt")"
