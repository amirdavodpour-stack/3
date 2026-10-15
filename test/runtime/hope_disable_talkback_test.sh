#!/usr/bin/env bash
set -euo pipefail
repo_root="${GITHUB_WORKSPACE:-$PWD}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/repo"
state="$tmp/state"
mkdir -p "$state"
component="com.android.talkback/com.google.android.marvin.talkback.TalkBackService"
printf '%s\n' '1' > "$state/enabled"
printf '%s\n' "$component" > "$state/services"
printf '%s\n' "$component" > "$state/bound"
cat > "$tmp/bin/adb" <<'MOCK_ADB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-s" ]]; then shift 2; fi
if [[ "${1:-}" == "shell" ]]; then shift; fi
case "${1:-}:${2:-}:${3:-}:${4:-}" in
  settings:get:secure:accessibility_enabled) cat "$FAKE_ADB_STATE/enabled" ;;
  settings:get:secure:enabled_accessibility_services)
    if [[ -s "$FAKE_ADB_STATE/services" ]]; then cat "$FAKE_ADB_STATE/services"; else printf '%s\n' 'null'; fi
    ;;
  settings:put:secure:accessibility_enabled) printf '%s\n' "${5:-}" > "$FAKE_ADB_STATE/enabled" ;;
  settings:delete:secure:enabled_accessibility_services)
    : > "$FAKE_ADB_STATE/services"
    if [[ "${FAKE_ADB_STAY_BOUND:-0}" != "1" ]]; then : > "$FAKE_ADB_STATE/bound"; fi
    ;;
  dumpsys:accessibility:*)
    printf 'Bound services:{\n'
    cat "$FAKE_ADB_STATE/bound"
    printf '}\nEnabled services:{{\n'
    cat "$FAKE_ADB_STATE/services"
    printf '}}\n'
    ;;
  *) echo "Unexpected mocked adb request: $*" >&2; exit 99 ;;
esac
MOCK_ADB
chmod +x "$tmp/bin/adb"
PATH="$tmp/bin:$PATH" FAKE_ADB_STATE="$state" GITHUB_WORKSPACE="$tmp/repo" ANDROID_SERIAL="emulator-test" \
  bash "$repo_root/tools/hope-disable-talkback.sh" > "$tmp/helper.log"
grep -Fq 'HOPE_TALKBACK_SERVICE_DISABLED_FOR_VISUAL_CAPTURE:true' "$tmp/helper.log"
grep -Fxq '0' "$tmp/repo/docs/audit/evidence/android-runtime/accessibility-enabled-disabled-check.txt"
grep -Fxq 'true' "$tmp/repo/docs/audit/evidence/android-runtime/accessibility-disabled-for-capture.txt"
grep -Fxq 'false' "$tmp/repo/docs/audit/evidence/android-runtime/talkback-service-bound-before-capture.txt"
printf '%s\n' 'PASS: TalkBack disable helper verifies settings and service-unbound state.'
