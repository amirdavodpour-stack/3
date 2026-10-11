# HOPE UX Debt Register

Baseline: run #1901, SHA `d9eb4143c2622f85d33772aebf9bc351146e265e`.

| Priority | Debt | Evidence | Owner scope | Exit condition |
|---|---|---|---|---|
| P0 | No visual certification matrix | [Run #1901](https://github.com/amirdavodpour-stack/3/actions/runs/37596668414), metadata accessibility-enabled=0 | Wave 4 | Full viewport/locale/theme/scale/state/TalkBack matrix with truthful certification |
| P1 | Wallet duplicated balance presentation | `wallet-fa-rtl.png` in run artifact | Wave 1 | One total + ledger-invariant widget test |
| P1 | Internal payment ID rendered to user | `transaction-detail-fa-rtl.png` in run artifact | Wave 1 | Internal ID hidden; stable ref remains backend gap |
| P1 | Responsive Home/Detail clipping | `responsive-720x1280-home-fa-rtl.png`, `responsive-720x1280-job-detail-fa-rtl.png` | Wave 1 | 360/720/1080 screenshots + text scale |
| P1 | Auth primary CTA clipped | `register-fa-rtl.png` | Wave 1 | CTA visible with keyboard closed/open at 720×1280 |
| P1 | Google sign-in icon not official G | `login-fa-rtl.png`, `register-fa-rtl.png` | Wave 1 | approved asset + screenshot |
| P1 | Notification CTA low contrast | `notifications-fa-rtl.png` | Wave 1 | measured contrast and after screenshot |
| P2 | Saved-search category exposes English enum | `saved-searches-fa-rtl.png` | Wave 1 | localized category map |
| P2 | Theme/locale parity unproven | Baseline only fa-dark | Wave 4 | en-light and parity review |
| P2 | Category illustration system missing/partial | Baseline category art is generic/repeated abstract art | Wave 2 | 12 category-specific deterministic covers, fallback, size budget |
| P2 | Server-backed match, trust and role data provenance incomplete | capability endpoint reviewed | Wave 2/3 | gap matrix and API-backed evidence |
| P2 | Contrast and Flutter guideline tests not in CI proof | no contrast report in artifact | Wave 4 | script + guideline tests in passing CI |
