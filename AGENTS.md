# HOPE agent operating rules

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
