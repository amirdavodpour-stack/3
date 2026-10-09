# Wave 22 Audit + Implementation Report — 2026-10-09

## Verified baseline
- Repository: `amirdavodpour-stack/3`
- Feature HEAD: `02642301ffda8c89179f1e9d867d5e6deaeeb14c`
- PR #30: Draft / unmerged; base `feat/google-sign-in-2026-09-20`.
- Static gate: [37923933729](https://github.com/amirdavodpour-stack/3/actions/runs/37923933729) PASS.
- Android runtime: [37924126059](https://github.com/amirdavodpour-stack/3/actions/runs/37924126059) SUCCESS on exact feature HEAD.
- Artifact ID `11613522157`; SHA-256 `8c3e73a9121e7ee4c2f8374d6ce5771ac73779864b4e206578614e5542bf35b4`.
- Artifact metadata `sha` matched feature HEAD. There are 19 primary 1080×1920 PNGs and six responsive 720×1280 PNGs, equivalent to 360×640dp at 320dpi. All 25 images were individually inspected; the archive checksum matches the GitHub artifact digest.
- Runtime recorded `accessibility_enabled=0` and `accessibility-services.txt: null`; screenshots do not certify TalkBack.

## Individual evidence matrix

| Screenshot | Wave 21 outcome / residual evidence | Wave 22 action |
|---|---|---|
| `login-fa-rtl.png` | Icon/title overlap fixed, but crossed decorative geometry remains behind title | Replace compact fallback with accent gradient + diffuse glow |
| `register-fa-rtl.png` | Same compact geometric decoration remains | Shared compact Hero fix |
| `password-reset-fa-rtl.png` | Same background geometry behind heading | Shared compact Hero fix |
| `notifications-fa-rtl.png` | Jalali date correctly renders ۱۴۰۵ شهریور ۳۰ | No change |
| `offers-fa-rtl.png` | All four filters visible and date fixed | No change |
| `wallet-fa-rtl.png` | Duplicate amounts removed; history title/filter sits at bottom edge | Reduce wallet stack and wrap filters |
| `responsive-720x1280-wallet-fa-rtl.png` | History section not shown within the 360×640dp first capture | Compact wallet card and lifecycle panel |
| `job-detail-fa-rtl.png` | Four full-width match bars and repeated category/location traits delay description | Two-column scores; hide duplicate trait panel on compact |
| `responsive-720x1280-job-detail-fa-rtl.png` | Opportunity description begins below the first compact fold | Same compact detail fix |
| `saved-searches-fa-rtl.png` | Single result near top; distant FAB leaves large empty area | Put create CTA after list/empty state |
| `financial-insights-fa-rtl.png` | Wave 21 metric tiles are grouped; money labels wrap | No change |
| `home-fa-rtl.png` | Featured Toman range complete | No change |
| `responsive-720x1280-home-fa-rtl.png` | Complete featured range at compact width | No change |
| `jobs-fa-rtl.png` | Search/count/filters and first opportunity card readable | No change |
| `responsive-720x1280-jobs-fa-rtl.png` | First result visible; later results scroll naturally | No change |
| `profile-fa-rtl.png` | Account/trust panels coherent; settings below fold | No change |
| `responsive-720x1280-profile-fa-rtl.png` | Settings continue naturally under navigation | No change |
| `transactions-fa-rtl.png` | Collaboration/transaction summary readable | No change |
| `responsive-720x1280-transactions-fa-rtl.png` | Transaction composition coherent at compact size | No change |
| `transaction-detail-fa-rtl.png` | Financial summary, lifecycle and exact values legible | No change; no ledger semantics |
| `applications-fa-rtl.png` | Single fixture leaves expected whitespace; status/progress clear | No change |
| `candidate-matches-fa-rtl.png` | Candidate ranks and scores remain clear | No change |
| `chat-fa-rtl.png` | Whitespace reflects sparse fixture; composer usable | No change |
| `job-satisfaction-fa-rtl.png` | Rating controls visible; lower form scrolls | No change |
| `create-job-fa-rtl.png` | Progress, type selection and live preview readable | No change |

## Wave 22 implementation
1. Compact Auth Hero fallback becomes a clean accent-led gradient plus diffuse glow; no crossing outlines behind title. Wide editorial fallback remains intact.
2. Compact decision-strip scores use a two-column responsive grid, preserving all skills/category/location/salary scores.
3. Compact Opportunity Detail does not repeat the DNA panel's category/location immediately below the same values in the decision strip; wide layout keeps it.
4. Tighten compact wallet card and lifecycle panel; preserve exact amounts and balance touch targets. Wallet history filters use Wrap, not hidden horizontal scroll.
5. Move Saved Search create action into normal scroll order after the result/empty state; remove the distant floating FAB.

## Verification contract
One consolidated Flutter invocation:
```
flutter test --no-pub test/core/ui/premium_visual_wave_15_test.dart test/core/ui/hope_display_formatters_test.dart test/features/wallet/wallet_page_test.dart test/features/marketplace/job_detail_page_test.dart test/features/jobs/saved_searches_page_test.dart
```
Require the full static gate on exact new HEAD: backend fast/security/static checks, lock/dependencies, localization/contrast/source guards, Flutter Analyze, and that one test invocation. Only after static PASS, add `[runtime-capture-fa] [wave22-preverified]` and capture Android once on exact HEAD.

## Acceptance invariants
- Wallet balance/reserve/transaction models stay authoritative. No currency arithmetic or ledger-state changes.
- Opportunity detail keeps all real scores, exact Toman budget, description and primary action.
- Preserve RTL/LTR, 48dp controls, existing visual tokens and dependency set.
- PR #30 remains Draft/unmerged; `main/production` untouched.
- T10 remains NOT ACCEPTED until Wave 22 metadata matches exact SHA and all 25 PNGs are reviewed individually.
