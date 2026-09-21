---
name: security-review
description: Perform a focused HOPE security and supply-chain review of source, GitHub Actions, dependencies, secrets, and release provenance. Use for security-sensitive changes and CI hardening.
---
# HOPE security review
Treat this repository as public and assume pull-request code can be attacker-controlled.
## Required sequence
1. Inspect workflow triggers, permissions, secrets, environments, and action references.
2. Check shell interpolation, token exposure, credential persistence, broad writes, and trust-boundary violations.
3. Check dependency/action pinning, lockfiles, and supply-chain evidence.
4. Trace release provenance from source SHA through artifact, signature/hash, SBOM, attestation, and verification.
5. Keep high-risk controls deterministic; never delegate release authorization to an agent.
## HOPE controls
- Prefer job-scoped permissions and OIDC where supported.
- Isolate production-only permissions to the smallest job.
- Treat caches and downloaded artifacts as untrusted state.
- Never log secrets.
- Verify attestations; generation alone is insufficient.
- Require exact-SHA binding between certification evidence and release artifacts.
## Output
Classify findings as blocking, high, medium, or informational. Cite exact file/workflow evidence and give the smallest safe remediation.
