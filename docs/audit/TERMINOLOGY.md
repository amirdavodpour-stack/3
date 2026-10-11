# HOPE Terminology & Copy Deck

Persian is the primary UI language. English must have matching semantic coverage through ARB keys. New user-facing copy must not be hardcoded into screen widgets.

| Concept | Persian canonical | English canonical | Rule |
|---|---|---|---|
| Listing umbrella | فرصت | Opportunity | Listing types are ماموریت (Mission) and شغل (Job). |
| Worker's application | درخواست | Application | Distinct from a priced proposal. |
| Priced worker proposal | پیشنهاد | Offer | Customer: پیشنهادهای دریافتی; worker: پیشنهادهای ارسالی. |
| Accepted engagement | همکاری | Engagement | Retire «معامله» and generic «پروژه» in user-facing listing language. |
| Escrowed funds | در امانت HOPE | Held in HOPE escrow | Avoid «محافظت‌شده» as the primary state label. |
| Spendable balance | قابل استفاده | Available | Current spendable amount, as returned by wallet API. |
| Awaiting settlement | در انتظار تسویه | Pending | Only where a real pending amount exists. |
| Lifetime earnings | کل درآمد | Lifetime earnings | Hide until a real settled-credit aggregate is available. |
| User wallet | کیف پول HOPE | HOPE wallet | «دفترکل» belongs only on an advanced audit surface. |
| Pulse | خلاصه وضعیت | Pulse | Brand label “HOPE Pulse” may appear once on Home. |
| Opportunity DNA | ویژگی‌های فرصت | Opportunity DNA | Prefer Persian in consumer UI. |
| Match | تطابق | Match | Budget score must be «تناسب بودجه», never «درآمد 82%». |
| Needs review | نیازمند بررسی | Needs review | Only genuine exceptions: dispute, failed payment, manual review. |

## Normal lifecycle status vocabulary

Use neutral/info/success semantic colors for normal progress, never warning amber:
`در انتظار تأمین وجه` → `وجه در امانت` → `در حال انجام` → `تحویل داده شد` → `تأیید شد` → `تسویه شد`.

## Tone and localization

- Respectful, friendly-formal `شما` form throughout; avoid informal singular/imperative phrasing.
- Persian digits in `fa`; Latin digits in `en`.
- Never render raw ISO timestamps, internal IDs, UUIDs, raw enum values or internal ledger jargon.
- Wrap embedded Latin terms in directional isolates or a shared BiDi-aware component where needed.
- Category labels must be mapped through localized categories; do not expose raw `Software`.
- Money is integer TOMAN only. Do not infer fee percentages or net amounts in Flutter.
- Example escrow explainer: «مبلغ همکاری تا زمان تأیید شما در امانت HOPE می‌ماند و بعد از تأیید به کیف پول مجری آزاد می‌شود.»
- Example accept confirmation: «{amount} تومان از کیف پول شما در امانت قرار می‌گیرد. تا تأیید کار، به مجری پرداخت نمی‌شود.»
- Example funds-secured copy: «وجه شما امن است. تا تأیید کار در امانت HOPE می‌ماند.»
- Example insufficient balance: «موجودی قابل استفاده شما {x} تومان کمتر از مبلغ لازم است.» CTA: «افزایش موجودی».
- Empty applications: «هنوز برای فرصتی درخواست نداده‌اید. از بخش کاوش شروع کنید.»

## Baseline gaps

- ARB file key counts differ by raw JSON property count because Persian includes more metadata; parity must compare actual message keys, excluding `@` metadata keys. This has not yet been computed in CI.
- English raw category `Software` is visible in the baseline saved-search screenshot.
- Google auth label exists in localization, but the icon is not brand-compliant in the baseline.
