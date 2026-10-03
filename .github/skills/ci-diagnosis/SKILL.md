---
name: ci-diagnosis
description: Diagnose failing HOPE GitHub Actions runs quickly and produce a minimal, evidence-backed remediation path. Use whenever a workflow or gate fails.
---
# HOPE CI diagnosis
Optimize time-to-diagnosis without weakening the gate.
## Required sequence
1. Identify workflow, run ID, commit SHA, job, and first failing step.
2. Read the first causal error; ignore downstream noise until causality is established.
3. Classify: product code, test, dependency/toolchain, infrastructure/network, workflow logic, credential/configuration, or flaky/non-deterministic.
4. Compare with the last green run only after understanding the current failure.
5. Reproduce with the smallest relevant command or focused test.
6. Apply the smallest causal fix.
7. Add a regression test when the defect represents a missing behavioral contract.
8. Re-run only gates needed to validate the causal fix, then the authoritative release gate when required.
## Parallelism
While remote CI runs, continue independent read-only work such as log inspection, source tracing, test preparation, documentation, and evidence reconciliation. Do not duplicate expensive certification runs without cause.
