# HOPE Visual Regression Matrix

Status: ACTIVE — source-aligned visual QA contract  
Branch: `feat/google-sign-in-2026-09-20`

## Visual targets

| Surface | Compact | Medium | Expanded | RTL | Dark | Reduced motion |
|---|---:|---:|---:|---:|---:|---:|
| Home | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Marketplace / Jobs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Opportunity Detail | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Create / Edit Job | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Auth | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Wallet / Transactions | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Profile / Settings | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## Canonical visual checks

### Geometry
- Minimum interactive target: 48px.
- Shared radii must resolve from `HopeV2Radii`.
- Shared spacing must resolve from `HopeV2Spacing`.
- No new screen-local radius/spacing literals when a canonical token exists.

### Typography
- Product font remains Vazirmatn.
- Persian/English line wrapping must not clip ascenders/descenders.
- Long titles and mixed RTL/LTR content must remain readable.
- Numeric values must preserve intentional directionality.

### Color
- Shared semantic states resolve from `HopeV2Colors` / `HopeV2SemanticColors`.
- Input, chip, navigation, divider and control surfaces resolve from canonical surface tokens.
- No raw semantic warning/error/success colors in screen code.

### Motion
- Reduced motion removes decorative transitions/spinners where a static state is equivalent.
- Press/focus feedback remains available without animation.
- Loading, retrying and submitting states retain clear non-motion affordances.

### Accessibility
- Native text fields retain native semantics and current value.
- Interactive wrappers must not hide child semantics unless an explicit replacement label is supplied.
- Keyboard activation: Enter + Space.
- Focus state is visually distinguishable.
- Tooltips/copy use localization APIs or project localization resources.

## Required visual states per major screen

1. Default content
2. Loading
3. Empty
4. Error
5. Retry
6. Offline / degraded network
7. Long-content / overflow
8. RTL Persian
9. English LTR
10. Dark theme
11. Reduced motion
12. Keyboard focus

## Certification rule

A source-level visual pass is **NOT** a runtime visual pass.

Runtime certification requires screenshots or equivalent rendered evidence at the target viewport/theme/locale/state. Until that evidence exists, the state remains `UNVERIFIED`.

## Current wave

Completed source-level hardening:
- shared geometry/surface token consolidation
- SearchField semantics + localized clear tooltip
- PressableScale semantics + keyboard activation
- reduced-motion async/filter loading
- Marketplace filter touch target
- aggregate interaction/accessibility tests

Pending runtime visual evidence:
- real device/emulator screenshots
- compact/medium/expanded comparison
- Persian/English comparison
- light/dark comparison
- reduced-motion comparison
- loading/empty/error/retry visual evidence
