# Defect Closure Register

Baseline run: [#1901](https://github.com/amirdavodpour-stack/3/actions/runs/37596668414), SHA `d9eb4143c2622f85d33772aebf9bc351146e265e`. All baseline screenshots are in the run artifact; no image has been edited. “OPEN” means no valid after-proof exists yet.

| ID | Defect | Baseline finding | Status |
|---|---|---|---|
| D-01 | Raw ISO timestamps | Not visible in current Notifications/Offers captures, but lint/test proof absent | OPEN / partial |
| D-02 | BiDi-scrambled date | Not reproduced in current Offers capture; regression test needed | OPEN |
| D-03 | Internal IDs | Transaction detail displays `payment-runtime-1` | OPEN — Wave 1 target |
| D-04 | Reversed Home range | Current Home screenshot shows min-to-max ordering | PARTIAL — add unit/render proof |
| D-05 | Truncated Explore price | Current price appears clipped/wrapped at compact widths | OPEN |
| D-06 | Test/demo leakage | Profile shows `ali.test@hope.local`; no stock photo or forbidden `runtime@example.invalid` in reviewed artifact | OPEN / test-only isolation |
| D-07 | Terminology drift | Multiple names remain in code/UI | OPEN |
| D-08 | English/jargon leakage | Saved search exposes `Software`; “HOPE Pulse” is allowed once on Home | OPEN |
| D-09 | False warning/status repetition | Baseline transaction shows duplicate status treatments | OPEN |
| D-10 | Inconsistent icons / Google glyph | Google button uses person-add, not official G; several large form glyphs | OPEN — Wave 1 target |
| D-11 | Oversized header/hero | Auth/detail hero is tall; content competes for first viewport | OPEN |
| D-12 | Below-fold forms | Register CTA partially clipped; create form preview too tall | OPEN |
| D-13 | Hero image/default card waste | Opportunity card uses abstract art, but featured hero remains oversized | OPEN |
| D-14 | Navigation IA/role switching | Bottom tab still says «کار» in Home capture while other pages show «فعالیت»; role switch not evidenced | OPEN |
| D-15 | Accept-offer lacks consequence context | Accept-sheet not captured | NOT VERIFIED |
| D-16 | Tiny low-contrast labels/metric shrink | Pulse labels truncate at 720×1280 | OPEN |
| D-17 | Responsive labels/hero overlap | Home metric and detail hero clipping/overlap visible at 720×1280 | OPEN |
| D-18 | Unlabeled application stepper | Application screen shows unlabeled dots | OPEN |
| D-19 | Disabled-looking notification CTA | CTA grey on grey in Notifications | OPEN |
| D-20 | Latin digits/Gregorian/relative time | Jalali/relative formatter exists; whole app proof missing | OPEN |
| D-21 | Wallet duplication/action ambiguity | Repeated financial view and total; no visible deposit (correct when disabled, but capability integration unverified) | OPEN |
| D-22 | Transaction status/timeline | Duplicate status pill and weak progress fill visible | OPEN |
| D-23 | Offers stat/chip duplication | Offers screen has stat/filter duplication | OPEN |
| D-24 | Saved-search filter string/edit icon | Raw `Software` and ambiguous camera-like action visible | OPEN |
| D-25 | Profile identity/theme | Identity block is aligned; appearance control is not proven to expose dark/light/system | PARTIAL |
| D-26 | Tone inconsistency | Full copy deck not enforced | OPEN |
| D-27 | Incomplete evidence/certification | fa-dark only, no 360dp, no TalkBack, no scale or state matrix; metadata says accessibility disabled | FAIL |
| D-28 | In-scope defect slot reserved by prior audit | No independently reproducible description attached in current source docs | NOT MAPPED — reconcile with canonical audit |
| D-29 | Home orphan/empty section heading | «تطابق‌ها» heading appears without visible content below it | OPEN |
| D-30 | Explore layout redundancy | Filter button sits alone on a row; oversized search icon; redundant card CTA | OPEN |

Closure rule: a defect may move to CLOSED only when its exact after screenshot(s) are in the wave artifact, the relevant automated test passes, and `evidence/wave-N/REVIEW.md` names the screenshot and reviewer verdict. “Not reproduced” is not the same as closed.
