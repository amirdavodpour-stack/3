#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
test_file="$repo_root/integration_test/runtime/critical_screens_evidence_test.dart"
script_file="$repo_root/tools/hope-wallet-runtime-evidence.sh"

#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$PWD}"
test_file="$repo_root/integration_test/runtime/critical_screens_evidence_test.dart"
script_file="$repo_root/tools/hope-wallet-runtime-evidence.sh"

grep -Fq "const _adbScreenshotCapture" "$test_file"
grep -Fq "HOPE_SCREENSHOT_SYNC_ROOT" "$test_file"
grep -Fq "while (await request.exists())" "$test_file"
grep -Fq "await binding.takeScreenshot(marker);" "$test_file"
grep -Fq "adb exec-out screencap -p" "$script_file"
grep -Fq "capture_host_screenshot" "$script_file"
grep -Fq "assert_hope_focused()" "$script_file"
grep -Fq "assert_hope_rendered()" "$script_file"
grep -Fq "FOCUS_CHECK_TIMEOUT_SECONDS=" "$script_file"
grep -Fq "DRAW_CHECK_TIMEOUT_SECONDS=" "$script_file"
grep -Fq "HOPE_ADB_SCREENSHOT_CAPTURE=true" "$script_file"
grep -Fq "HOPE_RUNTIME_TEST_BODY_COMPLETE" "$test_file"

python3 - <<'PY'
from pathlib import Path
p = Path('integration_test/runtime/critical_screens_evidence_test.dart')
s = p.read_text()
block = s[s.index('Future<void> _prepareRuntimeScreenshotSurface'):s.index('Future<void> _captureRuntimeScreenshot')]
assert '_adbScreenshotCapture || _runtimeScreenshotSurfacePrepared' in block
PY

echo "PASS: Android ADB framebuffer screenshot transport contract"