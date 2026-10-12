#!/usr/bin/env bash
set -euo pipefail

script="${1:-tools/hope-wallet-runtime-evidence.sh}"
driver="${2:-test_driver/hope_runtime_screenshot_driver.dart}"
test_file="${3:-integration_test/runtime/critical_screens_evidence_test.dart}"
if [[ -x /system/bin/toybox ]]; then
  T="/system/bin/toybox"
  grep_fixed() { "$T" grep "$@"; }
else
  grep_fixed() { grep "$@"; }
fi

grep_fixed -Fq -- 'flutter drive' "$script"
grep_fixed -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep_fixed -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep_fixed -Fq -- 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
grep_fixed -Fq -- 'HOPE_CAPTURE_TEXT_SCALE="${CAPTURE_TEXT_SCALE}"' "$script"
grep_fixed -Fq -- '"text_scale": $CAPTURE_TEXT_SCALE' "$script"
grep_fixed -Fq -- 'RUNTIME_TEST_TIMEOUT_SECONDS=' "$script"
grep_fixed -Fq -- 'timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s"' "$script"
grep_fixed -Fq -- 'validate_capture_set "baseline-$CAPTURE_LOCALE"' "$script"
grep_fixed -Fq -- 'validate_capture_set "responsive-$CAPTURE_LOCALE-a"' "$script"
en_transactions_line="$(grep -nF '"responsive-720x1280-transactions-en-ltr"' "$script" | head -n 1 | cut -d: -f1)"
en_wallet_line="$(grep -nF '"responsive-720x1280-wallet-en-ltr"' "$script" | head -n 1 | cut -d: -f1)"
en_profile_line="$(grep -nF '"responsive-720x1280-profile-en-ltr"' "$script" | head -n 1 | cut -d: -f1)"
test "$en_transactions_line" -lt "$en_wallet_line"
test "$en_wallet_line" -lt "$en_profile_line"
driver_transactions_line="$(grep -nF "'transactions': () =>" "$test_file" | tail -n 1 | cut -d: -f1)"
driver_wallet_line="$(grep -nF "'wallet': () =>" "$test_file" | tail -n 1 | cut -d: -f1)"
driver_profile_line="$(grep -nF "'profile': () =>" "$test_file" | tail -n 1 | cut -d: -f1)"
test "$driver_transactions_line" -lt "$driver_wallet_line"
test "$driver_wallet_line" -lt "$driver_profile_line"
grep_fixed -Fq -- 'await integrationDriver(' "$driver"

grep_fixed -Fq -- 'onScreenshot:' "$driver"
grep_fixed -Fq -- 'writeAsBytes(image, flush: true)' "$driver"
grep_fixed -Fq -- "const outputRoot = 'docs/audit/evidence/android-runtime';" "$driver"
grep_fixed -Fq -- 'docs/audit/evidence/android-runtime' "$driver"

grep_fixed -Fq -- 'IntegrationTestWidgetsFlutterBinding.ensureInitialized' "$test_file"
grep_fixed -Fq -- 'await binding.convertFlutterSurfaceToImage();' "$test_file"
grep_fixed -Fq -- "MethodChannel('hope.runtime/screenshot')" "$test_file"
grep_fixed -Fq -- "'captureScreenshot'," "$test_file"
grep_fixed -Fq -- 'forceFreshFrame: _runtimeHasCapturedScreenshot,' "$test_file"
grep_fixed -Fq -- 'await _prepareRuntimeScreenshotSurface(tester);' "$test_file"
grep_fixed -Fq -- 'TextScaler.linear(_captureTextScale)' "$test_file"
grep_fixed -Fq -- 'HOPE_RUNTIME_CAPTURE_TEXT_SCALE:$_captureTextScale' "$test_file"
grep_fixed -Fq -- 'find.byType(SkeletonBox).evaluate().isNotEmpty' "$test_file"
grep_fixed -Fq -- 'HOPE_SCREENSHOT_READY:$marker' "$test_file"

for forbidden in revertFlutterImage HOPE_SCREENSHOT_SYNC_ROOT HOPE_ADB_SCREENSHOT_CAPTURE files/hope-screen-sync- test-complete.ready completion_request= 'adb exec-out screencap -p' 'run-as com.hope.marketplace'; do
  if grep_fixed -Fq -- "$forbidden" "$script" "$test_file"; then
    echo "FAIL: legacy screenshot transport remains: $forbidden" >&2
    exit 1
  fi
done

# T10/runtime interaction acceptance must be tied to a real, bound TalkBack service.
talkback_disable_helper="tools/hope-disable-talkback.sh"
if [[ ! -s "$talkback_disable_helper" ]]; then
  echo "FAIL: visual capture needs a TalkBack disable/unbind verifier" >&2
  exit 1
fi
if ! bash -n "$talkback_disable_helper"; then
  echo "FAIL: TalkBack disable helper has a shell syntax error." >&2
  exit 1
