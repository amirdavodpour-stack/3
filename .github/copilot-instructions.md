# HOPE Copilot review rules

Review changes against the live HOPE architecture, not assumptions from older snapshots.

## Always check
- Main remains untouched until final release certification and signed APK verification.
- Changes are minimal and directly tied to the stated evidence or contract.
- Flutter UI preserves RTL, adaptive/responsive layouts, accessibility semantics, 48dp-class interactive targets, and explicit loading/empty/error/retry states.
- Financial UI uses localized internal Toman presentation and does not leak backend currency codes or technical enum values.
- Auth, wallet, payment lifecycle, idempotency, auditability, and security behavior are preserved.
- Tests cover the new contract and are anchored to stable semantic/text/key targets rather than positional lazy-widget assumptions.
- GitHub Actions use least-privilege permissions and immutable/full-SHA action references where practical.
- Release evidence is tied to the exact commit being certified.

When reviewing a failure, identify the first causal error from the relevant workflow logs before recommending changes. Do not recommend broad refactors for a localized defect.
