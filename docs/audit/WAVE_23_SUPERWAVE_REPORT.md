# Wave 23 — HOPE Design System 2.0 Superwave

**State at assembly:** implementation bundle prepared; new static/runtime evidence pending.

## Concrete changes in this bundle
- Reorder Home so HOPE Pulse appears before recommended opportunities, using a non-horizontally-scrolling metric panel.
- Replace the compact opportunity score tile with a circular indicator while retaining existing data-backed score inputs and breakdown bars.
- Tighten default compact panel inset, preserving explicit feature overrides.
- Keep a concise Money Flow heading visible in compact view without duplicating any wallet balance amounts.
- Show aggregate locked money from `HopeWallet.lockedBalance`, not the separate `otherLockedBalance` component.
- Use a vertical payment lifecycle timeline in compact view as well as wide view.
- Add a real-data comparison matrix for up to three candidates on wide layouts, keeping stacked mobile details.
- Collapse the optional live preview on compact Create Opportunity screens.
- Require deliberate answers for overall rating, communication rating and work-agreement state before satisfaction submission.
- Extend Flutter tests and source guards in the same changeset.

## Verification contract
One static CI execution owns the one consolidated Flutter test invocation, Flutter analyze and current source/contrast/backend gates. Only after exact-head static PASS should one Android runtime capture be requested. Its metadata must match the feature HEAD and the 25 screenshots (19 primary + 6 responsive) must be opened and inspected individually.

## Boundaries
No backend source, API payload, authorization, wallet arithmetic, payment transitions, route behavior or dependencies are changed. `main/production` is untouched. PR #30 stays Draft and unmerged. Runtime evidence cannot establish TalkBack compliance when accessibility is disabled.
