---
name: release-review
description: Verify HOPE release readiness, certification-to-SHA binding, signed APK integrity, SBOM, provenance, attestation, and authorization gates. Use before production release decisions.
---
# HOPE release review
Release review is evidence reconciliation, not an opinion.
## Required evidence chain
`source SHA → PR/review → workflow run → staging certification → payment certification → device evidence → artifact → signature/hash → SBOM → attestation → attestation verification → release authorization`
## Blocking checks
- Certified SHA equals artifact source SHA.
- Staging certification is PASS for that SHA.
- Payment certification is PASS for the same release candidate when financial scope applies.
- APK signature verification succeeds.
- SHA-256 and release manifest match the uploaded artifact.
- SBOM/provenance/attestation exist and map to the exact artifact.
- Attestation verification is executed explicitly.
- Production credentials and OIDC/attestation permissions are job-scoped.
- Agents cannot unilaterally authorize Main merge or production release.
## Output
Return a deterministic PASS/BLOCKED/UNVERIFIED checklist with exact evidence references.
