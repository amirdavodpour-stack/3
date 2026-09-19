# Agent Resource and Change Policy

This repository is maintained through explicit, auditable checkpoints. Automation may inspect and modify the active hardening branch, but it must preserve provenance and never manufacture release evidence.

## Source authority

The checked-out branch and its committed files are authoritative for implementation work. Historical ZIPs, previous reports, cached logs, generated summaries, and other artifacts are evidence only unless the task explicitly promotes one to the source of truth.

## Git safety

- Never write to `main` for this hardening operation.
- Never merge the hardening pull request as part of automated continuation.
- Prefer one coherent commit for a logical repair set when using GitHub contents/tree operations.
- Avoid creating duplicate diagnostic artifacts when a prior verified artifact already covers the same gate.

## CI and evidence safety

Every release-oriented action must use immutable action references. Runtime evidence must be emitted only by `backend/tools/write-evidence.mjs` during a real CI run. Evidence records the observed result and CI run URL; it must not be hardcoded as a pass.

Environment-dependent gates must fail closed. A missing credential, endpoint, emulator, provider, database, or storage integration is not silently converted into a successful certification. It is either an explicit honest skip with no evidence or a failing gate, according to the gate contract.

## Test discipline

Do not rerun an expensive completed test solely to obtain a prettier report. Reuse the preserved run and artifact identifiers when they still correspond to the unchanged tested source. Rerun only when source changes invalidate the earlier evidence or when a contract specifically requires a fresh run.
