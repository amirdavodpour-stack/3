# Backend Capability Gap Matrix

Baseline source: `d9eb4143c2622f85d33772aebf9bc351146e265e`. Values below are based on live source inspection; items not exercised by a test remain NOT VERIFIED.

| Screen element | Required data/API | Baseline status | Action |
|---|---|---|---|
| Capability gating | `GET /config/capabilities` | EXISTS | Preserve as the source of feature availability. |
| Wallet total/available/locked | `GET /wallet/me` | EXISTS | Render total once; total = available + locked. |
| Escrow amount | Active `JOB_PAYMENT` holds | EXISTS | Show as a subset of locked, never add twice. |
| Pending withdrawal | Active `PAYOUT_RESERVATION` holds + payout states | EXISTS / semantics need test | Clarify that pending funds are already excluded from available. |
| Wallet history | `GET /wallet/transactions` | EXISTS, cursor-paginated | Preserve pagination and integer amounts. |
| Withdrawal | `POST /wallet/withdraw` | EXISTS, capability-gated | Keep idempotency and insufficient-funds behavior. |
| Deposit/top-up | `POST /wallet/top-up` | EXISTS only in internal sandbox/staging | Hide CTA when `walletDeposit=false`; never simulate a successful top-up. |
| Internal transfer | `POST /wallet/transfer` | EXISTS | Move to overflow if not a primary wallet action. |
| Google sign-in | `GET /config/capabilities` + auth routes | EXISTS, configuration-gated | Official G icon; no false enabled state. |
| Saved opportunities | `POST/DELETE /me/saved-opportunities` | MISSING (`savedOpportunities=false`) | Hide unsupported feature or implement later additively. |
| Human reference | Stable `#HP-…` on engagement/payment/offer | MISSING (`humanReferences=false`) | Hide internal IDs now; add stable backend reference later. |
| Fee quote before apply/accept | Server quote with gross/fee/policy/net | NOT FOUND in inspected offer route | Trace `calculatePaymentBreakdown` and expose a quote endpoint only after its semantics/tests are confirmed. |
| Next action | `GET /me/next-action` or safe aggregator | NOT FOUND in inspected capabilities | Build only from existing server-authoritative engagement/offer/profile states. |
| Activity feed/badges | `GET /me/activity`, `GET /me/badges` | NOT FOUND | Derive read model only if source state is available; otherwise hide badge counts. |
| Lifetime earnings | Settled worker credits aggregate | MISSING (`lifetimeEarnings=false`) | Hide row. |
| Verified badge | Identity state | Capability says true; exact source not verified in this pass | Verify identity source before rendering. |
| Reputation/rating | Aggregate reviews | MISSING (`reputation=false`) | Hide stars; do not fabricate. |
| Response time | Median response interval | MISSING (`responseTime=false`) | Hide. |
| Distance | Permissioned coordinates or city-level match | Capability says true; semantics not verified | Prefer city label until distance calculation/data provenance is verified. |
| Match improvement hints | Match-engine missing-skill diff | MISSING (`matchImprovementHints=false`) | Omit uplift claims. |
| Candidate comparison | Applicants + match + skills + offer amount + delivery time | MISSING (`candidateComparison=false`) | Hide or add read model later. |
| Notification date/relative time | Backend timestamp + shared formatter | EXISTS as timestamp; formatter exists | Use relative time/Jalali formatter; never raw ISO. |
| Opportunity category label | Localized category map | PARTIAL | Replace raw enum/category strings such as `Software`. |
| Role mode | Persisted worker/customer preference + server authorization | NOT VERIFIED | UI switch alone is not authorization; inspect current source before wiring. |

## Migration ledger

Historical migrations currently reach `033_human_chat.js`; the project context's older “021” value is stale. Any new database work must be additive at `034+` and must not rewrite existing migrations.