fi
grep_fixed -Fq -- 'settings put secure accessibility_enabled 0' "$talkback_disable_helper"
grep_fixed -Fq -- 'settings put secure enabled_accessibility_services ""' "$talkback_disable_helper"
grep_fixed -Fq -- 'talkback-service-bound-before-capture.txt' "$talkback_disable_helper"
grep_fixed -Fq -- 'accessibility-disabled-for-capture.txt' "$talkback_disable_helper"
grep_fixed -Fq -- 'bash tools/hope-disable-talkback.sh' "$script"
disable_line="$(grep -nF 'bash tools/hope-disable-talkback.sh' "$script" | head -n 1 | cut -d: -f1)"
visual_start_line="$(grep -nF 'run_host_batch_session baseline "${baseline_screens[@]}"' "$script" | head -n 1 | cut -d: -f1)"
enable_line="$(grep -nF 'bash tools/hope-enable-talkback.sh' "$script" | tail -n 1 | cut -d: -f1)"
semantics_line="$(grep -nF 'run_host_batch_session semantics-only' "$script" | head -n 1 | cut -d: -f1)"
test "$disable_line" -lt "$visual_start_line"
test "$visual_start_line" -lt "$enable_line"
test "$enable_line" -lt "$semantics_line"
grep_fixed -Fq -- 'validate_semantics_set' "$script"
grep_fixed -Fq -- 'validate_scroll_end_set' "$script"
grep_fixed -Fq -- 'visual_capture_accessibility_service": "disabled' "$script"
grep_fixed -Fq -- 'visual_capture_talkback_enabled": false' "$script"
grep_fixed -Fq -- 'visual_capture_accessibility_disable_verified": $visual_capture_accessibility_disabled' "$script"
grep_fixed -Fq -- 'talkback_semantics_mode": "separate_bound_service_pass' "$script"
talkback_helper="tools/hope-enable-talkback.sh"
if [[ ! -s "$talkback_helper" ]]; then
  echo "FAIL: T10 needs a TalkBack install/enable/verify helper" >&2
  exit 1
fi
# Treat the helper and runtime launcher as executable source: syntax must be clean
# in Static, before the one-shot Android Runtime is armed.
if ! bash -n "$talkback_helper" "$script"; then
  echo "FAIL: TalkBack helper/runtime launcher has a shell syntax error." >&2
  exit 1
fi
grep_fixed -Fq -- 'com.android.talkback' "$talkback_helper"
grep_fixed -Fq -- 'com.google.android.marvin.talkback.TalkBackService' "$talkback_helper"
grep_fixed -Fq -- 'settings put secure enabled_accessibility_services' "$talkback_helper"
grep_fixed -Fq -- 'settings put secure accessibility_enabled 1' "$talkback_helper"
grep_fixed -Fq -- 'dumpsys accessibility' "$talkback_helper"
grep_fixed -Fq -- 'bash tools/hope-enable-talkback.sh' "$script"
grep_fixed -Fq -- 'HOPE_TALKBACK_REQUIRED' "$script"
grep_fixed -Fq -- 'HOPE_T10_SEMANTICS_PASS:' "$test_file"
grep_fixed -Fq -- "bool.fromEnvironment('HOPE_T10_SEMANTICS_ONLY'" "$test_file"
grep_fixed -Fq -- 'if (_talkbackRequired && _semanticsOnly && !marker.startsWith' "$test_file"
grep_fixed -Fq -- 'HOPE_T10_SEMANTICS_ONLY_SCREEN_COMPLETE:' "$test_file"
grep_fixed -Fq -- 'HOPE_T10_SEMANTICS_ONLY_SURFACE_SKIPPED' "$test_file"
grep_fixed -Fq -- 'HOPE_T10_SCROLL_END_PASS:' "$test_file"
grep_fixed -Fq -- '--dart-define=HOPE_T10_SEMANTICS_ONLY="${semantics_only}"' "$script"
grep_fixed -Fq -- 'if [ "$semantics_only" = "true" ]' "$script"
grep_fixed -Fq -- 'tester.ensureSemantics()' "$test_file"
grep_fixed -Fq -- "'scroll-end-\$marker'" "$test_file"
grep_fixed -Fq -- 'talkback_service_bound' "$script"
grep_fixed -Fq -- 'scroll_end_screens' "$script"
workflow_file=".github/workflows/hope-ui-runtime-evidence.yml"
grep_fixed -Fq -- 'Checkout pinned Google TalkBack source' "$workflow_file"
grep_fixed -Fq -- '229212fdf5842191d0a93fc95d9ca1423b346866' "$workflow_file"
grep_fixed -Fq -- 'Build pinned Google TalkBack accessibility service' "$workflow_file"
grep_fixed -Fq -- 'ndk;28.2.13676358' "$workflow_file"
grep_fixed -Fq -- "HOPE_TALKBACK_REQUIRED: '1'" "$workflow_file"

bash test/runtime/hope_disable_talkback_test.sh
echo "PASS: official Flutter integration_test screenshot transport contract"
