#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
test_file="$repo_root/integration_test/runtime/critical_screens_evidence_test.dart"
driver_file="$repo_root/test_driver/hope_runtime_screenshot_driver.dart"
script_file="$repo_root/tools/hope-wallet-runtime-evidence.sh"

main_activity="$repo_root/android/app/src/main/kotlin/com/hope/marketplace/MainActivity.kt"
runtime_contracts=(
  'private const val HOPE_SCREENSHOT_CHANNEL = "hope.runtime/screenshot"'
  '// HOPE_SCREENSHOT_FORCE_FRESH_FRAME'
  'getCurrentImageSurface()'
  'setOnImageAvailableListener'
  'acquireLatestImageViewFrame()'
  '// HOPE_SCREENSHOT_IMMEDIATE_FRAME_ATTEMPT'
  'hopeScreenshotFrameCaptured.compareAndSet(false, true)'
  'private const val HOPE_SCREENSHOT_FRAME_TIMEOUT_MS'
  'private const val HOPE_SCREENSHOT_FRAME_RETRY_INTERVAL_MS'
  'private const val HOPE_SCREENSHOT_LOG_TAG'
  'private var hopeScreenshotCapturePhase = "idle"'
  'HOPE_SCREENSHOT_CURRENT_TARGET_FRAME_ACCEPTED'
  'HOPE_SCREENSHOT_PIXELCOPY_START:'
  'HOPE_SCREENSHOT_PIXELCOPY_CALLBACK:'
  'private fun scheduleHopeFreshFrameRetry('
  'private fun clearHopeScreenshotCaptureWatchdogs('
  'hopeScreenshotResultCompleted.compareAndSet(false, true)'
  'BuildConfig.DEBUG'
)
for contract in "${runtime_contracts[@]}"; do
  if ! grep -Fq "$contract" "$main_activity"; then
    echo "FAIL: MainActivity native screenshot contract missing: $contract" >&2
    exit 1
  fi
done

dart_contracts=(
  "const _hopeRuntimeScreenshotChannel = MethodChannel('hope.runtime/screenshot');"
  "invokeMethod<Uint8List>("
  "'screenshotName': marker"
  "'forceFreshFrame': forceFreshFrame"
  'required WidgetTester tester'
)
for contract in "${dart_contracts[@]}"; do
  if ! grep -Fq "$contract" "$test_file"; then
    echo "FAIL: Dart runtime screenshot contract missing: $contract" >&2
    exit 1
  fi
done


grep -Fq "forceFreshFrame: _runtimeHasCapturedScreenshot || marker.startsWith('password-reset-')," "$test_file"
grep -Fq 'var _runtimeHasCapturedScreenshot = false;' "$test_file"
grep -Fq 'call.argument<Boolean>("forceFreshFrame") ?: false' "$main_activity"
grep -Fq 'HOPE_SCREENSHOT_SOURCE:native-primary:' "$test_file"
grep -Fq 'HOPE_SCREENSHOT_READY:' "$test_file"
if grep -Fq 'await binding.takeScreenshot(marker)' "$test_file"; then
  echo "FAIL: runtime evidence must not use Flutter Driver takeScreenshot transport" >&2
  exit 1
fi
grep -Fq 'onScreenshot:' "$driver_file"
grep -Fq 'writeAsBytes(image, flush: true)' "$driver_file"
grep -Fq 'flutter drive --keep-app-running --no-pub --no-dds' "$script_file"
grep -Fq 'HOPE_RUNTIME_DRIVER_BUILD_MODE:self-build' "$script_file"
# Self-build includes Flutter/Gradle compilation before VM-service connection.
grep -Fq 'DRIVER_CONNECT_TIMEOUT_SECONDS="${HOPE_DRIVER_CONNECT_TIMEOUT_SECONDS:-420}"' "$script_file"
grep -Fq 'emulator-options: -no-window -no-snapshot -gpu swiftshader' "$repo_root/.github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq -- '-feature -Vulkan' "$repo_root/.github/workflows/hope-ui-runtime-evidence.yml"
if grep -Fq -- '-gpu software' "$repo_root/.github/workflows/hope-ui-runtime-evidence.yml"; then
  echo "FAIL: runtime evidence must not use the generic software GPU alias" >&2
  exit 1
