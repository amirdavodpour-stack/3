#!/usr/bin/env bash
set -euo pipefail

script="tools/hope-wallet-runtime-evidence.sh"
test -f "$script"
bash -n "$script"

grep -Eq 'HOPE_HOST_CAPTURE_DETECTED:' "$script"
grep -Eq 'HOPE_HOST_SCREENSHOT_CAPTURED:' "$script"
grep -Eq 'HOPE_HOST_ACK_WRITTEN:' "$script"
grep -Eq 'timeout .*adb wait-for-device' "$script"
grep -Eq 'timeout .*adb exec-out screencap -p' "$script"
grep -Fq 'test -s "$evidence_dir/$output"' "$script"
grep -Eq 'ack_marker="\$\{marker#HOPE_SCREENSHOT_READY:\}"' tools/hope-wallet-runtime-evidence.sh
grep -Eq 'touch "files/hope-screen-acks/\$ack_marker"' tools/hope-wallet-runtime-evidence.sh
grep -Eq 'timeout .*adb shell run-as com.hope.marketplace mkdir -p files/hope-screen-acks' "$script"
grep -Eq 'timeout .*adb shell run-as com.hope.marketplace touch "files/hope-screen-acks/\$ack_marker"' "$script"
if grep -Fq 'adb shell run-as com.hope.marketplace rm -rf files/hope-screen-acks' "$script"; then
  echo "runtime harness contract: FAIL — responsive preflight uses run-as after the app may have exited" >&2
  exit 1
fi
test "$(grep -Fc 'adb shell run-as com.hope.marketplace mkdir -p files/hope-screen-acks' "$script")" -eq 1

grep -Fq -- '--dart-define=HOPE_RESPONSIVE_ONLY=true' "$script"
grep -Fq "bool.fromEnvironment('HOPE_RESPONSIVE_ONLY')" integration_test/runtime/critical_screens_evidence_test.dart

responsive_block="$(sed -n '/responsive_screens=(/,/)/p' "$script")"
test "$(printf '%s\n' "$responsive_block" | grep -n '"responsive-720x1280-transactions-fa-rtl"' | cut -d: -f1)" -lt "$(printf '%s\n' "$responsive_block" | grep -n '"responsive-720x1280-wallet-fa-rtl"' | cut -d: -f1)"
test "$(printf '%s\n' "$responsive_block" | grep -n '"responsive-720x1280-wallet-fa-rtl"' | cut -d: -f1)" -lt "$(printf '%s\n' "$responsive_block" | grep -n '"responsive-720x1280-profile-fa-rtl"' | cut -d: -f1)"

grep -Fq 'READY_CHECK_TIMEOUT_SECONDS="${HOPE_READY_CHECK_TIMEOUT_SECONDS:-2}"' "$script"
grep -Fq 'grep -Fq -- "$marker" "$active_runtime_log"' "$script"
grep -Fq 'adb shell run-as com.hope.marketplace sh -c' "$script"
grep -Fq 'until [ -e '\''files/hope-screen-acks/.ready-$ack_marker'\'' ]; do sleep 0.1; done' tools/hope-wallet-runtime-evidence.sh
echo "runtime harness contract: PASS"
