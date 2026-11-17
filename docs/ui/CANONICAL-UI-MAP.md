# HOPE Canonical UI Ownership Map

Status: ACTIVE — UI/UX orchestration baseline
Exact source baseline: `fca5fe65edd3264907dbb4491739852fca70a431`

## Product UI thesis

**Premium work instrument → opportunity → trust/state → economics → next action**

The product is not being redesigned from zero. Existing HOPE visual identity is retained; the work is to consolidate ownership and make observable behavior consistent.

## Canonical owners

| Capability | Canonical owner | Legacy overlap | Migration rule |
|---|---|---|---|
| Page shell | `PremiumPageFrame` | `HopeResponsive` / screen-local shells | New screens use PremiumPageFrame |
| Opportunity hero | `PremiumHero` | `GradientHero` | Migrate touched product surfaces first |
| Content panel | `PremiumPanel` | `HopeSurface` | New screens use PremiumPanel |
| Section header | `PremiumSectionHeader` | `SectionTitle` | Migrate touched screens |
| Tag / metadata | `PremiumTag` | `StatusPill` and ad-hoc chips | Prefer business-named variants |
| Search | `PremiumSearchBar` + `SearchField` owner | screen-local search | No new screen-local search primitive |
| Async state | `HopeAsyncState` | screen-local loading/error | State contracts live here plus owning content |
| Feedback | `HopeFeedback` | direct `ScaffoldMessenger` usage | New transient acknowledgements use HopeFeedback |
| Dialogs | app-owned dialog surfaces | raw `AlertDialog` in feature files | Standardize focus/actions before migration |
| Design tokens | `HopeV2Colors/Spacing/Radii/Motion` | raw visual literals | No new durable literals when token exists |

## Migration policy

1. Do not perform a big-bang UI rewrite.
2. New or touched screens must use the canonical owner when one exists.
3. Legacy primitives may remain only for consumers not yet migrated.
4. Do not add another overlapping primitive to solve a screen-local problem.
5. Any exception must document the information-architecture or interaction reason.
6. Runtime screenshot evidence is required for visual acceptance; source inspection alone is not visual certification.

## Current high-risk migration order

1. Auth: Login → Register → Password reset → Google Sign-In states
2. Marketplace: Home → Explore/Jobs → Job Detail → Create/Edit
3. Account: Profile → My Applications
4. Finance: Wallet → Transactions → Transaction Detail
5. Secondary: Notifications → Offers → Settings → About → Admin
6. Retire legacy aliases only after consumer migration is complete

## Verification

Use focused widget/interaction tests after the batch is implemented. Run the Flutter analyze/full suite as one aggregate gate rather than repeating the heavy suite for each micro-change. Runtime visual certification is a separate gate and requires rendered evidence.
