#!/usr/bin/env bash
set -euo pipefail

script="tools/hope-wallet-runtime-evidence.sh"
dart_test="integration_test/runtime/critical_screens_evidence_test.dart"
test -f "$script"
test -f "$dart_test"
bash -n "$script"

# Host capture is file-based; the custom app-to-host ACK loop is gone.
grep -Eq 'HOPE_HOST_CAPTURE_DETECTED:' "$script"
grep -Eq 'HOPE_HOST_SCREENSHOT_CAPTURED:' "$script"
grep -Eq 'HOPE_HOST_CAPTURE_CLEANED:' "$script"
grep -Fq 'grep -Fq -- "$marker" "$active_runtime_log"' "$script"
grep -Fq 'adb exec-out run-as com.hope.marketplace cat "$remote_path"' "$script"
grep -Fq 'for attempt in 1 2 3 4 5; do' "$script"
grep -Fq 'sleep 0.5' "$script"
grep -Fq 'HOPE_HOST_CAPTURE_FAILED:$marker:file-read' "$script"
if grep -Fq 'adb shell run-as com.hope.marketplace test -s "$remote_path"' "$script"; then
  echo "runtime harness contract: FAIL — host must not poll remote file existence via run-as" >&2
  exit 1
fi
grep -Fq 'test -s "$tmp_output"' "$script"
grep -Fq 'screenshot_magic="$(od -An -tx1 -N8 "$tmp_output"' "$script"
grep -Fq 'if [ "$screenshot_magic" = "89504e470d0a1a0a" ]; then' "$script"
grep -Fq 'HOPE_HOST_UI_HIERARCHY_DIAGNOSTIC:$marker:not-hope' "$script"
grep -Fq 'package="com.hope.marketplace"' "$script"
grep -Fq 'mv -- "$tmp_output" "$evidence_dir/$output"' "$script"
grep -Fq 'adb shell run-as com.hope.marketplace rm -f "$remote_path"' "$script"

# Flutter's official integration_test screenshot API owns capture and the app
# publishes the finished bytes atomically to the app-private filesystem.
grep -Fq "HOPE_SCREENSHOT_OUTPUT_ROOT" "$dart_test"
grep -Fq "IntegrationTestWidgetsFlutterBinding.instance" "$dart_test"
grep -Fq "convertFlutterSurfaceToImage()" "$dart_test"
grep -Fq "takeScreenshot(marker)" "$dart_test"
grep -Fq 'writeAsBytes(bytes, flush: true)' "$dart_test"
grep -Fq 'tempFile.rename(outputFile.path)' "$dart_test"
grep -Fq 'find.byType(CircularProgressIndicator)' "$dart_test"
grep -Fq 'Runtime render remained in loading state after bounded settle' "$dart_test"
grep -Fq 'await tester.pump(const Duration(milliseconds: 100))' "$dart_test"
grep -Fq 'HOPE_SCREENSHOT_READY:$marker' "$dart_test"

# Flutter emits the screenshot-ready marker only after the PNG has been atomically
# published. Android focus may already be lost while integration_test teardown
# proceeds, so focus observation must never gate a rendered screenshot capture.
if grep -Eq '^[[:space:]]*assert_hope_focused "\$prefix"[[:space:]]*$' "$script"; then
  echo "runtime harness contract: FAIL — Android focus must not gate rendered screenshot capture" >&2
  exit 1
fi

# Baseline and responsive runs both receive the same output root.
test "$(grep -Fc -- '--dart-define=HOPE_SCREENSHOT_OUTPUT_ROOT="$capture_root"' "$script")" -eq 2

# The legacy handshake must not return.
if grep -Eq 'HOPE_SCREENSHOT_ACK_ROOT|HOPE_HOST_ACK_WRITTEN|.ready-$ack_marker|adb .*screencap -p|ack_marker=' "$script" "$dart_test"; then
  echo "runtime harness contract: FAIL — legacy host ACK/screencap handshake remains" >&2
  exit 1
fi

echo "runtime harness contract: PASS"
