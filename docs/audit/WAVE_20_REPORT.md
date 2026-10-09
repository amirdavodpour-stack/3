# HOPE Visual Wave 20 — Compact-height content convergence

**Date:** 2026-10-09  
**Input:** Runtime #2203 / run `37875475661`, artifact `11591933824`  
**Code base:** `53daa8c96aa8274a381163d783cd3f87244d3237`  
**Scope:** presentation-only Flutter layout; preserve routes, backend data, ledger semantics, localized copy, and action contracts.

## Evidence reviewed

The artifact contains 25 PNGs: 19 primary Persian/RTL captures and six 720×1280 physical-pixel responsive captures representing 360×640 logical dp at 320 dpi. Contact sheets for the complete set were reviewed, with full-resolution checks on Home, Jobs, Opportunity Detail, Wallet, Profile, Work/Finance Center, Applications, Financial Insights, Create Opportunity, Job Satisfaction, Candidate Matches, Chat, and Offers.

## Confirmed visual defects

1. **Repeated dead band above the navigation dock.** Responsive Jobs, Wallet, Profile, and Work/Finance Center content stops materially above the dock. Primary captures show the same symptom on Jobs, Wallet, and Work/Finance Center. Large page-frame tails are being reserved in addition to the external navigation dock.
2. **Opportunity Detail reserves too much vertical space before its sticky action.** The page frame uses a 102dp bottom tail while the primary action already lives in the Scaffold bottom navigation area, reducing visible detail content.
3. **Create Opportunity and Job Satisfaction first folds are unnecessarily short.** Their page frame bottom padding and nested scroll padding are both large; the first screen exposes less form content than necessary.
4. **Jobs results compound the reserved tail.** The result sliver adds 122dp after the final item while the page frame also reserves bottom space.

## Wave 20 changes

- Reduce the shared compact-height `PremiumPageFrame` tail cap from 20/40dp to 8/16dp. The dock is already outside the body; retain a minimal gesture cushion rather than a second navigation-sized band.
- Align bottom padding on Jobs, Wallet, Profile, Work/Finance Center, Applications, Opportunity Detail, Create Opportunity, and Job Satisfaction with the actual viewport composition.
- Reduce Jobs result-tail padding from 122dp to 56dp so the list does not reserve an additional oversized blank tail.
- Keep the existing canonical HOPE navy/indigo/teal palette, 48dp interactive targets, RTL layout, financial formatting, API state, navigation, and job lifecycle untouched.
- Expand the existing single focused Flutter widget-test case to assert the new 16dp compact-height contract. Update source guards and both workflow marker conditions to Wave 20 so the entire wave receives one Flutter test run and one post-green runtime capture.

## Acceptance gate

- Static verification must pass on the final feature-branch HEAD, including Flutter analyze, design/contrast guards, runtime source guards, backend checks, and exactly one invocation of `flutter test --no-pub test/core/ui/premium_visual_wave_15_test.dart`.
- Only after static success, trigger one Android runtime capture of the same HEAD.
- Inspect all 25 resulting PNGs; compare the responsive first fold and dock gap on Jobs, Wallet, Profile, Work/Finance Center, Opportunity Detail, Create Opportunity, and Job Satisfaction.
- Reconfirm complete localized budget ranges on Home and Jobs.
- Keep PR #30 draft/unmerged and `main/production` untouched. T10 Visual Certification remains NOT ACCEPTED until the new artifact is visually reviewed.

## Design references

- HOPE canonical visual contract and previous wave history: `DESIGN.md`, `docs/design/HOPE-DS-2.0-spec.md`.
- Existing HOPE UI Audit Board in Canva: 48dp targets, responsive content-first layouts, real data, and restrained HOPE tokens.
- Material Design accessibility and responsive layout guidance: https://m2.material.io/design/usability/accessibility and https://m3.material.io/components/cards/accessibility.
- Flutter adaptive/responsive layout guidance: https://docs.flutter.dev/ui/adaptive-responsive.
