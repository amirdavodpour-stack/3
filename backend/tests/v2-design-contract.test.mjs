import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('../..', import.meta.url).pathname);
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8');

test('V2 premium design system is present and wired into flagship surfaces', () => {
  const pubspec = read('pubspec.yaml');
  const theme = read('lib/core/theme/hope_v2_design.dart');
  const appTheme = read('lib/core/theme/app_theme.dart');
  const components = read('lib/core/ui/premium_components.dart');
  const home = read('lib/features/home/home_page.dart');
  const homeWidgets = read('lib/features/home/home_widgets.part.dart');
  const jobs = read('lib/features/jobs/jobs_page.dart');
  const homeFeed = read('lib/features/home/premium_home_feed.dart');
  const jobCard = read('lib/features/jobs/jobs_widgets.part.dart');
  const opportunityCard = read('lib/core/ui/opportunity_card.dart');
  const offersPage = read('lib/features/offers/offers_page.dart');
  const candidateMatches = read('lib/features/marketplace/employer_candidate_matches_page.dart');
  const profile = read('lib/features/profile/profile_page.dart');
  const transactions = read('lib/features/transactions/transactions_page.dart');
  const paymentSummary = read('lib/core/ui/premium_payment_summary.dart');
  const transactionUseCases = read('lib/core/application/use_cases.dart');
  const notifications = read('lib/features/notifications/notifications_page.dart');
  const admin = read('lib/features/admin/admin_page.dart');
  const lifecycle = read('lib/core/ui/premium_lifecycle.dart');
  const application = read('lib/core/marketplace/application.dart');
  const detailRepo = read('lib/core/marketplace/job_detail_repository.dart');
  const spec = read('V2-DESIGN-SYSTEM-SPEC.md');
  const profileRepo = read('lib/core/profile/profile_repository.dart');
  const providerRoute = read('backend/src/routes/provider_routes.js');
  const trustRepo = read('backend/src/repository/trust.js');

  assert.match(pubspec, /^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$/m);
  for (const token of [
    'HopeV2Spacing', 'HopeV2Radii', 'HopeV2Breakpoints', 'HopeV2Surfaces',
    'HopeV2Shadows', 'HopeV2Type', 'HopeV2Motion', 'HopeV2Touch', 'HopeV2Layer',
  ]) assert.match(theme, new RegExp(`class ${token}`));
  for (const primitive of [
    'PremiumPageFrame', 'PremiumHeader', 'PremiumPanel', 'PremiumHero',
    'PremiumStatCard', 'PremiumSectionHeader', 'PremiumTag', 'PremiumSearchBar',
  ]) assert.match(components, new RegExp(`class ${primitive}`));
  assert.match(components, /MediaQuery\.sizeOf\(context\)\.width < HopeV2Breakpoints\.compact/);
  assert.match(components, /HopeV2Touch\.minimum/);
  assert.match(components, /MediaQuery\.paddingOf\(context\)/);
  assert.match(components, /Semantics\(/);
  assert.match(home, /buildResponsiveHomeFeed/);
  assert.match(homeWidgets, /HopeResponsive\(/);
  assert.match(homeWidgets, /PremiumHomeFeed/);
  assert.match(homeFeed, /OpportunityCard/);
  assert.match(homeFeed, /home-pulse-stat|_homePulseStat/);
  assert.match(jobs, /premium_components\.dart/);
  // Explore/Home intentionally share the canonical OpportunityCard; the old
  // private Jobs card is now only a part-file marker.
  assert.match(jobs, /OpportunityCard/);
  assert.match(opportunityCard, /PremiumTag/);
  assert.match(opportunityCard, /HopeV2Radii/);
  assert.match(theme, /static Color amount\(BuildContext context\)/);
  assert.match(theme, /static Color price\(BuildContext context\)/);
  assert.match(theme, /static const moneyTextLight = Color\(0xFF18221C\)/);
  assert.match(theme, /static const moneyTextDark = Color\(0xFFF1F3EC\)/);
  assert.match(theme, /static const infoTextLight = Color\(0xFF115E59\)/);
  assert.match(appTheme, /labelColor: textColor/);
  assert.match(appTheme, /selectedColor: textColor/);
  assert.match(opportunityCard, /key: const ValueKey\('opportunity-card-standard-budget'\)[\s\S]{0,500}HopeV2SemanticColors.amount\(context\)/);
  assert.match(offersPage, /_money\(o.price\),[\s\S]{0,350}HopeV2SemanticColors.price\(context\)/);
  assert.match(paymentSummary, /_money\(context, baseAmount\),[\s\S]{0,200}HopeV2SemanticColors.price\(context\)/);
  assert.match(candidateMatches, /color: HopeV2SemanticColors.info\(context\)/);
  assert.match(opportunityCard, /HopeV2Surfaces/);
  for (const migrated of [profile, transactions, notifications, admin]) {
    assert.match(migrated, /premium_components\.dart/);
    assert.match(migrated, /PremiumPageFrame|PremiumHeader|PremiumPanel/);
  }
  assert.match(lifecycle, /class PremiumLifecycle/);
  assert.match(lifecycle, /PremiumLifecycleStep/);
  assert.match(transactions, /PremiumLifecycle/);
  assert.match(transactions, /PremiumPaymentSummary/);
  assert.match(paymentSummary, /class PremiumPaymentSummary/);
  assert.match(transactionUseCases, /idempotencyKey/);
  assert.match(application, /class HopeOffer/);
  assert.match(application, /String get statusLabel/);
  assert.match(application, /bool get isTerminal/);
  assert.match(detailRepo, /Future<HopeOffer> submitOffer/);
  assert.match(spec, /Premium Max/);
  assert.match(spec, /accessibility/i);
  assert.match(profileRepo, /trustSignals/);
  assert.match(profileRepo, /completedJobs/);
  assert.match(providerRoute, /getPublicTrustSignals/);
  assert.match(providerRoute, /trustSignals/);
  assert.match(trustRepo, /getPublicTrustSignals/);
  assert.match(trustRepo, /completed_jobs/);

});
