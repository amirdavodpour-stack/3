# HOPE Semantic Icon Map

Status: ACTIVE — Kinetic Editorial migration
Source baseline: `feat/hopev2-kinetic-editorial-2026-10-16`

## Canonical icon family

All consumer-facing glyphs use Flutter `CupertinoIcons` `IconData` through the shared `HopeV2Icons` vocabulary or the outline/filled navigation pairs in `HopeV2NavigationIcons`. `HopeIcon` and `HopeIconTile` are the shared rendering adapters. HugeIcons rendering remains only as a compatibility branch for legacy callers; it is not the product vocabulary for new or migrated surfaces.

The style is Cupertino/SF-inspired, not a claim that these are official Apple SF Symbols assets. Avoid direct per-screen icon selection. Add new concepts to this map and the central registry first.

## Semantic mapping

| Concept | Shared key | Canonical Cupertino glyph | Rule |
|---|---|---|---|
| Home | `home` / `homeSelected` | house / house_fill | Filled only when selected in the primary dock |
| Discover | `search` | search | Search input or search action |
| Explore destination | `HopeV2NavigationIcons.explore` | compass / compass_fill | Navigation only |
| Workshop destination | `workshop` / `workshopSelected` | briefcase / briefcase_fill | Navigation only |
| Mission / execute | `mission` | bolt | Work action, not generic state |
| Job / opportunity | `job` | doc_text | Opportunity identity |
| Featured | `featured` | star | Genuine featured/recommended content only |
| Match / AI fit | `match` | sparkles | Match meaning only; never generic decoration |
| Trust / escrow | `protectedFunds` / `escrow` | lock_shield | Protected funds / escrow only |
| Wallet | `wallet` | creditcard | Wallet destination and balance |
| Payments / invoice | `payments` | doc_on_clipboard | Payment/invoice facts |
| Budget | `budget` | doc_chart | Budget / financial allocation |
| Activity | `activity` | waveform_path | Activity or timeline cue; not a financial metric |
| Insights | `insights` | chart_bar | Analytics and measured trends |
| Partial progress | `partial` | chart_pie | Incomplete/partial state, not generic analytics |
| Assignment | `assign` | person_crop_circle_badge_checkmark | Assign/confirm person, distinct from add-user |
| Deposit | `deposit` | arrow_down_circle | Render action only when `walletDeposit=true` |
| Withdraw | `withdraw` | arrow_up_circle | Withdrawal action; danger semantics only after failure |
| Transfer in | `transferIn` | arrow_down_left | Directional transaction row |
| Transfer out | `transferOut` | arrow_up_right | Directional transaction row |
| Transfer | `transfer` | arrow_left_right | Transfer action |
| History | `history` | clock | Wallet and transaction history |
| Completed / success | `completed` / `success` | checkmark_circle | Success only after operation succeeds |
| Pending | `pending` | hourglass | Non-final state |
| Error | `error` | xmark_circle | Pair with recovery guidance when available |
| Verified | `verified` | checkmark_seal | Only when server-backed identity state is true |
| Location | `location` | location | City/location only when available and permissioned |
| Distance | `distance` | location_north | Distance/direction, not an exact location assertion |
| Category | `category` | tag | Category identity |
| Deadline | `deadline` | calendar | Due date / deadline |
| Save | `save` / `savedSearches` | bookmark | Saved opportunity or search |
| Share | `share` | share | Native share affordance |
| Message | `message` | chat_bubble_text | Conversation / message |
| Notification | `notifications` | bell | Notification entry point |
| Filter | `filter` | slider_horizontal_3 | Search/list filters |
| Refresh / retry | `refresh` / `retry` | arrow_clockwise | Animate only while an actual refresh/retry runs |
| Role switch | `roleSwitch` | repeat | Switch between مجری / کارفرما |
| Description | `description` | doc_richtext | Longer content/details, distinct from opportunity identity |
| Attachment / upload | `attachment` / `upload` | paperclip / tray_arrow_up | Evidence and file actions |
| Empty state | `empty` | tray | Pair with concise, actionable empty-state copy |
| Offline | `offline` | wifi_slash | Explain connection state and recovery |
| Google sign-in | official Google G asset | Existing brand asset | Never substitute another glyph, recolor or redraw the brand mark |
| Device platform | `android` / `apple` | Generic device silhouettes | Platform name remains visible as text; do not imitate or redraw platform marks |

## State and interaction rules

- Header icon-only controls: maximum two; put remaining actions in overflow.
- Every icon-only control needs a Persian tooltip and semantics label.
- Core icons use consistent optical scale. Use filled/selected variants only where state changes; avoid oversized white glyphs in form fields.
- Color alone never communicates state. Pair status color with an icon and readable text.
- Financial direction remains explicit. Never use a currency-specific glyph that falsely implies USD or another currency for TOMAN amounts.
- Kinetic editorial framing is decorative; it must not imply success, failure, verification, balance, trust, or live progress on its own.
- Static illustration remains legible under reduced-motion settings; animated behavior is reserved for real async operations and respects system reduce-motion.
- User-authored content, quoted messages and meaningful user emojis are not blanket-rewritten. Only decorative product-authored emoji are replaced.
- Runtime screenshot and semantics tests are required before visual acceptance.
