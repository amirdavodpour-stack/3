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
grep_fixed -Fq -- "flutter drive --keep-app-running --no-pub --no-dds --no-enable-impeller" "$script"
grep_fixed -Fq -- '--driver=test_driver/hope_runtime_screenshot_driver.dart' "$script"
grep_fixed -Fq -- '--target=integration_test/runtime/critical_screens_evidence_test.dart' "$script"
grep_fixed -Fq -- 'HOPE_SCREENSHOT_OUTPUT_ROOT="$evidence_dir"' "$script"
grep_fixed -Fq -- 'HOPE_CAPTURE_TEXT_SCALE="${CAPTURE_TEXT_SCALE}"' "$script"
grep_fixed -Fq -- '"text_scale": $CAPTURE_TEXT_SCALE' "$script"
grep_fixed -Fq -- 'HOPE_CAPTURE_THEME="${CAPTURE_THEME}"' "$script"
grep_fixed -Fq -- '--dart-define=HOPE_CAPTURE_THEME="${CAPTURE_THEME}"' "$script"
grep_fixed -Fq -- '"theme": "$CAPTURE_THEME"' "$script"
grep_fixed -Fq -- 'RUNTIME_TEST_TIMEOUT_SECONDS=' "$script"
grep_fixed -Fq -- 'BODY_COMPLETION_TIMEOUT_SECONDS="${HOPE_RUNTIME_BODY_COMPLETION_TIMEOUT_SECONDS:-90}"' "$script"
grep_fixed -Fq -- 'completion_deadline=$((SECONDS + BODY_COMPLETION_TIMEOUT_SECONDS))' "$script"
grep_fixed -Fq -- 'timeout --foreground --signal=TERM --kill-after="${ADB_KILL_AFTER_SECONDS}s"' "$script"
grep_fixed -Fq -- 'validate_capture_set "baseline-$CAPTURE_LOCALE"' "$script"
grep_fixed -Fq -- 'validate_capture_set "responsive-$CAPTURE_LOCALE-a"' "$script"
grep_fixed -Fq -- 'CAPTURED_BASELINE_SCREENS="$(find "$evidence_dir" -maxdepth 1' "$script"
grep_fixed -Fq -- 'CAPTURED_RESPONSIVE_SCREENS="$(find "$evidence_dir" -maxdepth 1' "$script"
grep_fixed -Fq -- "responsive-*.png" "$script"
grep_fixed -Fq -- "scroll-end-*" "$script"
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
grep_fixed -Fq -- "'screenshotName': marker" "$test_file"
grep_fixed -Fq -- 'call.argument<String>("screenshotName") ?: "unlabelled"' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- "'captureScreenshot'," "$test_file"
grep_fixed -Fq -- "int _runtimeFreshFrameCount(String marker)" "$test_file"
grep_fixed -Fq -- "if (marker.startsWith('register-')) return 1;" "$test_file"
grep_fixed -Fq -- "if (marker.startsWith('password-reset-')) return 1;" "$test_file"
grep_fixed -Fq -- "freshFramesRequired: freshFrameCount," "$test_file"
grep_fixed -Fq -- "'freshFramesRequired': freshFramesRequired" "$test_file"
grep_fixed -Fq -- 'call.argument<Int>("freshFramesRequired")' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- 'freshFramesRequired.coerceIn(1, 2)' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- 'await _prepareRuntimeScreenshotSurface(tester);' "$test_file"
grep_fixed -Fq -- 'TextScaler.linear(_captureTextScale)' "$test_file"
grep_fixed -Fq -- 'HOPE_RUNTIME_CAPTURE_TEXT_SCALE:$_captureTextScale' "$test_file"
grep_fixed -Fq -- 'find.byType(SkeletonBox).evaluate().isNotEmpty' "$test_file"
grep_fixed -Fq -- 'HOPE_SCREENSHOT_READY:$marker' "$test_file"
grep_fixed -Fq -- 'HOPE_SCREENSHOT_STALE_FRAME_DRAINED:' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- 'HOPE_SCREENSHOT_STALE_FRAME_REJECTED:' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- 'hopeScreenshotFreshFramesRemaining > 1' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- 'HOPE_SCREENSHOT_CAPTURE_COMPLETE:' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- 'HOPE_SCREENSHOT_TIMEOUT:phase=' android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt
grep_fixed -Fq -- 'stableAtBottomFrames < 2' "$test_file"
grep_fixed -Fq -- 'stableFrames=$stableAtBottomFrames' "$test_file"

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
grep_fixed -Fq -- 'settings delete secure enabled_accessibility_services' "$talkback_disable_helper"
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
responsive_semantics_begin_line="$(grep -nF 'HOPE_T10_RESPONSIVE_SEMANTICS_VIEWPORT_BEGIN:720x1280:320dpi' "$script" | cut -d: -f1)"
responsive_semantics_batch_line="$(grep -nF 'run_host_batch_session semantics-responsive-a' "$script" | cut -d: -f1)"
responsive_semantics_reset_line="$(grep -nF 'adb shell wm size reset || true' "$script" | tail -n 1 | cut -d: -f1)"
responsive_semantics_end_line="$(grep -nF 'HOPE_T10_RESPONSIVE_SEMANTICS_VIEWPORT_END' "$script" | cut -d: -f1)"
test "$responsive_semantics_begin_line" -lt "$responsive_semantics_batch_line"
test "$responsive_semantics_batch_line" -lt "$responsive_semantics_reset_line"
test "$responsive_semantics_reset_line" -lt "$responsive_semantics_end_line"
grep_fixed -Fq -- 'validate_semantics_set' "$script"
grep_fixed -Fq -- 'validate_scroll_end_set' "$script"
grep_fixed -Fq -- 'visual_capture_accessibility_service": "disabled' "$script"
grep_fixed -Fq -- 'visual_capture_talkback_enabled": false' "$script"
grep_fixed -Fq -- 'visual_capture_accessibility_disable_verified": $visual_capture_accessibility_disabled' "$script"
grep_fixed -Fq -- 'talkback_semantics_mode": "separate_bound_service_pass' "$script"
grep_fixed -Fq -- '"talkback_package": "$TALKBACK_PACKAGE"' "$script"
grep_fixed -Fq -- '"talkback_service_component": "$TALKBACK_SERVICE_COMPONENT"' "$script"
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
grep_fixed -Fq -- 'settings put secure touch_exploration_enabled 1' "$talkback_helper"
grep_fixed -Fq -- 'touchExplorationEnabled=(true|false)' "$talkback_helper"
grep_fixed -Fq -- 'touch-exploration-enabled.txt' "$talkback_helper"
grep_fixed -Fq -- 'dumpsys accessibility' "$talkback_helper"
grep_fixed -Fq -- 'bash tools/hope-enable-talkback.sh' "$script"
grep_fixed -Fq -- 'HOPE_TALKBACK_REQUIRED' "$script"
grep_fixed -Fq -- 'HOPE_T10_SEMANTICS_PASS:' "$test_file"
grep_fixed -Fq -- "'HOPE_T10_SEMANTICS_ONLY'," "$test_file"
grep_fixed -Fq -- 'if (_talkbackRequired && _semanticsOnly && !marker.startsWith' "$test_file"
grep_fixed -Fq -- 'HOPE_T10_SEMANTICS_ONLY_SCREEN_COMPLETE:' "$test_file"
grep_fixed -Fq -- 'HOPE_T10_SEMANTICS_ONLY_SURFACE_SKIPPED' "$test_file"
grep_fixed -Fq -- 'HOPE_T10_SCROLL_END_PASS:' "$test_file"
grep_fixed -Fq -- '--dart-define=HOPE_T10_SEMANTICS_ONLY="${semantics_only}"' "$script"
grep_fixed -Fq -- 'if [ "$semantics_only" = "true" ]' "$script"
grep_fixed -Fq -- 'tester.ensureSemantics()' "$test_file"
grep_fixed -Fq -- "'scroll-end-\$marker'" "$test_file"
grep_fixed -Fq -- 'talkback_service_bound' "$script"
grep_fixed -Fq -- 'talkback_touch_exploration_enabled' "$script"
grep_fixed -Fq -- 'HOPE_T10_TARGET_BOUNDS_PASS:' "$test_file"
grep_fixed -Fq -- 'HOPE_T10_TARGET_BOUNDS_FAIL:' "$test_file"
grep_fixed -Fq -- "import 'package:flutter/painting.dart' show MatrixUtils;" "$test_file"
grep_fixed -Fq -- "import 'package:flutter/rendering.dart' show RenderView;" "$test_file"
grep_fixed -Fq -- 'Rect _globalSemanticsNodeBounds(SemanticsNode node, RenderView renderView)' "$test_file"
grep_fixed -Fq -- 'transform = nodeTransform * transform as Matrix4;' "$test_file"
grep_fixed -Fq -- 'Matrix4.copy(renderView.configuration.toMatrix())..invert()' "$test_file"
grep_fixed -Fq -- 'MatrixUtils.transformRect(transform, node.rect)' "$test_file"
grep_fixed -Fq -- 'final targetBounds = _globalSemanticsNodeBounds(node, renderView);' "$test_file"
grep_fixed -Fq -- 'targetBounds.width < 48' "$test_file"
grep_fixed -Fq -- 'targetBounds.height < 48' "$test_file"
grep_fixed -Fq -- 'talkback_target_bounds_screens' "$script"
grep_fixed -Fq -- 'talkback_target_bounds_failures' "$script"
grep_fixed -Fq -- 'talkback_target_bounds_min_width_dp' "$script"
grep_fixed -Fq -- 'talkback_target_bounds_min_height_dp' "$script"
grep_fixed -Fq -- 'touch-exploration-enabled.txt' "$script"
grep_fixed -Fq -- 'HOPE_T10_ACCEPTANCE_FAILED: setup=$talkback_setup_status enabled=$talkback_enabled bound=$talkback_service_bound touch_exploration=$talkback_touch_exploration_enabled' "$script"
grep_fixed -Fq -- 'hope_android_app_activity_ready "$RUNTIME_SERIAL" com.hope.marketplace' "$script"
grep_fixed -Fq -- 'assert_hope_focused talkback-return' "$script"
grep_fixed -Fq -- 'HOPE_RUNTIME_APP_FOREGROUND_AFTER_TALKBACK:true' "$script"
grep_fixed -Fq -- 'elif ! assert_hope_focused "$mode" || ! assert_hope_rendered "$mode"; then' "$script"
grep_fixed -Fq -- 'HOPE_HOST_RUNTIME_FOCUS_AND_SURFACE_VERIFIED:$mode' "$script"
grep_fixed -Fq -- 'scroll_end_screens' "$script"
grep_fixed -Fq -- '"transaction-detail-$scroll_suffix"' "$script"
grep_fixed -Fq -- '"create-job-$scroll_suffix"' "$script"
grep_fixed -Fq -- '"profile-$scroll_suffix"' "$script"
grep_fixed -Fq -- "'transaction-detail', 'create-job'" "$test_file"
grep_fixed -Fq -- '"financial-insights-$scroll_suffix" "job-satisfaction-$scroll_suffix"' "$script"
scroll_end_policy="$(sed -n '/bool _runtimeNeedsScrollEnd(String marker)/,/^}/p' "$test_file")"
if ! grep_fixed -Fq -- "'financial-insights'" <<<"$scroll_end_policy" || ! grep_fixed -Fq -- "'job-satisfaction'" <<<"$scroll_end_policy"; then
  echo "FAIL: T10 scroll-end policy must include Financial Insights and Job Satisfaction." >&2
  exit 1
