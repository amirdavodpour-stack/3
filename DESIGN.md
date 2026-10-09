## Visual Wave 18 — Compact viewport calibration and first-fold recovery — 2026-10-09

Wave 17's Android artifact (runtime #2188 / run `37871022058`) contains 19 primary and six responsive Persian/RTL screenshots. Review of the original-size responsive Jobs and Profile captures found that the 720×1280 physical-pixel override was applied without a matching density override. On the Pixel 2 emulator's native density, that yields an approximately 274×488dp logical viewport; the screenshots consequently show inflated typography, clipped first-fold cards and an oversized empty band before the fixed navigation dock. This is a capture-calibration defect that also exposed a real compact-height spacing problem; it must not be mislabeled as a color-only issue.

### Grouped changes

- Calibrate the responsive Android capture to 720×1280 physical pixels at 320 dpi, i.e. 360×640 logical dp, and record physical/logical dimensions plus density in the artifact metadata.
- Restore both emulator physical size and density after the responsive batch to avoid leaking the test configuration into subsequent capture sessions.
- Make `PremiumPageFrame` cap its bottom safety tail at 40dp for short-height viewports and 20dp for very short viewports. The body already sits above the Scaffold dock; a fixed 96–112dp tail wastes the first fold on compact screens.
- Add a stable key to the frame padding and extend the existing single Flutter widget-test case with a 360×640dp scroll-viewport/padding contract.
- Add source guards for density calibration, restoration, metadata, and compact frame padding. Keep all business data and ledger semantics unchanged.

### Evidence and exit gate

