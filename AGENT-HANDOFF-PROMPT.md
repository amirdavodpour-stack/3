# HOPE Agent Handoff

## Operating contract

Resume work from the current branch checkpoint; do not restart completed phases or replace the authoritative source archive unless explicitly instructed. The active hardening branch is the only write target for this work. `main` is production and must not be modified or merged as part of an implementation handoff.

## Evidence discipline

- No fake green.
- Do **not** declare V1 COMPLETE based on source inspection, a partial test run, or an inherited report.
- A gate is `PASS` only when the named automated command actually ran and its observed outcome was successful.
- Environment-dependent evidence such as staging, device, provider, S3, performance, and disaster-recovery certification is `UNVERIFIED` until the corresponding workflow executes and records evidence.
- A failed or unavailable gate is recorded honestly as `BLOCKED` or `UNVERIFIED`; do not convert it to a pass by editing a report or hardcoding evidence.

## Resume procedure

1. Read this handoff and the current branch head.
2. Preserve already-verified results and avoid rerunning expensive completed gates without a reason.
3. Inspect the current source before changing it.
4. Implement the smallest coherent change set that advances the release contract.
5. Run the relevant automated contracts and preserve their raw outputs.
6. Push only to the hardening branch and keep `main` untouched.

## Release decision boundary

A release candidate requires source checks, backend contracts, Flutter verification, staging certification, device certification, and production artifact verification to be independently observed. Passing documentation is not a substitute for execution evidence.

## Current hardening checkpoint

The backend contract suite is the active verification gate after the Flutter checkpoint. Treat its latest real GitHub Actions run as the source of truth for remaining backend/CI failures; do not reuse an older failing run after source changes.
