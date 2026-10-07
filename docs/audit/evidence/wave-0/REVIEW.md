# Wave 0 Screenshot Review

Run: [#1901](https://github.com/amirdavodpour-stack/3/actions/runs/37596668414)  
SHA: `d9eb4143c2622f85d33772aebf9bc351146e265e`  
Artifact: `11471421888`  
Locale/theme: fa-RTL / dark  
Counts: 15 × 1080×1920 + 6 × 720×1280

Every PNG in the artifact was inspected. Source images remain untouched.

| Screenshot | Verdict | Findings |
|---|---|---|
| `applications-fa-rtl.png` | FAIL | Six unlabeled progress dots; large unused lower area; status/step labels not sufficiently explanatory. |
| `create-job-fa-rtl.png` | FAIL | Preview/type panel dominates initial viewport; first form controls are pushed down. |
| `home-fa-rtl.png` | FAIL | Main visual identity is coherent, but featured card is oversized and orphan “تطابق‌ها” section has no visible content. |
| `job-detail-fa-rtl.png` | FAIL | Large hero overlaps/competes with tags and controls; no fee/escrow context beside primary action. |
| `jobs-fa-rtl.png` | FAIL | Search/filter layout wastes a row; search glyph too large; budget and meta hierarchy is dense. |
| `login-fa-rtl.png` | FAIL | Google button uses person-add icon; hero is too tall; large field glyphs dominate. |
| `notifications-fa-rtl.png` | FAIL | Primary action appears disabled due grey-on-grey contrast; no grouped-day hierarchy. |
| `offers-fa-rtl.png` | FAIL | Stats/chips duplicate; context before accepting an offer is not shown in the captured state. |
| `password-reset-fa-rtl.png` | FAIL | Tall hero; success-state copy/confirmation card not yet clearly separated from form. |
| `profile-fa-rtl.png` | PARTIAL | Identity block is aligned; test account email is visible; appearance selector parity not proven. |
| `register-fa-rtl.png` | FAIL | Primary CTA is clipped at bottom; oversized hero and field icons. |
| `responsive-720x1280-home-fa-rtl.png` | FAIL | Pulse metrics and labels truncate; Best Match card is clipped by viewport. |
| `responsive-720x1280-job-detail-fa-rtl.png` | FAIL | Back control and hero tags overlap; title is too large for hero composition. |
| `responsive-720x1280-jobs-fa-rtl.png` | FAIL | Budget/card title hierarchy clips below viewport; search/filter spacing is wasteful. |
| `responsive-720x1280-profile-fa-rtl.png` | PARTIAL | Identity is clear; settings are not fully captured and no scroll-bottom evidence exists. |
| `responsive-720x1280-transactions-fa-rtl.png` | FAIL | Stat labels are ellipsized; status summary repeats “0 settled” as if positive; content below fold is missing. |
| `responsive-720x1280-wallet-fa-rtl.png` | FAIL | Wallet balance duplicated in ledger view; subcategory semantics unclear; no full scroll capture. |
| `saved-searches-fa-rtl.png` | FAIL | Raw English category “Software”; edit/action glyph ambiguous; filter summary not rendered as localized chips. |
| `transaction-detail-fa-rtl.png` | FAIL | Internal payment ID exposed; duplicate status pill; timeline appears nearly empty. |
| `transactions-fa-rtl.png` | FAIL | Financial hub owns “کار” navigation; stat tiles duplicate card status; flow/action ownership unclear. |
| `wallet-fa-rtl.png` | FAIL | Duplicate total/ledger view, 9.5sp labels and clipped lower rows; unsupported deposit state not explained. |

## Certification limitation

This artifact is a successful capture, not a certified baseline. Metadata reports `accessibility-enabled=0`; only fa-dark was captured, at 1080×1920 and 720×1280, with no full-length/keyboard/state captures.