fi
grep_fixed -Fq -- '"$scroll_end_screens" -ne 10' "$script"
workflow_file=".github/workflows/hope-ui-runtime-evidence.yml"
static_workflow_file=".github/workflows/hope-ui-wave-1-static.yml"
grep_fixed -Fq -- "github.event.action == 'synchronize'" "$static_workflow_file"
grep_fixed -Fq -- "github.event.action == 'edited' && github.event.changes.title.from != null" "$workflow_file"
grep_fixed -Fq -- 'Checkout pinned Google TalkBack source' "$workflow_file"
grep_fixed -Fq -- '229212fdf5842191d0a93fc95d9ca1423b346866' "$workflow_file"
grep_fixed -Fq -- 'Build pinned Google TalkBack accessibility service' "$workflow_file"
grep_fixed -Fq -- 'ndk;28.2.13676358' "$workflow_file"
grep_fixed -Fq -- 'Install Android Emulator host runtime libraries' "$workflow_file"
grep_fixed -Fq -- 'sudo apt-get install --yes --no-install-recommends libpulse0' "$workflow_file"
grep_fixed -Fq -- "ldconfig -p | grep -F 'libpulse.so.0'" "$workflow_file"
host_runtime_lib_line="$(grep -nF 'Install Android Emulator host runtime libraries' "$workflow_file" | cut -d: -f1)"
emulator_prepare_line="$(grep -nF 'Prepare Android Emulator package with bounded retry' "$workflow_file" | cut -d: -f1)"
test "$host_runtime_lib_line" -lt "$emulator_prepare_line"
grep_fixed -Fq -- "HOPE_TALKBACK_REQUIRED: '1'" "$workflow_file"

bash test/runtime/hope_disable_talkback_test.sh
bash test/runtime/android_runtime_adb_recovery_test.sh
echo "PASS: official Flutter integration_test screenshot transport and Android launcher recovery contracts"
