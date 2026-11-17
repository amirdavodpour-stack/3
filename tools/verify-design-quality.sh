#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { echo "DESIGN QUALITY BLOCKED: $*" >&2; exit 1; }
need_file() { [[ -f "$1" ]] || fail "missing required file: $1"; }

required_files=(
  pubspec.yaml
  lib/core/theme/hope_v2_design.dart
  lib/core/theme/app_theme.dart
  lib/core/ui/components.dart
  lib/core/ui/premium_components.dart
  lib/core/ui/opportunity_card.dart
  lib/core/ui/premium_lifecycle.dart
  lib/core/ui/premium_payment_summary.dart
  lib/core/ui/hope_async_state.dart
  lib/core/ui/hope_l10n.dart
  lib/l10n/app_fa.arb
  lib/l10n/app_en.arb
  lib/features/auth/login_page.dart
  lib/features/auth/register_page.dart
  lib/features/home/home_page.dart
  lib/features/marketplace/job_detail_page.dart
  lib/features/marketplace/create_job_page.dart
  lib/features/jobs/jobs_page.dart
  lib/features/offers/offers_page.dart
  lib/features/applications/my_applications_page.dart
  lib/features/notifications/notifications_page.dart
  lib/features/wallet/wallet_page.dart
  lib/features/transactions/transactions_page.dart
  lib/features/profile/profile_page.dart
  integration_test/runtime/app_smoke_test.dart
  integration_test/runtime/flutter_runtime_test.dart
  tools/android-staging-network-preflight.sh
  test/flutter_test_config.dart
  test/core/quality/hope_accessibility_gate_test.dart
  test/core/quality/hope_quality_matrix_test.dart
  test/core/finance/toman_formatter_test.dart
  lib/core/finance/toman_formatter.dart
)
for f in "${required_files[@]}"; do need_file "$f"; done

python3 - <<'PY'
import json
from pathlib import Path

root = Path(".")
fa = json.loads((root / "lib/l10n/app_fa.arb").read_text(encoding="utf-8"))
en = json.loads((root / "lib/l10n/app_en.arb").read_text(encoding="utf-8"))
fa_keys = {k for k in fa if not k.startswith("@")}
en_keys = {k for k in en if not k.startswith("@")}
missing_en = sorted(fa_keys - en_keys)
missing_fa = sorted(en_keys - fa_keys)
if missing_en or missing_fa:
    print("Localization parity failure.")
    if missing_en: print("Missing from app_en.arb:", ", ".join(missing_en[:20]))
    if missing_fa: print("Missing from app_fa.arb:", ", ".join(missing_fa[:20]))
    raise SystemExit(1)
print(f"Localization parity PASS ({len(fa_keys)} message keys)")
PY

grep -q "class HopeV2Touch" lib/core/theme/hope_v2_design.dart || fail "touch-target token is missing"
grep -q "minimum = 48.0" lib/core/theme/hope_v2_design.dart || fail "48px minimum target token is missing"
grep -q "class PremiumPageFrame" lib/core/ui/premium_components.dart || fail "PremiumPageFrame is missing"
grep -q "class PremiumStatCard" lib/core/ui/premium_components.dart || fail "PremiumStatCard is missing"
grep -q "enum OpportunityCardVariant" lib/core/ui/opportunity_card.dart || fail "OpportunityCard is missing"
grep -q "IntegrationTestWidgetsFlutterBinding.ensureInitialized" integration_test/runtime/app_smoke_test.dart || fail "runtime smoke binding is missing"
grep -q "continueAsGuest" integration_test/runtime/app_smoke_test.dart || fail "guest smoke path is missing"
grep -q "loginWithGoogle" lib/features/auth/login_page.dart || fail "Google Sign-In action contract is missing"
grep -R -q "تومان" lib/features/wallet lib/features/transactions || fail "TOMAN labelling is not present in finance surfaces"
grep -q "semanticsIdentifier" lib/core/ui/premium_components.dart || fail "stable semantics identifier contract is missing"
grep -q "HopeTomanFormatter.grouped" lib/core/ui/copy.dart || fail "TOMAN display formatter is not connected"

echo "HOPE design/runtime guardrails PASS"
echo "  files: ${#required_files[@]}"
echo "  localization: fa/en parity"
echo "  touch target: 48px"
echo "  runtime: Flutter integration smoke entrypoint"
echo "  finance: TOMAN label contract"
