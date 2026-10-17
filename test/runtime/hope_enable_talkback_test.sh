#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
talkback_package="com.hopev2.ci.talkback"
component="$talkback_package/com.google.android.marvin.talkback.TalkBackService"
preferences_activity="$talkback_package/com.android.talkback.TalkBackPreferencesActivity"
source_sha="229212fdf5842191d0a93fc95d9ca1423b346866"
mkdir -p "$tmp/bin" "$tmp/runner"
printf '%s\n' 'built TalkBack APK placeholder' > "$tmp/runner/hope-talkback.apk"

cat > "$tmp/bin/adb" <<'MOCK_ADB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-s" ]]; then shift 2; fi
if [[ "${1:-}" == "install" ]]; then
  printf '%s\n' 'Success'
  exit 0
fi
if [[ "${1:-}" == "shell" ]]; then shift; fi
command_line="$*"
case "$command_line" in
  "pm path $FAKE_TALKBACK_PACKAGE")
    printf 'package:/data/app/%s/base.apk\n' "$FAKE_TALKBACK_PACKAGE"
    ;;
  "am start -W -n $FAKE_TALKBACK_PACKAGE/com.android.talkback.TalkBackPreferencesActivity")
    printf 'Starting: Intent { cmp=%s/com.android.talkback.TalkBackPreferencesActivity }\n' "$FAKE_TALKBACK_PACKAGE"
    printf '%s\n' 'Status: ok'
    printf 'Activity: %s/com.android.talkback.TalkBackPreferencesActivity\n' "$FAKE_TALKBACK_PACKAGE"
    ;;
  "dumpsys package $FAKE_TALKBACK_PACKAGE")
    printf '%s\n' 'User 0: installed=true hidden=false stopped=false notLaunched=false enabled=0'
    ;;
  "settings put secure enabled_accessibility_services "*)
    exit 0
    ;;
  "settings put secure accessibility_enabled 1")
    exit 0
    ;;
  "settings put secure touch_exploration_enabled 1")
    exit 0
    ;;
  "settings get secure accessibility_enabled")
    printf '%s\n' '1'
    ;;
  "settings get secure enabled_accessibility_services")
    printf '%s\n' "$FAKE_TALKBACK_COMPONENT"
    ;;
  "dumpsys accessibility")
    local_touch_exploration=false
    local_bound_services=""
    local_binding_services="{}"
    case "$FAKE_TALKBACK_MODE" in
      bound)
        local_touch_exploration=true
        local_bound_services="Service[label=TalkBack_TfP, feedbackType[FEEDBACK_SPOKEN, FEEDBACK_HAPTIC, FEEDBACK_AUDIBLE], capabilities=251, eventTypes=TYPES_ALL_MASK, notificationTimeout=0, requestA11yBtn=false]"
        ;;
      bound-no-touch)
        local_bound_services="Service[label=TalkBack_TfP, feedbackType[FEEDBACK_SPOKEN, FEEDBACK_HAPTIC, FEEDBACK_AUDIBLE], capabilities=251, eventTypes=TYPES_ALL_MASK, notificationTimeout=0, requestA11yBtn=false]"
        ;;
      *)
        local_binding_services="{$FAKE_TALKBACK_COMPONENT}"
        ;;
    esac
    cat <<EOF
ACCESSIBILITY MANAGER (dumpsys accessibility)
User state[
 attributes:{id=0, touchExplorationEnabled=$local_touch_exploration}
 Bound services:{ $local_bound_services }
 Enabled services:{{$FAKE_TALKBACK_COMPONENT}}
 Binding services:$local_binding_services
 Crashed services:{}
EOF
    ;;
  *)
    printf 'Unexpected mocked adb command: %s\n' "$command_line" >&2
    exit 99
    ;;
esac
MOCK_ADB
chmod +x "$tmp/bin/adb"

cat > "$tmp/bin/sleep" <<'MOCK_SLEEP'
#!/usr/bin/env bash
exit 0
MOCK_SLEEP
chmod +x "$tmp/bin/sleep"

run_scenario() {
  local mode="$1"
  local case_repo="$tmp/repo-$mode"
  mkdir -p "$case_repo"
  env \
    PATH="$tmp/bin:/usr/bin:/bin" \
    GITHUB_WORKSPACE="$case_repo" \
    RUNNER_TEMP="$tmp/runner" \
    ANDROID_SERIAL="emulator-test" \
    HOPE_TALKBACK_REQUIRED="1" \
    HOPE_TALKBACK_APK="$tmp/runner/hope-talkback.apk" \
    HOPE_TALKBACK_SOURCE_SHA="$source_sha" \
    HOPE_TALKBACK_PACKAGE="$talkback_package" \
    FAKE_TALKBACK_MODE="$mode" \
    FAKE_TALKBACK_COMPONENT="$component" \
    FAKE_TALKBACK_PACKAGE="$talkback_package" \
    bash "$repo_root/tools/hope-enable-talkback.sh" > "$tmp/$mode.log" 2>&1
}

if ! run_scenario bound; then
  cat "$tmp/bound.log" >&2
  echo "FAIL: a service explicitly present under Bound services should pass." >&2
  exit 1
fi
grep -Fxq 'true' "$tmp/repo-bound/docs/audit/evidence/android-runtime/talkback-service-bound.txt"
grep -Fxq 'true' "$tmp/repo-bound/docs/audit/evidence/android-runtime/touch-exploration-enabled.txt"
grep -Fq 'HOPE_TALKBACK_SERVICE_BOUND:true' "$tmp/bound.log"
grep -Fq 'HOPE_TOUCH_EXPLORATION_ENABLED:true' "$tmp/bound.log"

if run_scenario bound-no-touch; then
  echo "FAIL: a bound TalkBack service with touch exploration disabled must not be accepted." >&2
  exit 1
fi
grep -Fxq 'true' "$tmp/repo-bound-no-touch/docs/audit/evidence/android-runtime/talkback-service-bound.txt"
grep -Fxq 'false' "$tmp/repo-bound-no-touch/docs/audit/evidence/android-runtime/touch-exploration-enabled.txt"
grep -Fq 'FAIL: TalkBack is bound but touch exploration remains disabled; refusing T10 interaction evidence.' "$tmp/bound-no-touch.log"

if run_scenario binding-only; then
  echo "FAIL: a service listed only under Binding services must not be accepted as bound." >&2
  exit 1
fi
grep -Fxq 'false' "$tmp/repo-binding-only/docs/audit/evidence/android-runtime/talkback-service-bound.txt"
grep -Fxq 'false' "$tmp/repo-binding-only/docs/audit/evidence/android-runtime/touch-exploration-enabled.txt"
grep -Fq 'FAIL: TalkBack did not bind; secure setting values are insufficient evidence.' "$tmp/binding-only.log"

printf '%s\n' 'PASS: TalkBack validator requires a bound service AND enabled touch exploration; rejects Binding-only state.'