fi
grep -Fq ': > "$log_path"' "$script_file"

# Regression: use the target page's already committed ImageReader frame if present.
# Register first so a racing new frame is not lost; only request an additional frame
# when no current target frame can be acquired. This prevents static Home deadlocks.
listener_line="$(grep -nF 'imageReader.setOnImageAvailableListener(' "$main_activity" | sed -n '2p' | cut -d: -f1)"
current_target_line="$(grep -nF 'val currentTargetFrameAvailable = flutterView.acquireLatestImageViewFrame()' "$main_activity" | cut -d: -f1)"
if [ -z "$listener_line" ] || [ -z "$current_target_line" ] || [ "$listener_line" -ge "$current_target_line" ]; then
  echo "FAIL: force-fresh capture must register its ImageReader listener before checking the target frame" >&2
  exit 1
fi
target_frame_block="$(sed -n "$((current_target_line - 3)),$((current_target_line + 15))p" "$main_activity")"
grep -Fq '// HOPE_SCREENSHOT_FORCE_FRESH_FRAME' <<<"$target_frame_block"
grep -Fq 'currentTargetFrameAvailable &&' <<<"$target_frame_block"
grep -Fq 'HOPE_SCREENSHOT_CURRENT_TARGET_FRAME_ACCEPTED' <<<"$target_frame_block"
grep -Fq 'scheduleHopeFreshFrameRetry(' "$main_activity"
grep -Fq 'HOPE_SCREENSHOT_TIMEOUT:phase=' "$main_activity"
grep -Fq 'forceFreshFrame: _runtimeHasCapturedScreenshot' "$test_file"
grep -Fq 'const _nativeScreenshotCaptureTimeout = Duration(seconds: 18);' "$test_file"
grep -Fq ').timeout(' "$test_file"
grep -Fq '_nativeScreenshotCaptureTimeout,' "$test_file"
grep -Fq 'Future<bool> _dragScrollableTowardEndWithFallbackOffsets(' "$test_file"
grep -Fq 'await _dragScrollableTowardEndWithFallbackOffsets(' "$test_file"
grep -Fq 'var stableAtBottomFrames = 0;' "$test_file"
grep -Fq 'while (sweeps < 20 && stableAtBottomFrames < 2)' "$test_file"
grep -Fq 'stableFrames=$stableAtBottomFrames' "$test_file"
if grep -Fq 'if (selectedState.position.pixels <= before + 0.5 &&' "$test_file"; then
  echo "FAIL: T10 scroll-end must not abort on the first no-progress drag; it must try alternate offsets." >&2
  exit 1
fi
if grep -Fq -- '--use-application-binary' "$script_file"; then
  echo "FAIL: runtime evidence must not use --use-application-binary" >&2
  exit 1
fi
if grep -Fq -- '--route=' "$script_file"; then
  echo "FAIL: runtime evidence must not use flutter drive route transport" >&2
  exit 1
fi
if grep -Fq 'platformDispatcher.defaultRouteName' "$test_file"; then
  echo "FAIL: runtime evidence must not use Android initial-route transport" >&2
  exit 1
fi
if grep -Fq 'wait_for_screenshot_file' "$script_file"; then
  echo "FAIL: runtime evidence must not poll screenshot files per marker" >&2
  exit 1
fi
if grep -Fq 'adb exec-out screencap -p' "$script_file"; then
  echo "FAIL: runtime evidence must not capture a later ADB framebuffer" >&2
  exit 1
fi
if grep -Fq 'HOPE_SCREENSHOT_SYNC_ROOT' "$test_file"; then
  echo "FAIL: target must not use app-private screenshot sync" >&2
  exit 1
fi

