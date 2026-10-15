# HOPEv2 — Kinetic Editorial Icon & Sticker System

Status: Implemented on the isolated working branch for review; runtime visual acceptance pending.

## Direction

**Kinetic Editorial** pairs a coherent Cupertino/SF-inspired icon family with a lively but controlled editorial duotone language. The app remains dark navy/charcoal and multi-accented. The design does not switch the product to a single green palette and does not treat every symbol as an illustration.

## Two-layer language

1. **Core glyphs:** small, readable Cupertino IconData glyphs resolved from `HopeV2Icons` or `HopeV2NavigationIcons`. Line/filled state is reserved for selected navigation or real action state.
2. **Editorial frame:** short arcs, asymmetric cuts, trajectories and small duotone markers around selected status and empty-state glyphs.
3. **Category artwork:** deterministic procedural artwork in the opportunity fallback painter, using the category accent with existing indigo and teal roles. It stays compact and must never communicate price, success, trust or urgency through color alone.
4. **Brand exceptions:** retain the official multicolor Google G asset for Google sign-in. The Apple/Android device list uses neutral device glyphs while platform identity is carried in text.

## Color roles

- Surfaces: `#070A12`, `#0F111A`, `#111827`
- Primary interaction: `#6366F1` / `#818CF8`
- Information: `#0F766E` / `#5EEAD4`
- Success and trust: existing semantic green ramp
- Warning: existing semantic amber ramp
- Error: existing semantic red ramp

Decorative shapes may use the existing category accent, indigo and teal with low alpha. Amber/red/green are not added as generic confetti; their meanings remain semantic.

## Components updated

- `HopeV2Icons`: canonical consumer-facing Cupertino glyph vocabulary.
- `HopeV2NavigationIcons`: five navigation outline/filled pairs.
- `HopeIcon` / `HopeIconTile`: shared rendering adapter.
- `HopeKineticGlyph`: compact editorial frame for semantic state and empty-state glyphs.
- `HopeAsyncState` / `HopeFeedback` / lifecycle status: unified state icon mapping.
- `OpportunityCard`: category-specific procedural duotone artwork gains trajectory arcs, asymmetrical cuts and a restrained indigo/teal layer.

## Interaction and accessibility rules

- Preserve all labels, meanings and financial direction. Icons complement text.
- Do not infer or suggest successful payment until the backend-backed state reports success.
- Do not add motion to decorative art. Real loading/retry motion respects system reduce-motion.
- Preserve minimum hit targets, Persian RTL mirroring, contrast, screen-reader labels and compact hero/card dimensions.
- Icon-only header actions are capped at two and require Persian tooltips and accessible labels.
- Replace product-authored decorative emojis only. Do not automatically modify user-authored content, quoted text or emoji that carries meaning.

## Verification gates

- Focused icon/theme, async-state, feedback, navigation and opportunity-card tests.
- Full Flutter test suite and static analysis through repository CI.
- Exact-head runtime screenshots for Persian RTL and English LTR, dark/light, compact widths and text scaling.
- Review icon ambiguity at 16–24dp before considering the migration complete.

No production branch is targeted directly. This specification is reviewed with the feature branch and must pass its CI and runtime evidence gate before merge.
