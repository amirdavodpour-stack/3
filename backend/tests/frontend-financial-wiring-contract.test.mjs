import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

test('transaction UI is wired to real payment and job lifecycle repository commands', () => {
  const repository = read('lib/core/transactions/transaction_repository.dart');
  const controller = read('lib/features/transactions/transaction_controller.dart');
  const useCases = read('lib/core/application/use_cases.dart');
  const page = `${read('lib/features/transactions/transaction_page.dart')}\n${read('lib/features/transactions/transaction_widgets.part.dart')}`;

  for (const endpoint of [
    "'/payments/jobs/$jobId'",
    "'/payments/fund/$jobId'",
    "'/payments/refund/$jobId'",
    "'/payments/release/$jobId'",
    "'/jobs/$jobId/start'",
    "'/jobs/$jobId/deliver'",
    "'/jobs/$jobId/accept'",
  ]) assert.ok(repository.includes(endpoint), `missing ${endpoint}`);

  for (const operation of ["'fund'", "'refund'", "'release'"]) assert.ok(useCases.includes(operation), `missing ${operation}`);
  for (const operation of ["'start'", "'deliver'", "'accept'"]) assert.match(controller, new RegExp(operation));
  assert.match(page, /Future<void> _jobAction\(String operation\)/);
  assert.match(page, /Future<void> _confirmAction\(String operation\)/);
  assert.match(page, /Refresh status/);
  assert.doesNotMatch(page, /Payment ID:|شناسه پرداخت:/);
  assert.match(page, /Financial action/);
  assert.match(page, /Funds held/);
});

