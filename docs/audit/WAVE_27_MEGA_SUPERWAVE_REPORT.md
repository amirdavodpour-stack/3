# Wave 27 Mega-Superwave — cross-surface visual quality

## Change scope

This commit consolidates the next visual wave into one feature-branch change. It extends shared scroll-tail and system-inset handling across core work, finance, discovery, communication, notifications, profile and authentication surfaces; improves compact Home spacing and wide-screen recommendation density; makes financial chart category/date labels horizontally legible without dropping or synthesizing data; and corrects compact opportunity range line breaks so amount endpoints remain readable while the currency unit appears once.

The changed implementation covers:
- Shared design tokens and scroll geometry.
- Wallet, Work Center, transaction detail, profile, opportunity detail, candidate matching and applications.
- Home, Explore, saved searches, offers, notifications and notification devices.
- Create Opportunity, satisfaction form and authentication surfaces.
- Financial chart layout, chat composer iconography and compact opportunity money labels.
- Regression assertions for scroll-tail insets, chart scroll surfaces, exact Toman range rendering and a strengthened runtime source guard.

## Invariants retained

No API, authentication, routing, payload, wallet/ledger arithmetic, payment transition or job lifecycle semantics are intentionally changed. Data points and opportunity budget endpoints remain source-backed; this wave changes their presentation and scroll access only. Compact live preview remains collapsed by default, satisfaction cannot submit before required answers, and chat's action control is not downsized with its decorative glyph. The runtime source guard's executable file mode must remain `100755`.

## Acceptance status

**Verification pending at commit authoring.** A source change, source guard or authored audit statement is not a pass. Record the exact-HEAD Static CI run and its consolidated Flutter result first. Only then request one serialized Android runtime capture on the same HEAD if the approved PR marker path is available. Verify artifact identity and inspect all 25 fresh screenshots individually. Screen-reader/TalkBack certification remains **NOT ACCEPTED** until runtime evidence confirms an enabled accessibility service.

## Branch policy

Target only `feat/ui-v2-wave-1-execution-2026-10-07`. PR #30 must remain Open, Draft and Unmerged. `main` and production are forbidden write targets. No force-push, workflow bypass or fabricated evidence.
