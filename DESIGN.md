# HOPE Design System — Durable Visual Context

## Product
HOPE is a Persian-first, bilingual work marketplace connecting people who post opportunities with people who perform them. The product combines marketplace discovery, active work lifecycle, wallet/transactions, notifications, profile, and operational/admin surfaces.

## Audience and design job
Primary audience: mobile-first users who need to understand an opportunity, its economics, trust/state, and next action quickly.
Primary design job: reduce decision friction without turning the marketplace into a generic job-board dashboard.

### Premium reference target — HOPE Futuristic Work Platform UI Showcase
The target visual language is a dark, high-density work platform: near-black navy surfaces, indigo/violet primary, emerald trust/success, amber warning, restrained red danger, compact rounded cards, thin borders, strong metric/state hierarchy, controlled glow, and deliberate mobile bottom navigation / desktop rail behavior. This is a system reference, not a pixel-copy mandate. Product behavior, backend contracts, wallet/ledger semantics and real data remain authoritative. Opportunity/hero imagery is screen-level, not a page-wide background.

## Visual direction
HOPE should feel like a **premium work instrument** rather than a generic SaaS dashboard:
- dark-first, high-contrast layered surfaces for the default product experience;
- light mode remains supported as an explicit user-selected alternative;
- confident violet as the primary brand signal;
- restrained teal for positive/secondary actions;
- warm amber for caution/attention;
- generous but disciplined spacing;
- rounded surfaces used as functional grouping, not decoration;
- Persian typography treated as a first-class product asset;
- motion is short and purposeful.

Avoid generic AI-dashboard patterns: excessive gradients, decorative statistics, gratuitous glassmorphism, dense card grids, and ornamental numbered sections.

## Canonical tokens

### Color
- Primary: `#6C4DFF`
- Primary dark-mode: `#B3A2FF`
- Secondary: `#22B8A7`
- Secondary strong/light-mode accessible teal: `#0C7D70`
- Accent/warning: `#FFB45C`
- Ink: `#151326`
- Muted text: `#6B6780`
- Light page: `#F7F7FB`
- Light panel: `#FFFFFF`
- Dark page: `#090811`
- Dark panel: `#15131D`
- Dark card: `#1C1925`
- Success: `#0B7A58`
- Danger: `#BA454D`

Runtime ownership: `lib/core/theme/hope_v2_design.dart` is the canonical token source; `app_theme.dart` is the Material compatibility/theme adapter. Shared surface mappings (input, chip, navigation, divider, control border) must resolve through this source rather than new screen-local literals.

## Typography
- Runtime font: Vazirmatn.
- Display: heavy, compact, restrained negative tracking.
- Body: readable Persian-first line height.
- Utility/eyebrow: small, high-weight labels for state/category context.
- Never encode hierarchy by font size alone; pair type with spacing and semantic structure.

## Spacing and geometry
- Base spacing: 4 / 8 / 12 / 16 / 24 / 32 / 40 / 56.
- Radii: 12 / 16 / 22 / 28 / 32, with pill only for tags/chips.
- Interactive minimum: 48px.
- Breakpoints: compact <600, medium 600–899, expanded >=900, wide >=1200.

## Signature element
The HOPE signature is the **opportunity-to-action surface**: a strong contextual hero or opportunity card followed by explicit discovery/action controls. Financial information must remain visually subordinate to the user's immediate work decision unless the current task is finance.
- Intentional shared hero gradient styling is owned by `HopeV2Gradients.hero`; it is a component variant, not a page-background default.

## Responsive rules
- Mobile is the primary composition, not a compressed desktop.
- RTL and LTR must preserve hierarchy and interaction semantics.
- Desktop may introduce navigation rail and wider content, but must not invent a separate product language.
- Avoid fixed-height page shells that trap document scrolling.

## State rules
Every meaningful async surface must have deliberate loading, empty, error/retry, and success states. Preserve stale usable data when safe while surfacing refresh failure.
Buttons retain geometry while busy.
Destructive actions use explicit app-owned confirmation.

## Accessibility
Target WCAG 2.2 AA.
- Native semantics first.
- Visible keyboard focus.
- 48px minimum interactive targets.
- Do not communicate state by color alone.
- Respect reduced motion.
- Preserve user text scaling; fix responsive overflow at the component level.

## Localization
Persian (fa) is the primary design language; English (en) must remain structurally equivalent.
- No hard-coded user-facing copy when a localization key is appropriate.
- Directionality must be derived from locale.
- Labels, errors, empty states, dates, numbers, and accessibility names must follow locale.

## Component ownership
Prefer shared primitives in `lib/core/ui/` and theme tokens over screen-local styling.
Business-named variants are preferred over one-off conditional visual forks.

## Change discipline
A durable visual change must update this document and the runtime token/component source in the same changeset.
Do not redesign a screen merely to make it different from a sibling. Improve the canonical system or document an intentional business variant.