grep -Fq 'String.fromEnvironment' "$test_file"
grep -Fq "String.fromEnvironment('HOPE_CAPTURE_LOCALE', defaultValue: '')" "$test_file"
grep -Fq "String.fromEnvironment('HOPE_CAPTURE_MODE', defaultValue: 'baseline')" "$test_file"
grep -Fq 'IntegrationTestWidgetsFlutterBinding.ensureInitialized();' "$test_file"
# Android screenshot surface preparation must follow the first target page pumpWidget.
capture_fn_start="$(grep -nF 'Future<void> _captureRuntimeScreen(' "$test_file" | cut -d: -f1 | head -n1)"
capture_fn_end="$(grep -nF 'Future<void> _captureBaselineLocale(' "$test_file" | cut -d: -f1 | head -n1)"
capture_block="$(sed -n "${capture_fn_start},$((capture_fn_end - 1))p" "$test_file")"
pump_widget_line="$(grep -nF 'await tester.pumpWidget(' <<<"$capture_block" | head -n1 | cut -d: -f1)"
surface_prepare_line="$(grep -nF 'await _prepareRuntimeScreenshotSurface(tester);' <<<"$capture_block" | head -n1 | cut -d: -f1)"
if [ -z "$pump_widget_line" ] || [ -z "$surface_prepare_line" ] || [ "$surface_prepare_line" -le "$pump_widget_line" ]; then
  echo "FAIL: Android screenshot surface must be prepared after target screen pumpWidget" >&2
  exit 1
fi
main_block="$(sed -n '/^void main()/,$p' "$test_file")"
if grep -Fq 'await _prepareRuntimeScreenshotSurface(tester);' <<<"$main_block"; then
  echo "FAIL: screenshot surface must not be prepared on the initial Home host" >&2
  exit 1
fi
grep -Fq -- '--dart-define=HOPE_CAPTURE_LOCALE="${CAPTURE_LOCALE}"' "$script_file"
grep -Fq -- '--dart-define=HOPE_CAPTURE_MODE="${launch_mode}"' "$script_file"
grep -Fq -- '--dart-define=HOPE_CAPTURE_HOME_ONLY="${DART_CAPTURE_HOME_ONLY}"' "$script_file"

grep -Fq 'run_host_batch_session responsive-a' "$script_file"
grep -Fq 'run_host_batch_session responsive-b' "$script_file"
grep -Fq 'run_host_batch_session responsive-c' "$script_file"
grep -Fq 'responsive-c) responsive_batch="3"' "$script_file"
# Baseline capture must remain one Driver/VM-service session; the proven green
# certification run captured the complete locale baseline without repeated
# emulator-side teardown/startup cycles.
grep -Fq 'run_host_batch_session baseline "${baseline_screens[@]}"' "$script_file"
if grep -Fq 'baseline_first_screens=' "$script_file" ||
   grep -Fq 'baseline_second_screens=' "$script_file" ||
   grep -Fq 'baseline_third_screens=' "$script_file" ||
   grep -Fq 'baseline_fourth_screens=' "$script_file"; then
  echo "FAIL: baseline evidence must not churn multiple Driver sessions" >&2
  exit 1
fi
grep -Fq 'HOPE_RUNTIME_TEST_BODY_COMPLETE' "$script_file"
grep -Fq 'if (child is WalletPage)' "$test_file"
grep -Fq 'await _waitForRuntimeRenderToSettle(tester);' "$test_file"
grep -Fq 'widget is HopeAsyncState && widget.kind == HopeStateKind.loading' "$test_file"
grep -Fq "print('HOPE_RUNTIME_WALLET_LOADED_STATE_ASSERTED:\$marker');" "$test_file"
grep -Fq "? 'قابل استفاده'" "$test_file"
grep -Fq ": 'Available';" "$test_file"
login_block="$(sed -n '/if (child is LoginPage)/,/^[[:space:]]*}/p' "$test_file")"
# Login uses a bounded timed settle; only an unbounded pumpAndSettle invocation is prohibited.
grep -Fq "print('HOPE_RUNTIME_LOGIN_DIRECT_CAPTURE:\$marker');" "$test_file"
# Login capture intentionally uses a bounded deterministic settle; unbounded pumpAndSettle is prohibited below.
grep -Fq 'HOPE_HOST_SCREENSHOT_FLUSH_COMPLETE' "$script_file"
# Post-completion screenshot flush must be followed by normal integration_test driver teardown.
grep -Fq 'screenshot_flush_deadline' "$script_file"
grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT' "$script_file"
grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_FORCE_STOP' "$script_file"
if grep -Fq 'HOPE_HOST_RUNTIME_DRIVER_STOP_AFTER_COMPLETE' "$script_file"; then
  echo "FAIL: runtime evidence still force-stops the driver after screenshot flush" >&2
  exit 1