- Input artifact: [Runtime #2188](https://github.com/amirdavodpour-stack/3/actions/runs/37871022058), artifact ID `11590562044`; all 25 PNGs were inspected, including full-size responsive Jobs and Profile images.
- The previous responsive artifact is not visually certified: its logical viewport was too small for the intended compact-phone comparison, and the first-fold composition is materially distorted.
- Run the consolidated Flutter test once on the final Wave 18 code, then run the static workflow. Only if both are green, trigger one Persian/RTL Android runtime capture. Do not close Wave 18 until all 25 new screenshots are individually inspected and the responsive screens show no clipped first-fold cards or artificial blank band.
- Keep PR #30 draft/unmerged and main untouched.

### References

- Flutter adaptive/responsive design: https://docs.flutter.dev/ui/adaptive-responsive
- Flutter logical-pixel sizing contract: https://api.flutter.dev/flutter/widgets/MediaQueryData/size.html

## Visual Wave 17 — Responsive viewport, navigation and financial clarity — 2026-10-09

Wave 17 is grounded in Android runtime workflow #2168 / run `37863924499` at exact feature HEAD `b69f3a87d94951018ac45d1124adec32d2d8468e`. The artifact contains 19 Persian/RTL primary images and six responsive images at physical resolution 720×1280. Its metadata records the PR merge ref as `30/merge` at merge SHA `5f1db15b7525246ec8d4f9e572008fb4b748ee48`; that merge ref is distinct from the exact feature HEAD checked out and rendered by the workflow.

### Evidence-driven findings
- In responsive Jobs and Transactions captures, the scrollable content ended well above the navigation dock, leaving a visually dead band. Opportunity Detail similarly showed content cut off well before its fixed primary action. This is consistent with the shared page frame allowing an inner scroll view to shrink-wrap instead of filling the available body viewport.
- On widths below 340 logical pixels, the five-tab dock forced 62dp minimum content into items narrower than that constraint; inactive Persian labels showed ellipses and Wallet's selected label was abbreviated.
- Wallet summary values explicitly used one line plus ellipsis, truncating available balance amounts. Work-centre labels had similar one-line constraints; opportunity budget range endpoints were also sent to the money label as one unformatted string.

### Wave 17 grouped implementation
- Make `PremiumPageFrame` constrain its inner page content to the available body height, without removing the shared opaque canvas, max-width centering, safe-bottom padding, or page semantics.
- Use an ultra-compact navigation variant below 340 logical pixels: selected destination retains its label (allowing two lines), inactive destinations retain accessible semantic labels while showing icons only, and the dock no longer imposes a 62dp minimum width on each of five items.
- Allow Wallet's labelled balance metrics and Work Centre summary text to wrap rather than discarding amount/status content behind ellipses.
- Give compact featured-opportunity budget values up to two lines, with responsive typography; localize and group each Opportunity Detail budget endpoint through the shared display formatter before joining the range.
- Extend the existing single-case Flutter widget test with narrow-width navigation and a measurable scroll-viewport-fill assertion; extend source guard and workflow markers for this wave.
- Preserve actual backend values and existing TOMAN semantics. Do not add synthetic records or alter authorization, ledger lifecycle, payment state, route behavior, media provenance, or AI policy.

### Wave 17 acceptance sequence
- Keep the runtime-trigger marker off while implementation and static validation run.
- Run the one focused Flutter test on the exact new feature HEAD; only after it is green, set `[runtime-capture-fa]` and `[wave17-preverified]` together to initiate one runtime capture without running that focused test twice.
- Inspect all 25 PNGs from the new artifact before calling the wave visually certified. Keep PR #30 draft and unmerged; main remains untouched.
- Flutter's adaptive layout guidance distinguishes app-window size from local widget constraints and recommends selecting layouts from available space. Sources: https://docs.flutter.dev/ui/adaptive-responsive/general and https://docs.flutter.dev/ui/adaptive-responsive/best-practices.


## Visual Wave 16 — Responsive density and empty-state convergence — 2026-10-09

Wave 16 is grounded in the final Wave 15 exact-head runtime artifact from workflow #2155 / run `37861305993`, containing 19 Persian/RTL primary screenshots and six responsive screenshots at 720×1280. The run completed successfully and its artifact was inspected as a 25-image contact-sheet set before implementation. Main observations: the discovery and finance surfaces use noticeably different vertical densities; some compact opportunity metadata is vulnerable to single-line truncation; and empty/error-first screens (chat, notifications, saved searches, applications, and Home discovery) do not share a consistent visual hierarchy. Screenshot evidence alone cannot establish whether low data density reflects a valid backend-empty state or a capture fixture; therefore this wave does not add synthetic records.

### Wave 16 grouped implementation
- Introduce a reusable `PremiumEmptyState` with bounded copy width, semantic container, responsive spacing, restrained icon treatment, and optional real action.
- Apply the shared state to saved searches, application history, notifications, first-message chat state, and Home discovery with no matching opportunities.
- Allow compact opportunity budget metadata to wrap onto a second line rather than losing the financial range to single-line ellipsis.
- Reduce narrow header truncation risk with a slightly smaller compact display size and a third title line.
- Give two- and three-column Home opportunity grids more vertical room for title and metadata; do not force compact single-column layouts into a grid.
- Extend the existing single Flutter widget test case to verify the responsive empty-state contract at a narrow 320 logical-pixel viewport alongside Wave 15 decision/card assertions.
- Extend the source guard to lock the cross-screen empty-state and responsive metadata contracts.

### Wave 16 verification contract
- One Flutter test invocation for the complete visual wave; the existing single test case now includes the shared empty-state rendering at 320 logical pixels.
- Only after that gate is green, trigger exactly one Persian/RTL runtime screenshot workflow and inspect all 25 screenshots from its new artifact.
- Keep the PR draft and unmerged; do not alter main or claim visual certification until the new artifact is inspected.
- Keep real backend data/media only, Persian-first RTL with correct LTR islands, existing design tokens, and touch targets at least 48 dp.
- Official responsive/accessibility basis reviewed through Exa: Flutter's adaptive/responsive guidance recommends layout decisions from available constraints rather than device identity/orientation; Flutter accessibility guidance calls for adequate contrast, scalable text, and minimum 48×48 dp touch targets. Sources: https://docs.flutter.dev/ui/adaptive-responsive/best-practices and https://docs.flutter.dev/ui/accessibility/ui-design-and-styling.

## Visual Wave 15 — Runtime #2148 Evidence-Driven Decision Clarity — 2026-10-09

Wave 15 is grounded in the exact artifact from Runtime #2148 / workflow run `37847636651`, containing 19 primary Persian/RTL screenshots and six 720×1280 responsive screenshots. The artifact metadata identifies the captured PR merge ref as `30/merge` at merge SHA `a1b8d8f491cc95067cc870f541f9f4e945dd00f1`; the feature branch HEAD at audit time is `40293a6632a6a11efcd384b5e82d3e62f4ee590a`. Do not conflate those identifiers. The screenshot matrix confirms a real interpolation defect in Opportunity Detail, back-navigation overlap on the hero, cramped featured-opportunity budget wrapping, redundant match context, and a weak first-fold priority order in the wallet.

### Wave 15 grouped implementation
- Repair actual Dart interpolation in the shared opportunity decision strip so match score and component percentages render numeric values instead of raw template expressions.
- Keep one canonical match score: Opportunity Detail's decision strip owns score/breakdown; Opportunity DNA continues to present only distinct real traits.
- Recompose Opportunity Detail's hero at compact/medium widths, move the back affordance away from RTL title/eyebrow content, and preserve the fixed primary action and scroll behavior.
- Give featured opportunity budgets their own line at narrow widths and use safe two-line truncation rather than clipping numeric financial content.
- Remove the duplicate Home hero-to-feed spacer so the first discovery section arrives sooner.
- Put the actual wallet balance and four ledger-state metrics before secondary wallet actions on narrow layouts.
- Add one single-case Flutter gate that exercises rendered score interpolation, compact Hero composition, duplicate-score suppression, and featured-card overflow; keep source guards for the remaining screenshot-specific contracts.

### Wave 15 guardrails
- Real backend data/media only; no synthetic records, filler, or generated imagery in product surfaces.
- Persian-first RTL, correct LTR islands, Vazirmatn-first.
- Tappable targets remain at least 48px.
- Existing HOPE tokens/components only; no new dependency.
- Internal TOMAN ledger, authorization/admin boundaries, job/payment lifecycle and AI policy unchanged.
- Main untouched; PR #30 remains OPEN/DRAFT/UNMERGED.
- Do not weaken renderer, timeout, screenshot transport, or capture validation.
- One focused command: `flutter test --no-pub test/core/ui/premium_visual_wave_15_test.dart` (one grouped widget test). The static workflow runs it before the `[wave15-preverified]` marker is added; after it passes, the exact-head Runtime capture skips only this duplicate gate and captures the full 25-PNG matrix.

### Wave 15 closure rule
Source changes alone do not close the wave. The single Wave 15 Flutter test must pass on the exact feature HEAD, then one exact-head Runtime must produce all 25 PNGs, and all screenshots must be inspected before T10 can be accepted. The preverified marker is added only after the test passes; it prevents duplicate Flutter execution in the Runtime workflow without bypassing the test result.

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


## Visual Wave 7 — 2026-10-08

Wave 7 is the consolidated editorial-density pass after the exact-head 25-screen Runtime #2076 inspection. The artifact is green and complete; the screenshots show that the remaining drift is systemic rather than route-specific: standard opportunity rows still read as nested cards, support metrics compete with focal decisions, tags/status markers are too boxed, and secondary quick actions consume too much visual surface area.

### Wave 7 implementation contract
- **Focal tier:** featured opportunity media, primary decision CTA, wallet total, lifecycle/status decision.
- **Decision/state tier:** compact state strips and one primary command row.
- **Quiet tier:** standard opportunity rows, support metrics, secondary destinations, repeated metadata.
- **Utility tier:** filters, history, secondary account/work links.
- Standard opportunity cards are now editorial rows without an outer card shell; featured/scan variants retain their stronger containment.
- Standard opportunity media grows modestly on mobile/compact layouts to strengthen the real-work image anchor.
- Non-highlight stat cards become quiet by default; highlighted stats retain explicit containment.
- Quick-action secondary controls lose container chrome; the primary action remains filled.
- Domain navigation groups and tags become quieter, with transparent borders and lighter fills.
- Default premium panels retain their semantics and spacing but use less border/shadow weight; highlighted panels remain the only elevated shared tier.

### Screenshot acceptance target for Wave 7
The next runtime should visibly show fewer competing rectangles, stronger opportunity/media hierarchy, a quieter finance/work history, and a more editorial first fold while preserving all existing business semantics, RTL/LTR structure, 48dp targets, and exact 25-screen runtime coverage.


## Visual Wave 8 — 2026-10-08

Wave 8 is the second large consolidation pass after Runtime #2080. The screenshots confirm Wave 7 successfully removed most outer shells from standard opportunity rows and improved finance hierarchy, but the shell still dominates the composition: the selected mobile navigation cell is oversized, sparse work-center/profile surfaces waste vertical space, and the Home/Explore first fold carries too much inter-section breathing room.

### Wave 8 implementation contract
- Mobile navigation remains a full-width 48dp interaction target but renders its selected state as a compact centered capsule; the dock itself is reduced from 76dp to 68dp.
- Section headers use a tighter title/subtitle rhythm so page identity remains strong without pushing primary content below the fold.
- Home support sections use tighter spacing after the featured opportunity; the featured surface remains the dominant focal tier.
- Work Center compresses sparse state groups and reduces shell padding; status strips remain the primary state cue.
- Profile settings become a quiet structural group; trust and work-center destinations retain explicit hierarchy.
- Explore results tighten inter-card/list rhythm while preserving the larger standard opportunity media anchor introduced in Wave 7.
- No business semantics, data contracts, RTL behavior, or interaction target sizes change.


## Visual Wave 9 — 2026-10-08 — Tenfold Composition Convergence

Runtime #2080 is the rendered baseline for this wave: all 25 FA/RTL screenshots completed and artifact validation passed. The cross-screen review found the same systemic issue in multiple domains—strong focal surfaces are effective, but headers, metadata, secondary panels, lifecycle blocks, and utility controls still consume too much visual attention.

### Aggregated scope
- tighter mobile editorial headers and section subtitles;
- smaller-radius, lower-chrome default panels while highlighted surfaces retain elevation;
- shorter and quieter mobile navigation dock;
- compact product-owned search and filter controls;
- annotation-grade tags and status pills;
- compressed lifecycle cadence and connectors;
- stronger real-media opportunity anchors with quieter standard rows;
- Home pulse rendered as an unboxed support rail;
- opportunity intelligence/traits/facts/lifecycle subordinated to the hero and decision;
- flatter profile settings and shorter authentication hero surfaces;
- finance/work surfaces inheriting the same focal → decision → quiet → utility hierarchy;
- one focused Flutter gate for the grouped wave, followed by one exact-head 25-PNG runtime capture.

### Closure rule
The wave is not considered complete from source inspection alone. Closure requires the focused Flutter gate to pass, the exact-head runtime to finish with the complete 25-PNG artifact, and the complete matrix to be visually inspected before opening the next visual correction wave.


## Visual Wave 10 — 2026-10-08 — Cross-screen rhythm and quiet-surface convergence

Wave 10 is grounded in the exact-head 25-PNG artifact from Runtime #2126 (19 primary FA/RTL screens plus six 720×1280 responsive views). The rendered evidence shows the strongest remaining drift is composition-level: the opportunity hero and wallet balance establish a clear focal tier, while secondary panels and inter-section gaps still compete; low-count utility lists leave too much visual chrome around sparse content; Job Detail has an uneven vertical reading path at responsive size; Profile, Saved Searches, Transactions, and Offers need a more consistent compact cadence.

### Aggregated implementation
- reduce default and highlighted panel border contrast without weakening primary focus surfaces;
- compress the first four Home feed transitions while preserving later-section breathing room;
- tighten Job Detail secondary panel padding and vertical section gaps around the focal opportunity and primary action;
- reduce Profile identity/section spacing without adding synthetic profile content;
- compact Saved Searches shell, sparse result panel, and section rhythm;
- unify transaction page shell insets and secondary section gaps;
- tighten Offers page shell and section transitions;
- preserve the 68dp navigation dock, 48dp minimum targets, Persian-first RTL, real data/media, wallet/job semantics, and all auth/admin controls.

### Validation contract
One focused Flutter gate for this entire grouped wave. Only if that gate passes, perform one exact-head Android runtime capture with the complete 25-PNG matrix. No parallel runtime, no second Flutter run, and no visual acceptance until the resulting PNGs are inspected. Main remains untouched.

## Wave 11 — Runtime #2132 screenshot-driven composition convergence

**Evidence input:** Runtime #2132 / artifact `11572094459` on exact feature HEAD `e3507ac9b3189d4454b48469e26b21ce6f760a21`; 25 Persian/RTL PNGs (19 primary + 6 responsive 720×1280). The contact sheet and screen-by-screen evidence matrix define this wave; runtime re-certification remains pending until the grouped implementation passes its single focused Flutter gate.

**Confirmed visual priorities:**
- Give secondary/quiet surfaces enough tonal separation to read as intentional groups without restoring heavy borders or shadows.
- Make muted labels, lifecycle nodes, payment details, and section subtitles readable on dark navy surfaces.
- Keep Opportunity Detail media editorial but rebalance the first-fold order to hero → match signal → real budget/location facts → Opportunity DNA → description → operational details.
- Make the four wallet sub-balances legible as distinct values while preserving internal TOMAN/escrow semantics.
- Strengthen candidate-match score as the focal comparison metric and replace default Material chips with the HOPE tag primitive.
- Reduce the mobile gap between financial summary and the trend section without compressing chart legibility.
- Keep sparse states sparse; do not invent jobs, reviews, messages, transactions, or profile credentials to fill canvas space.

**Guardrails:** Persian-first RTL with correct LTR islands, Vazirmatn, dark navy/indigo identity, 48dp targets, real backend data/media only, no page-wide photography, no user-facing AI chat, admin access restrictions, and the internal TOMAN ledger/job lifecycle remain unchanged.

**Verification:** one `flutter test --no-pub test/core/ui/premium_target_density_test.dart` command for the full wave. If green, exactly one serialized exact-HEAD Runtime capture; inspect all 25 screenshots before T10 acceptance. Do not run parallel captures or treat a green workflow as visual acceptance.


## Wave 12 — Product Signature + First Fold — implementation checkpoint

**Implementation target:** Runtime #37832916891 / artifact `11575520191` on exact HEAD `197703288c913a8fa43b4d1b300cf31ee6fbe884`.

**Visual findings carried into this wave:** compact Home/Jobs featured opportunities leave excessive dead space while decision content is visually fragmented; Opportunity Detail spends too much first-fold height on hero/match before key facts; Candidate Comparison lacks real component-level comparison; Create Opportunity hides Live Preview and has no persistent five-step visual map; Profile puts professional trust signals below settings; Wallet pushes actions below a large balance hero; Work Center leaves useful quick destinations outside the first fold.

**Wave 12 grouped scope:** Opportunity Card compact/featured convergence; Opportunity Detail decision strip + DNA order; Candidate Comparison real component bars; Create Opportunity five-step progress + visible Live Preview; Wallet first-fold command rail + existing internal ledger-flow signature; Transactions first-fold quick access; Profile professional first-fold trust rail; shared HOPE primitives for decision/progress/trust composition.

**Guardrails:** no invented content; real backend data/media only; Persian-first RTL and correct LTR islands; Vazirmatn; 48dp targets; no user-facing AI chat; admin authorization remains unchanged; internal TOMAN ledger semantics and job/payment lifecycle remain unchanged; Main untouched.

**Verification contract:** one focused Flutter test command for the entire wave — `flutter test --no-pub test/core/ui/premium_target_density_test.dart`. Only after it passes, one serialized exact-head Runtime with the complete 25-PNG matrix. No parallel capture and no T10 acceptance until every PNG is inspected.


## Wave 13 — Signature Density + First Fold Convergence — 2026-10-08

Wave 13 is driven by the complete exact-head Runtime #37837703135 / artifact `11576343079`. The 25 rendered screens show strong HOPE identity but continued first-fold inefficiency: the mobile payment lifecycle is too tall, Opportunity Detail allocates too much vertical budget to hero/match blocks, responsive Wallet keeps too much type/metric height, Financial Insights repeats nested boxes, Create Opportunity burns large section gaps, Candidate Comparison over-contains supporting content, and Profile settings remain visually heavy.

### Research synthesis used for this wave
- Canva HOPE UI Audit Board: first view prioritizes opportunity discovery; image is the focal cue; price + city remain visible; one clear primary action; 48px interaction targets; responsive width-based layout and RTL validation.
- Material 3 / Firecrawl: cards should be easy to scan and are allowed to change composition by layout width; not every grouping needs a card when dividers/spacing communicate hierarchy better.
- Flutter adaptive guidance / Parallel Search: layout should respond to available window size and preserve touch-first interaction; avoid fixed device assumptions.
- WCAG 2.2 / Exa: maintain readable contrast and accessible target sizing.
- Color Designer + AI Color Picker: preserve the existing near-black/navy + indigo family; strengthen hierarchy by reducing container noise, not by inventing a new palette.
- Figma access is available, but no canonical file/node URL is registered in Notion, so no unverified Figma file was treated as visual truth. Mobbin was attempted but requires an unavailable paid plan; Miro brand context is still staged/unavailable; MyFonts pairing search is unsupported.

### Implementation scope
- shared compact `HopeLifecycleRail`;
- mobile transaction/payment lifecycle compression;
- responsive Opportunity Detail hero + match cadence and compact bars;
- responsive Wallet density at sub-800dp windows;
- quieter Financial Insights metrics;
- tighter Create Opportunity section cadence;
- quieter, shorter Candidate Comparison rows;
- flatter Profile settings container;
- focused test coverage for the shared lifecycle primitive.

### Guardrails
Real data/media only; Persian-first RTL; correct LTR islands; Vazirmatn; 48dp targets; no user-facing AI; admin visibility and owner authorization unchanged; internal TOMAN ledger/job-payment semantics unchanged; Main untouched.

### Verification
One focused Flutter gate for the grouped wave, followed only if green by one serialized exact-head Android Runtime with the complete 25-PNG matrix. No T10 acceptance from green CI alone; every new PNG must be inspected.
