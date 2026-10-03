# HOPE Premium Max Grade + Live Mobile Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconstruct HOPE as a premium marketplace/fintech Flutter product and add a repeatable Android runtime, visual, accessibility, performance, and security verification loop.

**Architecture:** Keep backend, auth, payment lifecycle, routing, localization, and security contracts authoritative. Rebuild presentation through shared HOPE primitives; verify the rendered application on Android; keep release gates additive and fail closed.

**Tech Stack:** Flutter 3.47.2, Dart 3.12.x lock baseline, Flutter tests/integration_test, GitHub Actions, Flutter/Dart agent tooling, Patrol/Patrol MCP, Maestro/Maestro MCP, Trivy, OSV-Scanner, zizmor, PostHog, existing GitHub/Supabase/Railway.

**Spec:** docs/superpowers/specs/2026-09-21-hope-premium-max-grade-design.md

## Global Constraints

- Main stays untouched and PR #20 stays unmerged until final certification and signed APK verification.
- Internal finance remains TOMAN: 1 تومان = 1 internal unit.
- No external payment provider in the current phase.
- Keep Flutter 3.47.2 during reconstruction; version migration is a separate later task.
- Preserve existing behavioral tests unless behavior is intentionally changed.
- Persian-first RTL, formal functional Persian, localization parity, accessible 48px minimum interactive targets.
- Do not write secrets, credentials, API keys, or private user data to repository files.

## Review Focus

1. Navigation/primary actions remain reachable after visual restructuring.
2. RTL/English remain robust at compact, medium, and expanded widths.
3. Financial values and lifecycle states remain semantically correct and TOMAN-labelled.
4. Google Sign-In remains configuration-gated and is verified on Android when configured.
5. Loading, empty, error, offline/retry, permission, and resume states remain usable and accessible.

---

### Task 1: Repair and baseline verification

**Files:** `.github/workflows/main.yml`, `.github/workflows/android-emulator-certification.yml`, `.github/workflows/device-integration.yml`, create `tools/verify-design-quality.sh`, create `docs/audit/mobile-verification-matrix.md`.

- [ ] Add a script that runs localization/UX contract checks and verifies required design/runtime entrypoints.
- [ ] Record the critical-flow matrix: launch, auth, Google Sign-In, marketplace, job detail, create job, offers/applications, notifications, wallet, transactions, logout, network failure/retry, background/resume, native dialogs.
- [ ] Run the existing quality commands and record the baseline.
- [ ] Commit: `chore: add HOPE design and mobile verification guardrails`.

### Task 2: Premium design system

**Files:** `lib/core/theme/hope_v2_design.dart`, `lib/core/theme/app_theme.dart`, `lib/core/ui/premium_components.dart`, `lib/core/ui/components.dart`, `lib/core/ui/premium_lifecycle.dart`, `lib/core/ui/premium_payment_summary.dart`, `lib/core/ui/opportunity_card.dart`.

- [ ] Centralize typography, surfaces, semantic colors, finance emphasis, spacing, radius, motion, breakpoints, and touch-target tokens.
- [ ] Make shared premium primitives consume the same token source.
- [ ] Add explicit selected/pressed/disabled/loading/error states.
- [ ] Add focused widget tests for semantics, minimum targets, and compact-width resilience.
- [ ] Run focused tests.
- [ ] Commit: `refine: harden HOPE premium design primitives`.

### Task 3: Home and navigation reconstruction

**Files:** `lib/features/home/home_page.dart`, `lib/features/home/premium_home_feed.dart`, `lib/features/home/home_widgets.part.dart`, shell/routing files only when required.

- [ ] Pin guest/authenticated navigation and primary-action behavior in tests.
- [ ] Recompose Home as identity/context → relevant state → opportunity discovery → activity → finance → primary action.
- [ ] Replace one-off visual treatments with shared primitives.
- [ ] Verify RTL/English and responsive behavior.
- [ ] Run Home/application-shell tests.
- [ ] Commit: `refine: reconstruct HOPE premium home experience`.

### Task 4: Marketplace and job surfaces

**Files:** `lib/features/jobs/jobs_page.dart`, `jobs_filter_bar.part.dart`, `jobs_widgets.part.dart`, `lib/features/marketplace/job_detail_page.dart`, `create_job_page.dart`, `create_job_widgets.part.dart`, `lib/core/ui/opportunity_card.dart`.

