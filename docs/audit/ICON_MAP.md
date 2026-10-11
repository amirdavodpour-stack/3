# HOPE Semantic Icon Map

The current UI uses HugeIcons through shared `HopeV2Icons` / `HopeIcon`. Keep one semantic concept per icon; do not introduce per-screen glyph choices without updating this map.

| Concept | Canonical icon concept | Requirements |
|---|---|---|
| Discover/search | magnifier | Use in Explore/search only. |
| Execute / mission | bolt | Work/mission action, not generic status. |
| Trust / escrow | shield-lock | Funds-in-escrow only. |
| Match / AI-fit | sparkle | Match meaning only; do not reuse as a generic decoration. |
| Wallet | wallet | Wallet destination/balance. |
| Deposit | arrow-down-circle | Render only when `walletDeposit=true`. |
| Withdraw | arrow-up-circle | Withdrawal request, danger semantics only for failure. |
| History | clock-counter | Wallet history. |
| Transfer | arrows-swap | Transfer, preferably in overflow. |
| Save | bookmark | Saved opportunity/search. |
| Share | share | Native share affordance. |
| Verified | badge-check | Only when server-backed identity state is true. |
| Location | pin | City/location only when available/permissioned. |
| Budget | banknote | Budget or amount. |
| Deadline | calendar | Due date/deadline. |
| Notification | bell | Notification entry point. |
| Filter | sliders | Search filter. |
| Refresh | refresh-cw | Refresh/retry. |
| Role switch | repeat | Switch between مجری / کارفرما. |
| Google sign-in | official Google G asset | Never substitute person-add glyph; do not recolor/redraw the brand mark. |

## Interaction rules

- Header icon-only controls: maximum two; place remaining actions in overflow.
- Every icon-only control requires a Persian tooltip and semantics label.
- Icon stroke/weight must remain consistent; avoid oversized white glyphs in form fields.
- Color alone never communicates status; pair color with text and icon.
- Current baseline fails Google icon branding and has some ambiguous repeated glyphs. Fixes are not considered closed until screenshot and semantics tests pass.
