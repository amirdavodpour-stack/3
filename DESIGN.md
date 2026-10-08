# HOPE Design System — Durable Visual Context

## Product
HOPE is a Persian-first, bilingual work marketplace connecting people who post opportunities with people who perform them. The product combines marketplace discovery, active work lifecycle, wallet/transactions, notifications, profile, and operational/admin surfaces.

## Audience and design job
Primary audience: mobile-first users who need to understand an opportunity, its economics, trust/state, and next action quickly.
Primary design job: reduce decision friction without turning the marketplace into a generic job-board dashboard.

### Premium reference target — HOPE Futuristic Work Platform UI Showcase
The target visual language is a dark, high-density work platform: near-black navy surfaces, indigo/violet primary, emerald trust/success, amber warning, restrained red danger, compact rounded cards, thin borders, strong metric/state hierarchy, controlled glow, and deliberate mobile bottom navigation / desktop rail behavior. This is a system reference, not a pixel-copy mandate. Product behavior, backend contracts, wallet/ledger semantics and real data remain authoritative. Opportunity/hero imagery is screen-level, not a page-wide background.

### Visual calibration — HOPE Futuristic Work Platform UI Showcase
The supplied showcase is the calibration target for the reconstruction. Match its information density, dark layered surfaces, compact card geometry, strong numeric/state hierarchy, controlled violet glow, emerald trust signals, and mobile bottom-navigation rhythm. Preserve HOPE-specific copy, Persian-first RTL behavior, real marketplace/ledger data, permissions, and lifecycle semantics. Use imagery only inside opportunity/hero surfaces where product data supports it; never use a page-wide photographic background.

## Visual direction
HOPE should feel like a **premium work instrument** rather than a generic SaaS dashboard:
- dark-first, high-contrast layered surfaces for the default product experience;
- light mode remains supported as an explicit user-selected alternative;
- confident violet as the primary brand signal;
- restrained teal for positive/secondary actions;
- focused orange for featured/recommended opportunity signals, used as a small visual counterpoint to violet;
- navigation icons use a restrained, product-specific vocabulary: dashboard for home, workspaces for Workshop, insights for Activity, wallet for finance, and person for identity; avoid literal/tool-like icons where a broader product concept is intended;
- warm amber for caution/attention;
- generous but disciplined spacing;
- rounded surfaces used as functional grouping, not decoration;
- Persian typography treated as a first-class product asset;
- motion is short and purposeful.

Avoid generic AI-dashboard patterns: excessive gradients, decorative statistics, gratuitous glassmorphism, dense card grids, and ornamental numbered sections.

## Canonical tokens

### Color
- Primary: `#6366F1`
- Primary dark-mode: `#818CF8`
- Secondary: `#22D3EE`
- Secondary strong: `#06B6D4`
- Accent/warning: `#FFB45C`
- Featured signal orange: `#F97316` (dark: `#FF9A4D`); reserved for recommendation/attention emphasis, not primary actions
- Ink: `#151326`
- Muted text: `#6B6780`
- Light page: `#F1EDF8` with a restrained warm atmospheric halo; brown is never used as a surface color.
- Light panel: `#FFFFFF`
- Dark page: `#070A12` with cool navy/violet layers; no warm-brown page surfaces.
- Dark panel: `#0F111A`
- Dark card: `#111827`
- Success: `#10B981`
- Danger: `#EF4444`

Runtime ownership: `lib/core/theme/hope_v2_design.dart` is the canonical token source; `app_theme.dart` is the Material compatibility/theme adapter. Shared surface mappings (input, chip, navigation, divider, control border) must resolve through this source rather than new screen-local literals.

## Typography
- Runtime font: Vazirmatn.
- Display: heavy, compact, restrained negative tracking.
- Body: readable Persian-first line height.
- Utility/eyebrow: small, high-weight labels for state/category context.
- Never encode hierarchy by font size alone; pair type with spacing and semantic structure.

## Spacing and geometry
- Base spacing: 4 / 8 / 12 / 16 / 24 / 32 / 40 / 56.
- Radii: 12 / 16 / 18 / 24 / 28, with pill only for tags/chips; hero surfaces use 28.
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
- On normal mobile widths, the Home HOPE Pulse uses four compact metric cells in one row; it collapses to two columns only when the inner Pulse width falls below 300px to preserve readability on very narrow layouts.
- On mobile Home, opportunity creation remains available as an icon-only floating action so the primary featured opportunity surface is not visually obscured by an extended control.

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

### Icon language

Navigation and recurring product icons use a restrained, product-specific vocabulary: dashboard-customize for Home, hub for Workshop, timeline for Activity, wallet for finance, and manage-account for identity; opportunity, matching, protected-funds, payment, and lifecycle states use a dedicated HOPE icon vocabulary rather than ad-hoc Material defaults;


## Runtime calibration checkpoint — 2026-09-27
The current feature implementation has been recalibrated to the supplied HOPE Futuristic Work Platform UI Showcase: indigo primary, cool dark surfaces, tighter shared geometry, and stronger identity/featured-opportunity hierarchy. The next gate is rendered Android evidence at this exact feature HEAD; visual acceptance remains closed until actual PNG pixels are inspected.
- Recommendation cards surface the real match score when the domain payload provides it; absent fields are not synthesized.

