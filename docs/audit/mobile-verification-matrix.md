# HOPE Mobile Verification Matrix

**Branch baseline:** `feat/google-sign-in-2026-09-20`  
**Baseline SHA:** `7ab37f5c6abcc49a842d4e852c1033375a4b6de6`  
**Rule:** Main remains untouched and PR #20 remains unmerged until final certification and signed APK verification.

## Verification layers

| Layer | Evidence | Acceptance |
|---|---|---|
| Static UX contract | `tools/verify-design-quality.sh` | PASS |
| Flutter analysis | `flutter analyze --no-fatal-warnings --no-fatal-infos` | PASS |
| Flutter regression | `flutter test --no-pub` | PASS |
| Runtime | `integration_test/runtime/app_smoke_test.dart` | PASS on Android infrastructure |
| Android E2E | Patrol / Maestro where available | PASS |
| Visual QA | Representative Android screenshots | Reviewed; no blocking overflow/contrast/interaction defect |
| Accessibility | Semantics, focusability, 48px targets, RTL/localization | PASS |
| Performance | Startup, frames/jank, scrolling, large lists, memory | No release-blocking regression |
| Security | OSV-Scanner, Trivy, zizmor, Codex Security when connected | No unresolved release-blocking finding |
| Release | Exact certified SHA + signed APK verification | PASS |

## Critical-flow matrix

| ID | Flow | Primary surfaces | Verify | Evidence |
|---|---|---|---|---|
| M01 | Launch / first render | Auth → Home shell | App renders without transient failure; primary navigation reachable | Android screenshot + runtime result |
| M02 | Guest / authenticated navigation | Home, NavigationBar/Rail | Guest privacy is preserved; authenticated destinations remain reachable | E2E result |
| M03 | Login | Login, session restore | Validation/loading/error states are usable; session establishes correctly | E2E result |
| M04 | Google Sign-In | Login → native account picker → app | Only when configured; native return-to-app and backend session are verified | Android E2E + screenshot |
| M05 | Marketplace discovery | Jobs / Opportunity Card | Search/filter hierarchy works; compact/medium/expanded layouts remain usable | Screenshots + E2E |
| M06 | Job detail | Job Detail | Identity → economics → scope → trust → lifecycle → action order is intact | Screenshot + E2E |
| M07 | Create job | Create Job | Validation and TOMAN values preserved; submit behavior unchanged | E2E result |
| M08 | Offers / applications | Offers, My Applications | State/status actions remain discoverable and semantically correct | E2E result |
| M09 | Notifications | Notifications | Unread state, action, time, and deep-link behavior preserved | E2E result |
| M10 | Wallet | Wallet | Available / locked / pending values remain distinct and TOMAN-labelled | Screenshot + test |
| M11 | Transactions | Transactions / Detail | Project linkage and lifecycle semantics preserved | Screenshot + test |
| M12 | Logout | Profile / Auth | Session is revoked and user returns to expected auth/guest state | E2E result |
| M13 | Network failure / retry | Any async surface | Error/offline/retry states remain actionable; no stuck loading | E2E + screenshot |
| M14 | Background / resume | App shell | State restoration does not corrupt navigation/auth/financial display | Device result |
| M15 | Permission / native dialogs | Location and Android-native surfaces | Dialogs are readable, actionable, and return control to app correctly | Android screenshot + E2E |

## Baseline evidence — 2026-09-20

The exact baseline SHA had a successful **Main CI** run (Run #512, workflow run ID `35543169122`) with backend/static, npm audit, Flutter lockfile, Flutter analyze, Flutter test, and staging performance smoke all successful. The Flutter suite reported **443 tests passed**.

The same SHA had a successful **Verify staging operational gate** run (Run #282, workflow run ID `35543169128`). This is an operational staging baseline, not final Android or release certification.

Android certification is intentionally not marked PASS by this document until the exact certified SHA is exercised by the Android emulator/device gate and its evidence is collected.

## Required per-run evidence

Record the exact Git SHA, workflow/run ID, job result, relevant artifact ID, test count, screenshots (where applicable), and any release-blocking findings. Never record secrets, access tokens, signing material, private user data, or full authentication artifacts.
