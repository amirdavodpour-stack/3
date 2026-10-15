# HOPE DS 2.0 — Target Parity Matrix

Baseline is run #1901 at SHA `d9eb4143c2622f85d33772aebf9bc351146e265e`. No criterion is marked MATCHED without screenshot or test evidence.

| Target element | Baseline | Status | Next proof |
|---|---|---|---|
| Home greeting/avatar/role switch | Greeting and avatar; role switch absent/not evidenced | DEVIATED | role-aware Home screenshot + persisted role test |
| Home Pulse four equal metrics | Present, but labels truncate at 720×1280 | DEVIATED | 3 viewports + scale 2.0 |
| Server-ranked next action | Not evidenced | NOT DONE | aggregator/data contract + runtime |
| Best match opportunity | Present; large media hero consumes space | DEVIATED | compact card with category cover + after screenshot |
| Explore search/filter row | Filter sits on separate row; search icon is oversized | DEVIATED | one-line search/filter composition |
| Opportunity detail compact hero | Hero overlaps tags/back affordance at responsive size | FAIL | responsive screenshots and interaction check |
| Match breakdown | Score ring and bars exist; actual data provenance not verified | DEVIATED | model/API trace + data-backed tests |
| Wallet total once | Total repeated in ledger financial view | FAIL | single balance card + reconciliation widget test |
| Wallet deposit capability gating | API capability exists; normal UI lacks deposit in baseline | PARTIAL | explicit capabilities consumption + false/true tests |
| Wallet role-specific money flow | Not evidenced | NOT DONE | customer/worker state captures |
| Transaction/engagement human ref | Raw `payment-runtime-1` visible | FAIL | stable backend ref or hidden internal ID |
| Six-step timeline | Present but step progress appears nearly empty and status repeats | DEVIATED | state-specific timeline screenshots |
| Opportunity DNA | UI vocabulary is still mixed English/Persian | DEVIATED | Persian copy + capability-gated rows |
| Create opportunity 5-step flow | Stepper exists; preview occupies too much initial viewport | DEVIATED | compact bottom peek + keyboard/scroll capture |
| Candidate comparison | Capability false | NOT DONE | hide or implement backend read model |
| Funds secured | Not evidenced as a dedicated success state | NOT DONE | funding integration screenshot |
| Offers role-aware | Current screen exists; title/ID/counterparty completeness not fully verified | PARTIAL | role matrix + accept-sheet screenshot |
| Notifications readable action | Button appears disabled/low contrast | FAIL | contrast calculation + after screenshot |
| Profile appearance system | Dark baseline only; setting visible but selector/three-state not proven | NOT VERIFIED | dark/light/system persistence tests |
| Google official mark | Person-add glyph used | FAIL | approved G asset + screenshot |
| Full state matrix | Not captured | NOT DONE | loading/empty/error/offline/keyboard/sheet captures |
| 360×640 + 720×1280 + 1080×1920 | Only 720 and 1080 captured | FAIL | all three viewport sizes |
| fa-RTL + en-LTR, dark + light | fa-dark only | FAIL | language/theme matrix |
| TalkBack + scale 2.0 | accessibility disabled; no scale capture | FAIL | metadata=1 and scale tests |
