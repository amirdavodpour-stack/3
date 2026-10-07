# HOPE Design System 2.0 — Implementation Spec Sheet

## Visual thesis

**Discover · Execute · Trust**  
Persian tagline: «فرصت‌های بهتر، برای آدم‌های بهتر»  
Sub-tagline: «کار درست، درآمد امن، آینده روشن»  
English: **Intelligent Work · Trusted Money · Human Progress**

The app should feel like a high-trust work platform, not a generic dashboard. Use a dark navy base, indigo focus, restrained teal success, semantic amber only for real exceptions, and a bright white Google sign-in button. Hierarchy is task → amount/title → status/trust → metadata. The interface must remain legible at 360dp and text scale 2.0.

## Current shared source

- Theme/tokens: `lib/core/theme/hope_v2_design.dart`
- Theme facade: `lib/core/theme/app_theme.dart`
- Shared composition: `lib/core/ui/premium_components.dart`
- Opportunity card: `lib/core/ui/opportunity_card.dart`
- Formatting: `lib/core/ui/hope_display_formatters.dart`
- Localization: `lib/l10n/app_fa.arb`, `lib/l10n/app_en.arb`
- Contrast gate: `tool/contrast_check.py`, invoked by `tools/verify-design-quality.sh`

## Foundation rules

- Palette tokens are centralized; use semantic variants for accessible text/actions instead of assuming every accent color is readable on every surface.
- Body text requires 4.5:1 contrast. Essential icons/borders require 3:1. Inactive disabled controls are exempt from body-text contrast checks, but still need visible affordance.
- Font: Vazirmatn. Minimum meaningful text size 12sp. Body 16sp, secondary 14sp, section 18sp, title 22sp, display 28/32sp.
- Spacing: 4/8/12/16/20/24/32dp. Radii: 12/16/20/28dp.
- Every primary touch target is at least 48×48dp. Respect system reduce-motion.
- Use one card tap target; never add a redundant “view details” button inside an already tappable card.
- Money remains integer TOMAN; never scale down or ellipsize a financial amount. Wrap to two lines when needed.
- Consumer UI never displays internal database IDs, raw ISO timestamps, enum names, or ledger jargon.
- Listing cards use category-specific abstract art and employer identity, not a shared stock photo. Real opportunity media may appear on the detail page only when it is server-supplied and trustworthy.
- Category art is deterministic procedural geometry for this wave. Picsart preflight reported that one 1K image costs 3 credits while the connected account has 1; no generation was started or charged. Replace procedural art with optimized WebP assets only after an authorized credit budget is available.

## Layout sketches

### Home
Compact brand header + avatar + role mode. Pulse is a two-by-two grid below 420dp, four equal metrics above that width. “New” is derived from server timestamps within the last 24 hours; absent/invalid timestamps count as not-new. Escrow uses the actual escrow sub-balance, not total locked balance. Next action is one prioritized CTA; best match and opportunity list follow.

### Opportunity card
One consistent structure across hero/standard/compact densities. Category art is an abstract gradient + semantic icon, budget occupies its own line, no price ellipsis, at most three skill chips. Card tap is the single action.

### Wallet
Show total once. Rows for available, held in HOPE escrow, pending settlement, and lifetime earnings only when backend-backed. Escrow and payout reservation are breakdowns of locked funds, not extra total components. Hide deposit when `walletDeposit=false`.

### Engagement detail
One canonical status chip, a six-step timeline with the current step visibly filled, a “what happens next” explanation, role-specific actions and no raw payment IDs. A stable human reference remains a backend capability gap; the UI hides the internal ID rather than synthesizing one.

### Authentication
A 128dp compact hero with no redundant eyebrow/icon tile. Google sign-in uses the standard-colour G asset on a white outlined button. The form scrolls under keyboard and keeps its primary action reachable.

## Tool/design limitations recorded

- Figma is connected but the current seat is View-only; file creation/editing was not attempted. This SVG + Markdown spec is the repository-native fallback.
- Mobbin returned a paywall (“requires a paid plan”); no paid subscription was started.
- Picsart image preflight returned insufficient credits; no generation was run.
- Maestro is available as a repository workflow, but the connected Remote Desktop Commander device is offline and local Flutter/Maestro binaries are absent. Run verification through GitHub CI.
- NVIDIA BioNeMo, Swift Concurrency and FLOWSTACK UI are not directly applicable to the Flutter/Dart implementation; do not introduce unrelated dependencies merely to invoke them.
