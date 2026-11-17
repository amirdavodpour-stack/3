# HOPE UX Contract

## Scope
This contract defines observable behavior for the multi-screen HOPE Flutter application. Backend/domain contracts remain authoritative for permissions, money, lifecycle transitions, and security.

## Canonical shell
- Mobile: bottom navigation for Home, Explore, Activity, Wallet, Profile.
- Expanded layouts: navigation rail with the same destinations.
- Primary create/post action remains reachable from Home.
- Guest users may browse; authenticated-only actions route to authentication without losing the user's context where technically safe.

## Core workflow model
For every mutation:
operation → trigger → pending → success destination → success feedback → failure recovery.

Equivalent operations must use the same labels, busy treatment, feedback, and navigation outcome across screens unless the business workflow differs.

## Home
Home composition:
1. identity/context;
2. relevant work state;
3. opportunity discovery;
4. activity;
5. finance snapshot;
6. primary action.

Home must remain useful to guests without exposing private financial or personal work data.

## Marketplace
- Search/filter controls remain discoverable and keyboard/touch accessible.
- Remote search is debounced and stale responses cannot overwrite newer queries.
- Results have explicit loading, empty, no-results, partial-error, and retry states.
- Pagination/filter state must not strand the user on an empty page.

## Job detail
Information hierarchy:
identity → economics → scope → trust → lifecycle → next action.
Lifecycle actions are serialized while a transition is pending.

## Create/edit
- Preserve entered values on validation failure.
- Field errors are textual and associated with their fields.
- Duplicate submit is prevented.
- Successful create/edit follows the established owning-list navigation contract.

## Finance
- Available, locked, pending, and transaction values remain semantically distinct.
- Internal currency is TOMAN and must not be relabeled as another unit.
- Financial mutations require explicit busy/idempotency behavior supplied by the domain implementation.
- Guest users never receive private wallet/transaction data.

## Notifications
Unread state, time/context, action, loading, empty, and retry states must be explicit.
Deep-link destinations must remain consistent with the notification action.

## Permissions and privacy
Permission-sensitive controls must reflect actual authorization state; visual hiding is not a substitute for backend authorization.
Privacy/destructive actions require explicit confirmation and recovery guidance where possible.

## Async resilience
- Loading must not unexpectedly move primary controls.
- Errors explain what happened and what the user can do next.
- Retry is explicit.
- Safe stale data may remain visible during refresh failure.
- Offline behavior must not imply a successful server mutation.

## Accessibility
- Target WCAG 2.2 AA.
- Interactive targets are at least 48px.
- Keyboard focus is visible.
- Icon-only controls have accessible names.
- Reduced-motion preferences are honored.
- Large text scaling must not be disabled globally.

## Localization
fa and en are behaviorally equivalent locales. Directionality follows locale.
All user-facing messages and accessibility labels use the localization system where practical.

## Verification gate
A UI change is not complete until:
- focused widget/contract tests cover changed behavior;
- repository formatting/analyze/test/build checks required by the project are run;
- changed flow is exercised in a real runtime when available;
- success, loading, empty, error/retry, narrow viewport, and relevant accessibility states are checked;
- no PASS or QUALITY_READY claim is made from static inspection alone.