- [ ] Preserve the current `ChoiceChip` widget contracts required by existing Jobs tests.
- [ ] Recompose marketplace as Opportunity Explorer with strong search/filter/results hierarchy and responsive grid/list behavior.
- [ ] Rebuild OpportunityCard as the primary decision component.
- [ ] Rebuild Job Detail as identity → economics → scope → trust → lifecycle → action.
- [ ] Rebuild Create Job hierarchy and validation while preserving TOMAN and repository behavior.
- [ ] Run marketplace tests.
- [ ] Commit: `refine: reconstruct HOPE marketplace and job surfaces`.

### Task 5: Finance/work surfaces

**Files:** wallet, transactions, transaction detail, offers, applications pages and their shared financial/lifecycle components.

- [ ] Add tests for available/locked/pending values, TOMAN labels, lifecycle states, transaction navigation, guest privacy, and payment-lookup isolation.
- [ ] Make available balance the primary wallet focal point and visually separate locked/pending values.
- [ ] Rebuild Transactions around project-linked financial state and next action.
- [ ] Rebuild Transaction Detail without changing release/approval semantics.
- [ ] Rebuild Offers/Applications with consistent state treatments.
- [ ] Run focused suites.
- [ ] Commit: `refine: reconstruct HOPE finance and work-status surfaces`.

### Task 6: Auth, notifications, profile, privacy, about, admin

**Files:** existing auth/notifications/profile/privacy/about/admin pages.

- [ ] Pin state-completeness tests for loading/error/empty/retry/guest/permission paths.
- [ ] Rebuild Auth while retaining Google configuration gating and auth behavior.
- [ ] Rebuild Notifications around unread state/action/time and preserve deep links.
- [ ] Rebuild Profile/Privacy without weakening destructive-action safeguards.
- [ ] Rebuild About while preserving tested `HeroBanner` contracts.
- [ ] Rebuild Admin tabs and operational information density without hiding raw operational detail.
- [ ] Run focused suites.
- [ ] Commit: `refine: complete HOPE secondary premium surfaces`.

### Task 7: Flutter/Dart agent tooling

**Files:** create/update development tooling documentation and checked-in configuration only where valid.

- [ ] Document exact Flutter/Dart version contract and live inspection procedure.
- [ ] Configure supported Flutter/Dart MCP tooling.
- [ ] Verify launch, runtime inspection, screenshot and one interaction in a supported environment.
- [ ] Commit: `chore: document Flutter agent runtime verification`.

### Task 8: Android E2E, Patrol, Maestro

**Files:** `integration_test/**`, `maestro/**`, Patrol config/tests if supported, Android certification workflows.

- [ ] Add launch/Home/Marketplace/Job Detail smoke flow.
- [ ] Add Login/Home/Profile/Logout flow.
- [ ] Add configuration-gated Google Sign-In flow and return-to-app validation.
- [ ] Add Wallet/Transaction flow.
- [ ] Add network failure/retry flow.
- [ ] Capture representative Android screenshots.
- [ ] Use Patrol for Flutter/native interaction boundaries and Maestro for concise screen regression where the local toolchain is available.
- [ ] Preserve existing Android network/KVM mitigations.
- [ ] Commit: `test: add HOPE live Android critical-flow coverage`.

### Task 9: Accessibility, visual QA, performance

**Files:** create `tools/check_accessibility_contract.sh`, create `tools/check_visual_smoke.sh`, focused tests/docs.

- [ ] Check semantics, touch targets, focusability, localization labels, and overflow resilience.
- [ ] Collect representative screenshots.
- [ ] Inspect startup, scrolling, animation/jank, large-list behavior and memory on key screens.
- [ ] Fix only defects evidenced by runtime inspection.
- [ ] Commit: `qa: add HOPE accessibility performance and visual verification`.

### Task 10: Security verification

**Files:** create `.github/workflows/security-scanning.yml`, create `docs/audit/security-tooling.md`, create supporting `tools/security/` files if needed.

- [ ] Add OSV-Scanner coverage for supported manifests/lockfiles.
- [ ] Add Trivy filesystem/dependency scanning.
- [ ] Add zizmor for GitHub Actions.
- [ ] Document/use Codex Security when the user can connect it.
- [ ] Classify and fix release-blocking findings only; preserve existing security invariants.
- [ ] Commit: `chore: add HOPE security verification layer`.

### Task 11: Final certification and release evidence

**Files:** release/verification workflows and audit evidence only.

- [ ] Run Flutter analyze and full test suite.
- [ ] Run staging certification on the exact SHA.
- [ ] Run payment certification.
- [ ] Run Android emulator/device certification and collect screenshots.
- [ ] Run security checks.
- [ ] Run release validation.
- [ ] Verify signed APK integrity and signing metadata without exposing secrets.
- [ ] Record exact SHA, workflow IDs, artifact IDs, and results.
- [ ] Stop before Main integration; merge only after explicit authorization.
