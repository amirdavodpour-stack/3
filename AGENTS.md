# HOPE agent operating rules

## Stack
- Mobile client: Flutter/Dart (`hope_mobile`); Android runtime target. `pubspec.yaml` declares Flutter >=3.47.0; CI pins Flutter 3.47.2.
- Backend: Node.js/npm under `backend/`; the Static workflow runs `npm ci`, `npm run test:fast`, `npm audit --audit-level=high`, and `npm run check`.
- UI tests: `flutter_test` widget/regression suites; `integration_test` for Android runtime evidence. Runtime capture harness: `integration_test/runtime/critical_screens_evidence_test.dart`.
- CI evidence: `.github/workflows/hope-ui-wave-1-static.yml` is the static/backend/Flutter gate; `.github/workflows/hope-ui-runtime-evidence.yml` is the serialized Android rendered-evidence gate.
- Accessibility audit adaptation: Flutter semantics, labels, roles/actions, focus order, 360dp/narrow viewport behavior, RTL/LTR, and increased text scale must be tested with `flutter_test`/`WidgetTester`. Android TalkBack acceptance requires actual enabled-service evidence; screenshots or static checks alone do not qualify.
- Workflow authority: inspect current branch, exact HEAD, pull-request metadata, and Actions evidence before every code change or completion claim. Never infer a pass from an older SHA.


## Repository safety
- Work from the live branch/HEAD/diff and current GitHub Actions evidence.
- Never modify or merge `Main` before the final certification and signed-production-artifact verification gates are explicitly PASS.
- Never infer PASS from a historical run, a different SHA, or a green sub-job.
- Preserve completed fixes; reproduce a change only when new evidence justifies it.

## Engineering method
- For behavior changes, prefer failing-first tests, minimal implementation, fresh verification, and exact SHA evidence.
- When a check fails, identify the first concrete failure from logs and fix the smallest causal surface.
- Do not stack unrelated refactors on an unverified red baseline.
- Keep security/auth/wallet/payment/release semantics stable while improving UX.

## HOPE product contracts
- Current financial presentation is internal Toman: 1 Toman = 1 internal unit.
- Never expose backend currency codes/enums directly in user-facing UI when a localized product label exists.
- Preserve RTL, responsive/adaptive behavior, accessibility semantics, loading/empty/error/retry states, and idempotent financial actions.
- Analytics data must come from a valid connected project/scope; never invent product metrics.

## Release evidence
Maintain the traceability chain:
source SHA -> workflow run -> staging evidence -> production artifact -> signature/hash -> provenance/SBOM/attestation -> release decision.
