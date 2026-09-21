# HOPE — GitHub Free Engineering Operating System
**Status:** Engineering baseline / seed implementation
**Date:** 2026-09-21
**Repository:** amirdavodpour-stack/3
**Visibility:** Public
**Default branch:** Main

## 1. Operating objective
Build an agent-friendly engineering system that increases development and verification speed without removing critical quality or release controls.

`policy → deterministic automation → evidence → agent assistance → human/release authorization`

The Agent may inspect, implement, diagnose, test, and reconcile evidence in feature work. It must not be the final authority for Main protection, production authorization, secrets administration, destructive database actions, or security-policy exceptions.

## 2. GitHub Free/public-repository baseline
This repository is public. GitHub documents that standard Actions runners are free for public repositories. GitHub Free lists 2,000 monthly minutes, 500 MB shared artifact/Packages storage, and a 10 GB Actions cache allowance. Public repositories also receive CodeQL/code scanning, secret scanning, and dependency review without the paid private-repository Advanced Security requirement. Artifact attestations are available on GitHub Free for public repositories.

## 3. Priority model
### P0 — speed + correctness
- Change-aware tests instead of full certification for every commit.
- Concurrency cancellation for superseded runs.
- Dependency/toolchain caching.
- Parallel independent gates.
- Root-cause-first CI diagnosis.
- Exact-SHA evidence for release claims.
- Strong Main/Production boundaries.
### P1 — systemization
- Reusable workflows for duplicated deterministic gates.
- Repository-scoped agent skills.
- Incremental rulesets rather than one-shot governance migration.
- Dependabot + CodeQL + secret scanning + dependency review.
### P2 — optimization
- Feedback/queue/CI duration, flaky/rerun rate, time-to-diagnose/recovery, release cycle, rollback frequency, vulnerability age.
- Hooks only where deterministic enforcement adds value.
- Deep context only for critical paths.

## 4. Test and CI strategy
1. Fast PR gate: static checks + focused tests for affected areas.
2. Core regression gate: shared deterministic unit/widget/integration coverage.
3. Full certification: staging/payment/device/release evidence when scope or release policy requires it.

Do not reduce test confidence merely to save runner time. Reduce repeated work through caching, concurrency cancellation, change detection, reusable workflows, and parallel execution.

## 5. Release evidence contract
`source SHA → PR/review → workflow run → staging evidence → payment evidence → device evidence → production artifact → APK signature → SHA256 → SBOM → provenance/attestation → attestation verification → release authorization`

The exact source SHA must be bound to certification evidence. An attestation must be explicitly verified.

## 6. Agent operating model
### Autonomous feature-work scope
- repository inspection
- implementation
- test creation/update
- focused verification
- CI diagnosis
- minimal remediation
- read-only research
- evidence reconciliation
- maintenance of task-scoped repository skills
### Human authorization boundary
- Main modification/merge before final certification
- production release authorization
- secret creation/rotation/deletion
- destructive database operations
- security-policy exceptions
- release governance changes

## 7. Security/supply-chain baseline
Use the public-repository capabilities:
- CodeQL/code scanning
- secret scanning
- dependency review
- Dependabot
- full-SHA-pinned third-party Actions
- least-privilege token permissions
- OIDC for supported cloud authentication
- job-scoped production permissions
- signed APK verification
- SBOM + provenance/attestation + explicit verification

Avoid duplicate blocking checks. Make a control required only when it has a clear signal, failure mode, and actionable remediation.

## 8. Implemented seed in this branch
This branch adds:
- `.github/skills/code-review/SKILL.md`
- `.github/skills/security-review/SKILL.md`
- `.github/skills/release-review/SKILL.md`
- `.github/skills/finance-review/SKILL.md`
- `.github/skills/ci-diagnosis/SKILL.md`
- `.github/workflows/codeql.yml`
- `.github/workflows/dependency-review.yml`
- `.github/dependabot.yml`
- this specification

CodeQL is limited to JavaScript and GitHub Actions analysis; Flutter/Dart remains covered by existing Flutter quality/test gates.

## 9. Next engineering increments
1. Integrate change-impact detection into the existing Main/release test graph without weakening required gates.
2. Consolidate repeated deterministic logic into reusable workflows.
3. Harden `production-release.yml` with exact staging-SHA binding, payment certification prerequisite, job-scoped OIDC/attestation permissions, and workflow concurrency.
4. Add explicit `gh attestation verify` to release-validation.
5. Create the smallest useful Main ruleset alongside existing protection, observe it, then tighten after stable evidence.
6. Add a deterministic CI evidence summary for agent diagnosis and human release review.
7. Add hooks only after their default-branch activation path is deliberately planned.

## 10. Non-goals
- Do not weaken payment/wallet/auth/release semantics.
- Do not replace Main protection blindly.
- Do not add expensive certification to every ordinary PR.
- Do not give an agent unilateral production authority.
- Do not record intermediate research as project truth; only finalized findings and implementation outcomes belong in the permanent OS record.

## 11. Research basis
- GitHub Actions billing/usage: https://docs.github.com/en/actions/concepts/billing-and-usage
- GitHub rulesets: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
- GitHub CodeQL: https://docs.github.com/en/code-security/concepts/code-scanning/codeql/codeql-code-scanning
- GitHub secret scanning: https://docs.github.com/en/code-security/concepts/secret-security/secret-scanning
- GitHub artifact attestations: https://docs.github.com/en/actions/concepts/security/artifact-attestations
- GitHub agent skills: https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills
- GitHub hooks: https://docs.github.com/en/copilot/concepts/agents/hooks
- GitHub reusable workflows: https://docs.github.com/en/actions/concepts/workflows-and-actions/reusing-workflow-configurations
