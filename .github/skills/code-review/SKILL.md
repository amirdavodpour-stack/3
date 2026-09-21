---
name: code-review
description: Review HOPE changes for correctness, regressions, security-sensitive behavior, UX/accessibility, test quality, and evidence. Use for pull-request and code-review tasks.
---
# HOPE code review
Review the live repository state, not historical assumptions.
## Required sequence
1. Identify exact branch, HEAD SHA, PR, base branch, and changed files.
2. Read AGENTS.md and applicable path-specific instructions.
3. Separate correctness, regression risk, security, UX/accessibility, test quality, and CI/release concerns.
4. For failures, find the first causal error in the relevant run/log before proposing changes.
5. Prefer the smallest causal change; avoid broad refactors for localized defects.
6. Require fresh evidence for the exact SHA under review.
## HOPE checks
- Main stays protected and untouched until release policy allows it.
- Auth, wallet, payment, idempotency, auditability, and release semantics must not regress.
- Flutter preserves RTL, responsive/adaptive behavior, accessibility, stable semantic test targets, and explicit loading/empty/error/retry states.
- Finance UI presents localized internal Toman semantics and does not leak backend currency codes or technical enums.
## Output
Lead with blocking findings by severity. For each finding include evidence, impact, exact area, and minimal remediation. State verified and unverified items.
