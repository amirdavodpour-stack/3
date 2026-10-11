# Wave25 — Compact Profile First-Fold Correction

**Status:** implementation prepared on the existing feature branch; requires exact-HEAD static and runtime verification.  
**Repository:** `amirdavodpour-stack/3`  
**PR:** [#30](https://github.com/amirdavodpour-stack/3/pull/30), must remain Draft/open/unmerged.  
**Pre-change HEAD:** `aca117898f290d7e1a4335c69a0d33bbd02c0288`  
**Finding source:** Wave24 rendered Android runtime artifact `11632481859`.

## Evidence and diagnosis

- Wave24 static verification [37960350028](https://github.com/amirdavodpour-stack/3/actions/runs/37960350028) passed with 102 tests.
- Wave24 same-HEAD runtime [37961937703](https://github.com/amirdavodpour-stack/3/actions/runs/37961937703) passed capture, contents validation and upload.
- Runtime archive SHA-256: `ec3f4cbc85b5803c939bd98b9865be192b25cc54b6f5814e160446a7df8e9317`.
- Metadata reports 19 primary screens (1080×1920) and 6 responsive screens at 720×1280 physical pixels, corresponding to 360×640 logical dp.
- At that compact profile viewport, the initial language selector sits against the navigation dock. The previous test used `scrollUntilVisible` before asserting geometry; it verified post-scroll reachability, not first-fold clearance.
- The runtime accessibility service reports disabled (`0`) and services `null`; TalkBack/T10 remains not accepted.

## Changes in this correction

1. Reduce the Profile header avatar from 32dp radius to 24dp only when the viewport is narrower than 500dp, reclaiming 16dp vertically on phones while retaining the 32dp desktop/tablet treatment.
2. Strengthen the focused Profile regression to model a 48dp bottom system/gesture inset, avoid auto-scrolling, require at least the existing 12dp gap above the dock on the initial fold, and verify the Persian segment remains tappable.
3. Standardize the post-static skip marker as `[flutter-preverified]` in both workflows. The static workflow owns the single consolidated Flutter invocation; runtime capture should not repeat it after exact-HEAD static PASS.
4. Extend source guards and require this report so the compact first-fold contract remains visible to future waves.

## Verification protocol

- Remove runtime/preverified title markers while the correction is being committed so the static workflow runs on the final new HEAD.
- Accept the correction only after backend/security/static, lock/dependency checks, contrast guard, design/runtime source guard, Flutter Analyze and the one consolidated Flutter invocation pass on that HEAD.
- Then set `[runtime-capture-fa] [flutter-preverified]` on PR #30 and capture runtime evidence on the same SHA. Validate metadata SHA, artifact digest, all 25 PNGs and the responsive Profile first fold.
- Runtime may not rerun Flutter tests after the exact-HEAD static gate. No backend, payment semantics, financial arithmetic, API payloads, route behavior or dependencies are in scope.
- Never merge; `main/production` remains forbidden and untouched.
