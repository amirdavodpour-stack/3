---
applyTo: "lib/**/*.dart,test/**/*.dart"
---

# Flutter-specific HOPE guidance

- Consume canonical HOPE design tokens and shared UI primitives before inventing page-local values.
- Distinguish responsive scaling from adaptive layout decisions at compact, medium, and expanded widths.
- Preserve RTL mirroring and directional borders/padding.
- Preserve semantics, focus order, readable labels, and non-color-only state communication.
- Respect system reduced-motion preferences for nonessential animation.
- Prefer stable Keys or exact semantic/text anchors in widget tests; avoid positional `.at(n)` as the primary contract for lazy/adaptive content.
- For lazy content, use `WidgetTester.scrollUntilVisible` with the relevant `Scrollable` and an exact target.
- Keep tests deterministic and localized with the same delegates/locales used by the production surface.
