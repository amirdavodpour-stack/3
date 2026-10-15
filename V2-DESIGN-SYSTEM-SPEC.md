# HOPE V2 Design System Specification — Premium Max

## Product language

The product uses Persian-first RTL presentation for customer and worker experiences. Currency is displayed as `تومان`; the internal ledger uses one integer unit per displayed تومان and never introduces an exchange rate inside the product.

## Visual foundation

- Material 3 composition with a restrained premium fintech visual language.
- Default product presentation is dark-first; light mode remains explicitly supported.
- Consistent spacing scale, corner radii, typography hierarchy, icon sizing, and elevation across feature surfaces.
- Primary information is grouped into cards and sections; destructive actions are visually distinct and require an explicit confirmation state.
- Avoid layout assumptions tied to a single handset width. Screens must remain usable in narrow, large, and text-expanded configurations.

### Color genome

- **Dark foundation:** near-black navy `#070A12`; surface `#0F111A`; card `#111827`; raised panels `#101522` and `#121726`. Dark mode must read as charcoal/navy, not as a green-tinted canvas.
- **Brand action:** indigo is the primary action and selection family (`#6366F1` light identity, `#4F46E5` light action, `#818CF8` dark action). Use it for selected controls and focused actions, not as a body-text color.
- **Semantic roles remain independent:** teal for information/secondary actions, green for success, amber for warning/pending, orange for featured/recommended content, blue for trust/verification, and red for danger.
- **Forest and lichen remain supporting decorative/category accents.** They must not replace the global action color, neutral surfaces, or semantic colors. Opportunity artwork may use a muted, distinct category accent.
- Light mode keeps its warm editorial-paper surface family. All foreground/background pairings must pass the applicable WCAG contrast contract.

## Interaction states

Every asynchronous feature surface should define loading, success, empty, error, retry, disabled, and permission-denied states where applicable. Long-running financial operations must expose an operation state that is stable across refresh and navigation.

## RTL and localization

All user-facing strings must come from localization resources. Layout direction is derived from the active locale rather than hardcoded widget coordinates. Dates, numbers, and monetary values use locale-aware formatting while preserving the canonical internal amount.

## Financial UI rules

Wallet, transaction, payment-hold, refund, release, and payout surfaces must distinguish available balance, held funds, pending operations, and terminal history. A transaction identifier and operation state should remain observable after a retry. User-visible money labels should use تومان consistently.

## Accessibility and resilience

Interactive controls must have a readable focus/semantic label, sufficient hit area, and a meaningful disabled state. Network failures must not erase locally known transaction state. Empty states must explain what the user can do next rather than presenting a blank surface.

## Implementation contract

The design system is an implementation constraint, not a visual suggestion. New screens should reuse existing premium components and tokens before introducing one-off styling. Any exception must be justified by a documented interaction or information-architecture requirement.