fi
grep -Fq '"capture_transport": "native_android_pixelcopy"' "$script_file"
grep -Fq 'RUNTIME_SHUTDOWN_GRACE_SECONDS="${HOPE_RUNTIME_SHUTDOWN_GRACE_SECONDS:-30}"' "$script_file"

# Baseline host partitions must stay aligned with the Dart page-map insertion order.
# Login is intentionally first so risk-first capture and host validation inspect the same pages.
baseline_order="$(sed -n '/^screens=(/,/^)/p' "$script_file" | sed -n '/^[[:space:]]*".*-fa-rtl"/!d; s/^[[:space:]]*"\(.*\)-fa-rtl"$/\1/p' | head -n 15 | paste -sd ' ' -)"
expected_baseline_order="login home jobs job-detail applications saved-searches transactions wallet transaction-detail profile notifications offers create-job register password-reset"
if [ "$baseline_order" != "$expected_baseline_order" ]; then
  echo "FAIL: host baseline screen order drifted from Dart page order" >&2
  printf 'Expected: %s\\nActual:   %s\\n' "$expected_baseline_order" "$baseline_order" >&2
  exit 1
fi
# Responsive batch 3 must explicitly capture Wallet/Profile; falling through to baseline is forbidden.
grep -Fq "pages.entries.skip(6).take(2)" "$test_file"

pages_declaration_line="$(grep -nF 'final pages = <String, Widget Function()>{' "$test_file" | head -n1 | cut -d: -f1)"
if [ -z "$pages_declaration_line" ]; then
  echo "FAIL: baseline pages declaration not found" >&2
  exit 1
fi
first_baseline_page="$(sed -n "$((pages_declaration_line + 1))p" "$test_file")"
if [ "$first_baseline_page" != "    'login': () => const LoginPage()," ]; then
  echo "FAIL: unresolved Login runtime evidence must be the first baseline screen" >&2
  exit 1
fi

login_capture_block="$(awk '/if \(child is LoginPage\)/,/return;/{print}' "$test_file")"
if printf '%s\n' "$login_capture_block" | grep -qE 'await[[:space:]]+tester\.pumpAndSettle[[:space:]]*\('; then
  echo "FAIL: Login runtime capture must not use unbounded pumpAndSettle" >&2
  exit 1
fi
if printf '%s\n' "$login_capture_block" | grep -Fq 'await tester.pump('; then
  echo "FAIL: Login runtime capture must not issue a second tester.pump after surface preparation" >&2
  exit 1
fi

# T10: require a real TalkBack service and a live Flutter semantics tree.
talkback_helper="$repo_root/tools/hope-enable-talkback.sh"
if [ ! -s "$talkback_helper" ]; then
  echo "FAIL: T10 needs a TalkBack install/enable/verify helper" >&2
  exit 1