## Reference synthesis — 2026-09-24
The premium reconstruction borrows principles, not assets or copied screens:
- Nuri / Vivid-style visual language: lavender-led atmospheric canvas, compact hierarchy, restrained gradients.
- NuDS-style system discipline: semantic tokens as the single visual source of truth.
- Paychain / OrbitPay-style finance patterns: dense but legible state/value hierarchy and purpose-built wallet navigation.
- HOPE-specific rule: warm brown is an underlay accent only; the product surface remains lavender in light mode and cool navy/violet in dark mode.
- Expressive glow is concentrated in hero/opportunity surfaces rather than applied across every card or the whole page.


## Visual Wave 3 — 2026-10-08

Wave 3 is the larger composition and hierarchy convergence pass. It is informed by the exact-head rendered evidence from Run #1971 plus current marketplace/fintech UX research: marketplace cards benefit from high-signal information hierarchy with fewer containers, while financial interfaces should make balance, recent activity, amount, status, and recovery legible without hiding critical state behind navigation. The implementation therefore changes shared primitives and several flagship surfaces together rather than adding isolated screen chrome.

Scope: flat command-style quick actions; genuinely quiet secondary panels; product-owned search field chrome; ledger-style wallet submetrics with a single focal balance; compact wallet command rail; flat work-center metrics; lifecycle/payment summaries treated as sub-sections rather than cards-within-cards; and Home ordering of opportunity → active work → lightweight pulse → secondary destinations.

The design objective is **density without dashboard sameness**: fewer competing rectangles, stronger primary decisions, clearer state/value hierarchy, and reusable system behavior across marketplace, work, and finance surfaces.

## Visual Wave 2 — 2026-10-08

The next grouped visual wave is driven by Run #1971 / exact-head screenshot review. The dominant drift is systemic: too many similarly-weighted containers, low-salience navigation selection, tiny metadata/tag typography, and decorative fallback media competing with real opportunity imagery. Wave 2 therefore updates the shared visual system rather than patching one screen: opaque layered panels with quieter shadows, a clearer floating mobile dock with a contained active state, stronger compact editorial header scale, more legible tags, disciplined domain markers, and restrained category fallback media. Home Pulse is intentionally demoted to a quiet support rail so the featured opportunity remains the primary work decision. Real media remains preferred whenever payload data supplies it.

## Runtime visual acceptance observations — 2026-10-03

Run #1339 at exact feature HEAD `966e7c0356ccfbc140ae6cd17d86d61e51322fb1` completed successfully and its rendered Android artifact was inspected. The remaining visual work is compositional rather than runtime plumbing: Home was competing across intelligence/finance/quick-access surfaces; Explore spent too much first-viewport height on filter controls; featured opportunities needed a stronger image-led anchor.

This calibration keeps the domain contracts and moves the hierarchy toward matched opportunity first, active next action second, intelligence follow-up after the work signal; compact responsive refinement controls; stronger featured imagery/hero proportions; and opaque layered product surfaces instead of decorative glass. Backend semantics, authorization gates, and Main-branch state remain unchanged.


## Visual Wave 5 — 2026-10-08

The next grouped visual pass follows the inspected 25-screen FA/RTL runtime matrix. It tightens the first-fold rhythm on Home and shared headers, reduces unnecessary chrome around shared opportunity cards without changing the certified featured-media focal height, preserves the wallet balance as the finance focal point while tightening its surrounding rhythm, and explicitly darkens the Android system navigation area to match the near-black HOPE canvas instead of producing a pale band below the mobile dock.

This wave is presentation-only: no ranking, recommendation, auth, permissions, wallet/ledger values, payment lifecycle, API contract, or AI exposure changes. The exact-head Flutter suite is the single static gate; only after it is green should one full FA/RTL runtime capture be requested and its actual PNGs inspected.


## Wave 6 — Surface Hierarchy + Decision Spine (2026-10-08)

Wave 6 is a composition-level visual pass driven by Runtime #2020. Default surfaces become quieter while focal opportunity media and highlighted surfaces retain visual priority. The pass preserves business logic, RTL/LTR behavior, semantics, and 48dp interaction targets.

### Evidence-driven scope
- Runtime #2020 produced the complete critical/responsive artifact set and passed artifact validation.
- Home and featured opportunity media are strong focal anchors; repeated panels still compete with them.
- Jobs, transactions and wallet retain too much chrome for repeated content.
- Profile and utility states leave large quiet areas while secondary containers still carry visual weight.

### Wave 6 implementation
- Flatten default PremiumPanel chrome.
- Quiet PremiumTag/status chips.
- Tighten standard OpportunityCard containment and remove non-featured shadow competition.
- Give standard opportunity media a slightly stronger focal footprint while preserving the featured mobile media contract.
- Preserve highlighted/featured surfaces as the highest visual tier.

### Composition rule
Focal surface → decision/state strip → quiet rows → utility.

### Verification
One grouped Flutter gate, then one runtime capture if green. Actual PNGs remain the authority for the next correction wave. Main remains untouched.
