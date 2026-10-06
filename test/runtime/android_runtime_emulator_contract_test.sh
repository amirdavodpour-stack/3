#!/usr/bin/env sh
set -eu

workflow=".github/workflows/hope-ui-runtime-evidence.yml"
runtime="integration_test/runtime/critical_screens_evidence_test.dart"

test -f "$workflow"
test -f "$runtime"

grep -Fq "system-images/android-34/default/x86_64" "$workflow"
grep -Fq "hope-android-sdk-api34-cmake3.22.1-default" "$workflow"
grep -Fq "hope-android-avd-api34-default-pixel2" "$workflow"
grep -Fq "api-level: 34" "$workflow"

register_block="$(sed -n '/if (child is RegisterPage)/,/if (child is PasswordResetPage)/p' "$runtime")"
printf '%s
' "$register_block" | grep -Fq "HOPE_RUNTIME_REGISTER_DIRECT_CAPTURE"
if printf '%s
' "$register_block" | grep -Eq "await tester\.pump|Future<void>\.delayed"; then
  echo "FAIL: Register capture must not add a timed/async settle after surface preparation" >&2
  exit 1
fi

echo "PASS: Android 34 emulator capture contract"
echo "PASS: Register direct-capture contract"