fi
grep -Fq 'com.android.talkback' "$talkback_helper"
grep -Fq 'HOPE_TALKBACK_PACKAGE' "$talkback_helper"
grep -Fq 'com.google.android.marvin.talkback.TalkBackService' "$talkback_helper"
grep -Fq 'settings put secure enabled_accessibility_services' "$talkback_helper"
grep -Fq 'settings put secure accessibility_enabled 1' "$talkback_helper"
grep -Fq 'dumpsys accessibility' "$talkback_helper"
grep -Fq 'accessibility-enabled.txt' "$talkback_helper"
grep -Fq 'accessibility-services.txt' "$talkback_helper"
grep -Fq 'bash tools/hope-enable-talkback.sh' "$script_file"
grep -Fq 'HOPE_TALKBACK_REQUIRED' "$script_file"
grep -Fq 'HOPE_T10_SEMANTICS_PASS:' "$test_file"
grep -Fq 'HOPE_T10_SCROLL_END_PASS:' "$test_file"
grep -Fq "tester.ensureSemantics()" "$test_file"
grep -Fq "'scroll-end-\$marker'" "$test_file"
grep -Fq 'talkback_service_bound' "$script_file"
grep -Fq 'scroll_end_screens' "$script_file"
grep -Fq 'accessibility-services.txt' "$talkback_helper"

workflow_file="$repo_root/.github/workflows/hope-ui-runtime-evidence.yml"
grep -Fq 'Checkout pinned Google TalkBack source' "$workflow_file"
grep -Fq '229212fdf5842191d0a93fc95d9ca1423b346866' "$workflow_file"
grep -Fq 'Build pinned Google TalkBack accessibility service' "$workflow_file"
grep -Fq 'com.hopev2.ci.talkback' "$workflow_file"
grep -Fq 'HOPE_TALKBACK_PACKAGE: com.hopev2.ci.talkback' "$workflow_file"
grep -Fq "HOPE_TALKBACK_REQUIRED: '1'" "$workflow_file"

# A static candidate-match fixture intentionally exposes no tap callbacks; its
# semantic labels/nodes remain required, while actionable semantics stay
# mandatory on all other captured surfaces.
grep -Fq "final requiresTapAction = marker != 'candidate-matches-fa-rtl';" "$test_file"
grep -Fq 'actionableNodeCount < 1' "$test_file"

# T10 regression: service presence under "Binding services" must not count as bound.
if ! grep -Fq 'Bound services:' "$talkback_helper" ||
   ! grep -Fq 'Binding services' "$talkback_helper" ||
   ! grep -Fq 'bound_services_block' "$talkback_helper" ||
   ! grep -Fq 'TalkBackPreferencesActivity' "$talkback_helper"; then
  echo "FAIL: TalkBack binding verification must inspect only the Bound services section." >&2
  exit 1
fi

# Regression: skipped PR events must not acquire a workflow-level concurrency group
# and cancel an authorized Android capture that is already running.
workflow_level_concurrency_line="$(grep -n '^concurrency:' "$workflow_file" | head -n 1 | cut -d: -f1 || true)"
if [ -n "$workflow_level_concurrency_line" ]; then
  echo "FAIL: runtime concurrency is workflow-scoped; non-capture PR events can cancel an authorized capture." >&2
  exit 1
fi
runtime_job_if_line="$(grep -nF '    if: ${{ github.event_name == '\''workflow_dispatch'\'' || (github.event_name == '\''pull_request'\'' && github.event.action == '\''edited'\'' && github.event.changes.title.from != null' "$workflow_file" | head -n 1 | cut -d: -f1 || true)"
runtime_job_concurrency_line="$(grep -n '^    concurrency:' "$workflow_file" | head -n 1 | cut -d: -f1 || true)"
if [ -z "$runtime_job_if_line" ] || [ -z "$runtime_job_concurrency_line" ] || [ "$runtime_job_if_line" -ge "$runtime_job_concurrency_line" ]; then
  echo "FAIL: concurrency must be scoped to the runtime job after its authorization condition." >&2
  exit 1
fi
grep -Fq 'hope-ui-runtime-evidence-${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}' "$workflow_file" || {
  echo "FAIL: authorized runtime captures must remain serialized per PR." >&2
  exit 1
}

echo "PASS: Flutter rendered-screenshot transport contract"
