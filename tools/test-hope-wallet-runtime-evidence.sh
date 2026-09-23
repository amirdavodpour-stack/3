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

echo "runtime harness contract: PASS"