test('transaction evidence panel does not duplicate primary lifecycle controls', () => {
  const evidence = read('lib/features/transactions/transaction_evidence.part.dart');
  assert.doesNotMatch(evidence, /repository\.(startJob|deliverJob|acceptJob|releasePayment)\(/);
  assert.match(evidence, /copy_submit_evidence_bf38455/);
});

test('wallet UI is wired to repository mutations and wallet history controls', () => {
  const repository = read('lib/core/transactions/wallet_repository.dart');
  const page = read('lib/features/wallet/wallet_page.dart');

  for (const endpoint of ["'/wallet/me'", "'/wallet/transactions'", "'/wallet/payouts'", "'/wallet/transfer'", "'/wallet/withdraw'", "'/wallet/top-up'"]) {
    assert.ok(repository.includes(endpoint), `missing ${endpoint}`);
  }

  for (const method of ['topUp', 'transfer', 'requestPayout']) assert.match(page, new RegExp(`repository\\.${method}\\(`));
  assert.match(page, /_pendingKey\('TOP_UP'/);
  assert.match(page, /_pendingKey\('TRANSFER'/);
  assert.match(page, /_pendingKey\('PAYOUT'/);
  assert.match(page, /PremiumFilterChip/);
  assert.match(page, /'CREDIT'/);
  assert.match(page, /'DEBIT'/);
  assert.match(page, /'HOLD'/);
  assert.match(page, /Pending withdrawal|برداشت در انتظار|_pendingPayoutCount/);
  assert.match(page, /maximum available|Maximum available/i);
  assert.match(page, /Transfer amount exceeds your available balance/);
  assert.match(page, /Future<void> _showPayout/);
  assert.match(page, /duplicate payout/);
});

test('job detail exposes real financial transaction controls and resilient candidate states', () => {
  const page = read('lib/features/marketplace/job_detail_page.dart');
  assert.match(page, /HopeRoutes\.transaction\(/);
  assert.match(page, /copy_view_transaction_a91f1e6/);
  assert.match(page, /ConnectionState\.waiting/);
  assert.match(page, /snapshot\.hasError/);
  assert.match(page, /No candidates to display yet/);
});

test('job detail uses role-aware primary financial CTA and prevents duplicate candidate actions', () => {
  const page = read('lib/features/marketplace/job_detail_page.dart');
  assert.match(page, /final isOwner =/);
  assert.match(page, /final isProvider =/);
  assert.match(page, /final canViewFinance = isOwner \|\| isProvider/);
  assert.match(page, /View financial flow/);
  assert.match(page, /String\? _candidateBusyId/);
  assert.match(page, /_candidateBusyId == candidate\.id/);
  assert.match(page, /FilteringTextInputFormatter\.digitsOnly/);
  assert.match(page, /suffixText: _t\('تومان', 'Toman'\)/);
});

test('activity screen exposes a direct route from backend payment summary to transaction controls', () => {
  const page = read('lib/features/transactions/transactions_page.dart');
  assert.match(page, /FutureBuilder<HopePayment\?>/);
  assert.match(page, /PremiumPaymentSummary\(payment: payment\)/);
  assert.match(page, /HopeRoutes\.transaction\(/);
  assert.match(page, /context\.read<TransactionRepository>\(\)/);
  assert.match(page, /context\.read<UploadQueue>\(\)/);
});


test('financial insights and satisfaction UI are wired to scoped backend capabilities', () => {
  const financialRepository = read('lib/core/financial/financial_insights_repository.dart');
  const financialPage = read('lib/features/financial/financial_insights_page.dart');
  const satisfactionRepository = read('lib/core/jobs/job_satisfaction_repository.dart');
  const satisfactionPage = read('lib/features/jobs/job_satisfaction_page.dart');
  const routes = read('lib/core/router/app_routes.dart');
  const main = read('lib/main.dart');
  assert.match(financialRepository, /financial-insights/);
  assert.match(financialPage, /Monthly cash flow|جریان نقدی ماهانه/);
  assert.match(financialPage, /Balance trend|روند موجودی/);
  assert.match(financialPage, /Financial activity sources|منابع فعالیت مالی/);
  assert.ok(satisfactionRepository.includes('/jobs/${_id(jobId)}/satisfaction'));
  assert.match(satisfactionPage, /Work satisfaction report|گزارش رضایت همکاری/);
  assert.match(satisfactionPage, /no general AI chat|هیچ چت عمومی/);
  assert.match(routes, /financialInsights\(\)/);
  assert.match(routes, /jobSatisfaction\(String jobId\)/);
  assert.match(main, /FinancialInsightsRepository/);
  assert.match(main, /JobSatisfactionRepository/);
});

test('shared financial summary keeps status and financial language localized', () => {
  const summary = read('lib/core/ui/premium_payment_summary.dart');
  const activity = read('lib/features/transactions/transactions_page.dart');
  for (const marker of ['Localizations.localeOf(context).languageCode', 'Funds held', 'وجه در امانت', 'Total charge', 'مبلغ نهایی']) {
    assert.ok(summary.includes(marker), `missing ${marker}`);
  }
  for (const marker of ['PUBLISHED', 'ASSIGNED', 'IN_PROGRESS', 'DELIVERED', 'UNDER_REVIEW', 'COMPLETED', 'Settled', 'تسویه شده']) {
    assert.ok(activity.includes(marker), `missing ${marker}`);
  }
});


test('payment fee values flow from the canonical backend response into the Flutter model without UI recalculation', () => {
  const view = read('backend/src/application/view_helpers.js');
  const model = read('lib/core/transactions/payment.dart');
  const summary = read('lib/core/ui/premium_payment_summary.dart');

  assert.match(view, /fees:\s*\{\s*baseAmount:\s*payment\.baseAmount/);
  for (const field of ['baseAmount', 'employerFee', 'workerFee', 'platformFee', 'employerCharge', 'providerPayout']) {
    assert.ok(view.includes(field + ': payment.' + field), 'payment view is missing ' + field);
  }
  assert.match(model, /fees: map\['fees'\] is Map/);
  assert.match(model, /HopePaymentFees\.fromMap/);
  assert.match(summary, /final fees = payment\.fees;/);
  for (const field of ['employerFee', 'workerFee', 'platformFee', 'employerCharge', 'providerPayout']) {
    assert.ok(summary.includes('fees.' + field), 'payment summary does not display API field ' + field);
  }
  assert.doesNotMatch(summary, /calculatePaymentBreakdown|employerFeeRate|workerFeeRate/);
});

test('wallet and financial-insights API envelopes match the Flutter repositories', () => {
  const walletRoutes = read('backend/src/application/wallet_routes.js');
  const walletRepository = read('lib/core/transactions/wallet_repository.dart');
  const insightsRoutes = read('backend/src/routes/financial_insights_routes.js');
  const insightsRepository = read('lib/core/financial/financial_insights_repository.dart');

  assert.match(walletRoutes, /\{ wallet: wallet \|\|/);
  assert.match(walletRepository, /map\['wallet'\]/);
  assert.match(walletRoutes, /transactions: result\.items, nextCursor: result\.nextCursor/);
  assert.match(walletRepository, /map\['transactions'\]/);
  assert.match(walletRepository, /map\['nextCursor'\]/);
  assert.match(insightsRoutes, /sendJson\(res, 200, insights\)/);
  assert.match(insightsRepository, /\/wallet\/financial-insights\?months=\$safeMonths/);
  assert.match(insightsRepository, /HopeFinancialInsights\.fromMap/);
});

test('opportunity fee disclosures match backend fee policy in Persian and English', () => {
  const view = read('backend/src/application/view_helpers.js');
  const financial = read('backend/src/financial.js');
  const createPage = read('lib/features/marketplace/create_job_widgets.part.dart');
  const faCopy = read('lib/l10n/generated/app_localizations_fa.dart');
  const enCopy = read('lib/l10n/generated/app_localizations_en.dart');

  assert.match(view, /employerRate: 0\.10, candidateRate: 0\.10, model: 'PER_MISSION'/);
  assert.match(view, /employerRate: 0\.30, candidateRate: 0, model: 'FIRST_MONTH_SALARY'/);
  assert.match(financial, /employerFeeRate = normalizedKind === 'MISSION' \? 10 : 30/);
  assert.match(financial, /workerFeeRate = normalizedKind === 'MISSION' \? 10 : 0/);
  assert.match(createPage, /kind === 'MISSION'[\s\S]{0,180}copy_10_from_the_employer_and_10_from_the_candi_cf15dfa[\s\S]{0,150}copy_30_of_the_candidate_s_first_month_pay_is_c_d6da53b/);
  assert.match(faCopy, /۱۰٪ از کارفرما و ۱۰٪ از کارجو/);
  assert.match(faCopy, /۳۰٪ از دستمزد ماه اول کارجو از سمت کارفرما/);
  assert.match(enCopy, /10% from the employer and 10% from the candidate/);
  assert.match(enCopy, /30% of the candidate\\'s first-month pay is charged to the employer/);
});
test('customer financial copy does not expose implementation-only accounting terms', () => {
  const insightsPage = read('lib/features/financial/financial_insights_page.dart');
  const walletPage = read('lib/features/wallet/wallet_page.dart');

  assert.doesNotMatch(insightsPage, /\bledger\b|لجر|transaction reference|نوع مرجع تراکنش/i);
  assert.doesNotMatch(walletPage, /\bledger\b|لجر|Entry type|Reference type|نوع ثبت|نوع مرجع/i);
});
test('create opportunity UI preserves exact Toman input and recovers category/deadline dependencies', () => {
  const page = `${read('lib/features/marketplace/create_job_page.dart')}\n${read('lib/features/marketplace/create_job_widgets.part.dart')}`;
  const payload = read('lib/features/marketplace/create_job_payload.dart');
  const validator = read('lib/features/marketplace/create_job_validator.dart');

  assert.match(page, /FilteringTextInputFormatter\.digitsOnly/);
  assert.match(page, /LengthLimitingTextInputFormatter\(16\)/);
  assert.match(page, /suffixText: translate\('تومان', 'Toman'\)/);
  assert.match(page, /Future<void> _pickDeadline\(\)/);
  assert.match(page, /DateFormat\('yyyy-MM-dd'\)/);
  assert.match(page, /snapshot\.hasError/);
  assert.match(page, /_categoriesFuture = _loadCategories\(\)/);
  assert.match(payload, /'budgetMin': int\.parse\(input\.minBudget\.trim\(\)\)/);
  assert.match(payload, /'budgetMax': int\.parse\(input\.maxBudget\.trim\(\)\)/);
  assert.match(validator, /BigInt\.tryParse\(minRaw\)/);
  assert.match(validator, /min > max/);
  assert.match(validator, /9000000000000000/);
});


test('satisfaction UI surfaces the automatic dispute state without exposing free-form AI', () => {
  const repository = read('lib/core/jobs/job_satisfaction_repository.dart');
  const page = read('lib/features/jobs/job_satisfaction_page.dart');
  assert.ok(repository.includes('dispute'));
  assert.ok(page.includes('dispute') || page.includes('پرونده اختلاف'));
  assert.ok(page.includes('تا تعیین تکلیف') || page.includes('until it is resolved'));
});

test('admin entry always goes through identity verification', () => {
  const home = read('lib/features/home/home_page.dart');
  const access = read('lib/features/admin/admin_access_page.dart');
  const repository = read('lib/core/admin/admin_repository.dart');
  assert.ok(home.includes('HopeRoutes.adminAccess()'));
  assert.ok(access.includes('verifyPanelAccess'));
  assert.ok(repository.includes("'/admin/access'"));
});
