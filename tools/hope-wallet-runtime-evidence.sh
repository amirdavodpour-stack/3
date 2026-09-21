#!/usr/bin/env bash
set -euo pipefail

evidence_dir="${GITHUB_WORKSPACE:-$PWD}/docs/audit/evidence/android-runtime"
mkdir -p "$evidence_dir"

runner_temp="${RUNNER_TEMP:-/tmp}"
log_file="$runner_temp/hope-wallet-runtime.log"
rm -f "$log_file"
: > "$log_file"

set +e
stdbuf -oL -eL flutter test --no-pub \
  integration_test/runtime/wallet_surface_evidence_test.dart \
  -r expanded 2>&1 | tee "$log_file" &
test_pid=$!
set -e

capture_screen() {
  local marker="$1"
  local output="$2"

  for _ in $(seq 1 90); do
    if grep -q -- "$marker" "$log_file"; then
      adb wait-for-device
      adb exec-out screencap -p > "$evidence_dir/$output"
      return 0
    fi

    if ! kill -0 "$test_pid" 2>/dev/null; then
      break
    fi

    sleep 2
  done

  echo "Timed out waiting for screenshot marker: $marker" >&2
  return 1
}

capture_screen "HOPE_SCREENSHOT_READY:wallet-fa-rtl" "wallet-fa-rtl.png"
capture_screen "HOPE_SCREENSHOT_READY:wallet-en-ltr" "wallet-en-ltr.png"

set +e
wait "$test_pid"
test_status=$?
set -e

adb shell getprop ro.build.version.release > "$evidence_dir/android-version.txt"
adb shell getprop ro.product.model > "$evidence_dir/device-model.txt"
adb shell wm size > "$evidence_dir/viewport.txt"

cat > "$evidence_dir/metadata.json" <<EOF
{
  "workflow": "${GITHUB_WORKFLOW}",
  "run_id": "${GITHUB_RUN_ID}",
  "ref": "${GITHUB_REF_NAME}",
  "sha": "${GITHUB_SHA}",
  "surface": "WalletPage",
  "evidence_type": "rendered_android_runtime",
  "locales": ["fa-RTL", "en-LTR"],
  "theme": "light",
  "interactive_target_contract": "48px",
  "test_exit_code": $test_status
}
EOF

cat "$log_file"
exit "$test_status"
