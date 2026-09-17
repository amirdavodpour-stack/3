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
  assert.match(page, /Payment ID:/);
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
  assert.match(page, /ChoiceChip/);
  assert.match(page, /'CREDIT'/);
  assert.match(page, /'DEBIT'/);
  assert.match(page, /'HOLD'/);
  assert.match(page, /Pending payouts/);
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
  assert.match(page, /suffixText: 'TOMAN'/);
});

test('activity screen exposes a direct route from backend payment summary to transaction controls', () => {
  const page = read('lib/features/transactions/transactions_page.dart');
  assert.match(page, /FutureBuilder<HopePayment\?>/);
  assert.match(page, /PremiumPaymentSummary\(payment: payment\)/);
  assert.match(page, /HopeRoutes\.transaction\(/);
  assert.match(page, /context\.read<TransactionRepository>\(\)/);
  assert.match(page, /context\.read<UploadQueue>\(\)/);
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


test('create opportunity UI preserves exact Toman input and recovers category/deadline dependencies', () => {
  const page = `${read('lib/features/marketplace/create_job_page.dart')}\n${read('lib/features/marketplace/create_job_widgets.part.dart')}`;
  const payload = read('lib/features/marketplace/create_job_payload.dart');
  const validator = read('lib/features/marketplace/create_job_validator.dart');

  assert.match(page, /FilteringTextInputFormatter\.digitsOnly/);
  assert.match(page, /LengthLimitingTextInputFormatter\(16\)/);
  assert.match(page, /suffixText: (?:_t|translate)\('تومان', 'TOMAN'\)/);
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
