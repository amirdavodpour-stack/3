# HOPE Premium Max Grade + Live Mobile Verification Design

## Status
Draft for review. This document defines the next product/engineering pass on branch `feat/google-sign-in-2026-09-20`. Main remains untouched.

## Goal
Turn the current HOPE Flutter client into a distinctive premium marketplace/fintech mobile experience while establishing a repeatable verification loop that validates the real Android UI, native interactions, critical workflows, performance, accessibility, and security before release.

## Product Direction
The frontend may diverge substantially from the current visual composition. Existing backend capabilities, security contracts, routing semantics, localization rules, and financial lifecycle remain authoritative.

Design principles:
- Persian-first, RTL-native, formal functional Persian.
- Premium fintech/marketplace visual language rather than default Material styling.
- Strong hierarchy, restrained gradients, deliberate depth, meaningful motion, and consistent iconography.
- Every success, loading, empty, error, offline, and permission state receives the same design quality.
- Financial information is prominent and trustworthy.
- Currency remains `تومان`; 1 تومان equals 1 internal unit.
- Avoid slogan-heavy or machine-like copy.
- Preserve accessibility: semantic labels, 48px minimum interactive targets, focus/contrast/readability, dynamic text resilience.

## Experience Architecture
### Home
Identity, relevant state, opportunity discovery, activity, finance, and primary action are organized into a clear visual hierarchy.

### Marketplace
Opportunity Explorer with meaningful filters, strong opportunity cards, responsive list/grid behavior, and clear action hierarchy.

### Job Detail
Decision surface ordered around identity, economics, scope, trust, lifecycle, and action. Owner/candidate capabilities remain intact.

### Wallet and Transactions
Financial hierarchy uses available/locked/pending states, project-linked transaction summaries, lifecycle visualization, and unambiguous next actions.

### Offers / Applications / Notifications
Shared premium primitives and consistent state semantics replace one-off visual treatments while preserving existing behavioral contracts.

### Auth
Premium Login/Register surfaces preserve current authentication behavior and Google Sign-In gating. Real Android verification covers sign-in, return-to-app, session establishment, and failure states.

## Design System
Centralize tokens and primitives for spacing, radii, typography, semantic colors, surfaces, elevation, motion, breakpoints, touch targets, and component states. Prefer shared primitives over per-page styling.

Required primitives include:
- Premium page frame
- Header/hero
- Surface/panel
- Stat/metric card
- Opportunity card
- Lifecycle
- Status/tag
- Search/filter controls
- Empty/loading/error states
- Primary/secondary/destructive actions
- Financial summary

## Mobile Verification Architecture
Use complementary layers:
1. Flutter/Dart tooling and MCP for live diagnostics, widget/runtime inspection, screenshots, and developer-tool operations.
2. Flutter tests for unit/widget contracts.
3. Patrol for Flutter-first E2E and native Android interactions.
4. Maestro for concise cross-screen regression flows and accessibility-driven interaction.
5. GitHub CI for deterministic quality gates.
6. Security scanning with Codex Security when available, plus Trivy/OSV-Scanner/zizmor where appropriate.
7. PostHog remains fail-open product analytics; Telemetry remains authoritative for operational diagnostics.

The verification loop is:
`code -> analyze -> tests -> live runtime inspection -> Android E2E -> visual inspection -> security -> regression -> signed artifact`.

## Critical E2E Flows
- Launch and first-render
- Login / logout
- Google Sign-In and return-to-app
- Browse marketplace
- Open job detail
- Create job
- Apply / offer flows
- Notifications and deep actions
- Wallet
- Transaction lifecycle
- Network failure/retry
- Permission/native dialog handling
- App background/resume

## Performance
Keep Flutter 3.47.2 as the current stable baseline during the reconstruction. Version migration is a separate change after the release path is stable. Performance review includes startup, frame rendering/jank, scrolling, large lists, memory behavior, and network wait states.

## Security and CI
Do not weaken or bypass existing security, payment, auth, or staging gates. Do not introduce an external payment provider for the current internal-TOMAN mode. Main remains untouched until the full release certification and signed APK verification are complete.

## Acceptance Criteria
The pass condition is not merely a green unit-test suite. The implementation is considered release-ready only when:
- Flutter analysis and project tests pass.
- Existing behavioral test contracts remain valid.
- Critical Android E2E flows pass on emulator/device infrastructure.
- Google Sign-In is verified on Android when configuration is supplied.
- UI is reviewed from real rendered screens, not only source code.
- Accessibility and interactive-target checks pass.
- Security scans report no unresolved release-blocking findings.
- Release validation produces and verifies the signed artifact for the exact certified SHA.
