# HOPEv2 — Kinetic Editorial Icon & Sticker System

Status: Implemented on the isolated working branch for review; runtime visual acceptance pending.

## Direction

**Kinetic Editorial** pairs a coherent Cupertino/SF-inspired icon family with a lively but controlled editorial duotone language. The app remains dark navy/charcoal and multi-accented. The design does not switch the product to a single green palette and does not treat every symbol as an illustration.

## Two-layer language

1. **Core glyphs:** small, readable Cupertino IconData glyphs resolved from `HopeV2Icons` or `HopeV2NavigationIcons`. Line/filled state is reserved for selected navigation or real action state.
2. **Editorial frame:** short arcs, asymmetric cuts, trajectories and small duotone markers around selected status and empty-state glyphs.
3. **Category artwork:** deterministic procedural artwork in the opportunity fallback painter, using the category accent with existing indigo and teal roles. It stays compact and must never communicate price, success, trust or urgency through color alone.
4. **Icon-tile tint:** shared cards and empty states resolve a supporting tint by product concept. Explicitly supplied colors are preserved; this avoids a purple-only UI without turning the app into a green-only theme.
4. **Brand exceptions:** retain the official multicolor Google G asset for Google sign-in. The Apple/Android device list uses neutral device glyphs while platform identity is carried in text.

## Color roles

- Surfaces: `#070A12`, `#0F111A`, `#111827`
- Primary interaction / selection: indigo `#6366F1` / `#818CF8`
- Peer identity accent: botanical green ramp; forest `#3E673F` in light mode and `#9FBF91` in dark mode
- Information: teal `#0F766E` / `#5EEAD4`
- Trust: blue ramp, retained independently
- Success: semantic green ramp, kept distinct from the botanical identity accent
- Featured: restrained orange/clay ramp
- Warning and error: semantic amber and red ramps

Green is restored as a frequent complementary identity hue beside indigo, not as a replacement theme. The compact navigation keeps an indigo selection plate with a green editorial rail; the desktop rail uses a green selected glyph while labels remain neutral. Kinetic state frames pair botanical green with teal and the owning state's semantic color. Amber/red/semantic-success colors remain meaning-driven rather than generic confetti.

## Components updated

- `HopeV2Icons`: canonical consumer-facing Cupertino glyph vocabulary.
- `HopeV2NavigationIcons`: five navigation outline/filled pairs.
- `HopeIcon` / `HopeIconTile`: shared rendering adapter; icon tiles resolve a restrained section/semantic accent by product concept, while explicit caller colors always win.
- `HopeV2IconAccents`: light/dark tint map for work/money-in (green), information/communication (teal), trust/identity (blue), featured content (clay), pending (amber), negative outcomes (red), and neutral actions (indigo).
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


## Card-density continuation — 2026-10-16

- Home loading placeholders now follow the compact viewport contract. Home opportunity grids use width-calculated tiles with natural content height rather than fixed-aspect cells. A regression test covers a 1024×1200 layout and prevents cards with short content from expanding into oversized square tiles.
- Explore uses content-sized two/three-column opportunity tiles while retaining full-width compact summaries on phones. The test previously reproduced a 509.30dp card against a 320dp budget; the corrected layout passes.
- Explore loading placeholders follow the content-width breakpoint: horizontal skeletons for phone-width compact summaries, compact-grid placeholders for two-column content, and standard placeholders where the loaded card is standard.
- Notification-device loading now mirrors the compact device row (platform tile, text rails, action placeholder), announces the loading state through a live region, and remains under the compact panel-height budget.
- Wallet's history transition uses viewport height as well as compact width: a short phone preserves every bit of first-fold space, while a taller compact screen retains 4dp separation before history.
- Static verification on exact HEAD `ae1a3434afe28d4a3f335266b162934b2598bc36`: [run 38918058048](https://github.com/amirdavodpour-stack/3/actions/runs/38918058048), **440 tests passed**. Runtime visual acceptance remains pending; its workflow was skipped and no screenshot was captured.


## Admin summary and operations metric cards — 2026-10-16

- The operations metric surface no longer forces backend values into fixed 82/96dp cells. Metric cards have width-responsive columns and natural content height; full values wrap and long labels stop using ellipsis when text scale exceeds 1.2.
- The main admin summary retains the existing compact aspect-ratio grid at default text scale. At enlarged text scale (>1.2), it switches to content-sized cards using the roomier stat presentation so labels and values are not squeezed into the compact one-line row.
- Regression evidence: at 390×844 and 1.5× text, the old admin summary tile was only **71.84dp** high and its internal column overflowed by **7.2dp**. The operations metric test also reproduced a 30-digit backend value overflowing a fixed-height card. Both regressions pass on the current source.
- Exact-HEAD Static PASS: [run 38920230225](https://github.com/amirdavodpour-stack/3/actions/runs/38920230225), SHA `d67f46720830438258d4199d1f284ee05c41c0db`, **442 tests passed**. Runtime evidence workflow [38920230858](https://github.com/amirdavodpour-stack/3/actions/runs/38920230858) was SKIPPED; no new runtime screenshot was taken, so visual/device acceptance remains pending.
