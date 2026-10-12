#!/usr/bin/env bash
set -euo pipefail
evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
runner_temp="${RUNNER_TEMP:-/tmp}"
serial="${ANDROID_SERIAL:-emulator-5554}"
apk_path="${HOPE_TALKBACK_APK:-$runner_temp/hope-talkback.apk}"
expected_source_sha="229212fdf5842191d0a93fc95d9ca1423b346866"
source_sha="${HOPE_TALKBACK_SOURCE_SHA:-}"
component="com.android.talkback/com.google.android.marvin.talkback.TalkBackService"
mkdir -p "$evidence_dir"
printf '%s\n' 'false' > "$evidence_dir/talkback-service-bound.txt"
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
adb -s "$serial" shell pm path com.android.talkback > "$evidence_dir/talkback-package-path.txt" 2>&1
if ! grep -Fq 'package:' "$evidence_dir/talkback-package-path.txt"; then
  echo "FAIL: com.android.talkback is not installed on the emulator." >&2
  exit 6
fi
adb -s "$serial" shell dumpsys package com.android.talkback > "$evidence_dir/talkback-package-info.txt" 2>&1 || true
# Secure settings alone are not accepted; verify the actual bound AccessibilityManager service.
adb -s "$serial" shell settings put secure enabled_accessibility_services "$component"
adb -s "$serial" shell settings put secure accessibility_enabled 1
bound=false
for attempt in $(seq 1 30); do
  adb -s "$serial" shell settings get secure accessibility_enabled > "$evidence_dir/accessibility-enabled.txt" 2>&1 || true
  adb -s "$serial" shell settings get secure enabled_accessibility_services > "$evidence_dir/accessibility-services.txt" 2>&1 || true
  adb -s "$serial" shell dumpsys accessibility > "$evidence_dir/accessibility-bound-services.txt" 2>&1 || true
  enabled_value="$(tr -d '\r\n' < "$evidence_dir/accessibility-enabled.txt" 2>/dev/null || true)"
  services_value="$(tr -d '\r\n' < "$evidence_dir/accessibility-services.txt" 2>/dev/null || true)"
  if [[ "$enabled_value" == "1" ]] &&
     grep -Fq 'com.android.talkback' <<<"$services_value" &&
     grep -Fq 'com.google.android.marvin.talkback.TalkBackService' <<<"$services_value" &&
     grep -Eiq 'bound services' "$evidence_dir/accessibility-bound-services.txt" &&
     grep -Fq 'com.android.talkback' "$evidence_dir/accessibility-bound-services.txt" &&
     grep -Fq 'com.google.android.marvin.talkback.TalkBackService' "$evidence_dir/accessibility-bound-services.txt"; then
    bound=true
    break
  fi
  sleep 1
done
printf '%s\n' "$bound" > "$evidence_dir/talkback-service-bound.txt"
if [[ "$bound" != "true" ]]; then
  echo "FAIL: TalkBack did not bind; secure setting values are insufficient evidence." >&2
  grep -Ei -C 3 'accessibility|talkback|bound service' "$evidence_dir/accessibility-bound-services.txt" >&2 || true
  exit 7
fi
echo "HOPE_TALKBACK_SERVICE_BOUND:true"
echo "HOPE_TALKBACK_SOURCE_SHA:$source_sha"
echo "HOPE_TALKBACK_APK_SHA256:$(cat "$evidence_dir/talkback-apk-sha256.txt")"
