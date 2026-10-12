#!/usr/bin/env bash
set -euo pipefail
evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
serial="${ANDROID_SERIAL:-emulator-5554}"
timeout_seconds="${HOPE_ADB_TIMEOUT_SECONDS:-20}"
kill_after_seconds="${HOPE_ADB_KILL_AFTER_SECONDS:-5}"
component="com.android.talkback/com.google.android.marvin.talkback.TalkBackService"
mkdir -p "$evidence_dir"
adb_call() {
  timeout --foreground --signal=TERM --kill-after="${kill_after_seconds}s" "${timeout_seconds}s" \
    adb -s "$serial" "$@"
}
adb_call shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled-before.txt" 2>&1 || true
adb_call shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services-before.txt" 2>&1 || true
adb_call shell settings put secure accessibility_enabled 0
adb_call shell settings delete secure enabled_accessibility_services
disabled=false
for attempt in $(seq 1 30); do
  adb_call shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled-disabled-check.txt" 2>&1 || true
  adb_call shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services-disabled-check.txt" 2>&1 || true
  adb_call shell dumpsys accessibility > "$evidence_dir/accessibility-bound-services-disabled-check.txt" 2>&1 || true
  enabled_value="$(tr -d '\r\n' < "$evidence_dir/accessibility-enabled-disabled-check.txt" 2>/dev/null || true)"
  services_value="$(tr -d '\r\n' < "$evidence_dir/accessibility-services-disabled-check.txt" 2>/dev/null || true)"
  bound_services="$(sed -n '/Bound services:/,/Enabled services:/p' "$evidence_dir/accessibility-bound-services-disabled-check.txt" 2>/dev/null || true)"
  if [[ "$enabled_value" == "0" ]] &&
     { [[ -z "$services_value" ]] || [[ "$services_value" == "null" ]]; } &&
     ! grep -Fq -- "$component" <<< "$bound_services"; then
    disabled=true
    break
  fi
  sleep 0.25
done
printf '%s\n' "$disabled" > "$evidence_dir/accessibility-disabled-for-capture.txt"
if [[ "$disabled" != "true" ]]; then
  printf '%s\n' 'false' > "$evidence_dir/talkback-service-bound-before-capture.txt"
  echo "FAIL: TalkBack/accessibility service is still active; refusing visual baseline capture." >&2
  grep -Ei -C 3 'accessibility|talkback|bound service' "$evidence_dir/accessibility-bound-services-disabled-check.txt" >&2 || true
  exit 7
fi
printf '%s\n' 'false' > "$evidence_dir/talkback-service-bound-before-capture.txt"
echo "HOPE_TALKBACK_SERVICE_DISABLED_FOR_VISUAL_CAPTURE:true"
