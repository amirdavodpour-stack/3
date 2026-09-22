import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../evidence/evidence_picker.dart';
import '../../core/uploads/upload_queue.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/transactions/payment.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/ui/copy.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_async_state.dart';
import 'transaction_controller.dart';
import '../../core/marketplace/job.dart';
part 'transaction_evidence.part.dart';
part 'transaction_widgets.part.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({
    super.key,
    required this.repository,
    required this.uploadQueue,
    required this.jobId,
  });
  final TransactionRepository repository;
  final UploadQueue uploadQueue;
  final String jobId;
  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  HopePayment? payment;
  bool loading = true;
  String? error;
  int _refreshRequestId = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final requestId = ++_refreshRequestId;
    try {
      if (mounted) {
        setState(() {
          loading = true;
          error = null;
        });
      }
      final data = await TransactionController(
              repository: widget.repository, jobId: widget.jobId)
          .load();
      if (mounted && requestId == _refreshRequestId) {
        setState(() {
          payment = data;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && requestId == _refreshRequestId) {
        setState(() => error = apiErrorMessage(e,
            fallback: HopeCopy.of(context).copy_operation_failed_eb38c4c));
      }
    }
    if (mounted && requestId == _refreshRequestId) {
      setState(() => loading = false);
    }
  }

  Future<void> action(String operation) async {
    setState(() => loading = true);
    try {
      final next = await TransactionController(
              repository: widget.repository, jobId: widget.jobId)
          .execute(operation);
      if (mounted) {
        setState(() => payment = next);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(HopeCopy.of(context).copy_operation_completed_66dd356)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(apiErrorMessage(e,
                fallback:
                    HopeCopy.of(context).copy_operation_failed_eb38c4c))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  bool _isOwner(HopeJob? job) =>
      context.read<AuthController>().user?['id']?.toString() == job?.ownerId?.toString();

  String _jobStatusLabel(String? raw) => switch (raw?.toUpperCase()) {
        'DRAFT' => _t('پیش‌نویس', 'Draft'),
        'PUBLISHED' => _t('منتشر شده', 'Published'),
        'FUNDED' => _t('تأمین وجه شده', 'Funded'),
        'IN_PROGRESS' => _t('در حال انجام', 'In progress'),
        'DELIVERED' => _t('تحویل شده', 'Delivered'),
        'UNDER_REVIEW' => _t('در حال بررسی', 'Under review'),
        'COMPLETED' => _t('تکمیل شده', 'Completed'),
        'CANCELLED' => _t('لغو شده', 'Cancelled'),
        _ => _t('نیازمند بررسی', 'Needs review'),
      };

  bool _isProvider(HopeJob? job) =>
      context.read<AuthController>().user?['id']?.toString() == job?.providerId?.toString();

  Color _statusColor(String status) {
    return switch (status) {
      'RELEASED' || 'REFUNDED' => AppColors.success,
      'HOLD_FAILED' || 'RELEASE_FAILED' => AppColors.danger,
      'HOLD_PENDING' || 'RELEASE_PENDING' || 'REFUND_PENDING' => AppColors.warning,
      _ => AppColors.primary,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'RELEASED' || 'REFUNDED' => Icons.check_circle_outline_rounded,
      'HOLD_FAILED' || 'RELEASE_FAILED' => Icons.error_outline_rounded,
      'HOLD_PENDING' || 'RELEASE_PENDING' || 'REFUND_PENDING' => Icons.schedule_rounded,
      'HELD' => Icons.lock_clock_rounded,
      _ => Icons.account_balance_wallet_outlined,
    };
  }

  String _statusHint(String status) => switch (status) {
        'NO_TRANSACTION' => _t('برای شروع، پرداخت این کار را تأمین کنید.', 'Fund this payment to start the financial flow.'),
        'HOLD_PENDING' => _t('در حال تأیید تأمین وجه است؛ از ارسال دوباره عملیات خودداری کنید.', 'Funding is being confirmed. Do not submit it again.'),
        'HELD' => _t('وجه تا زمان تکمیل و تأیید کار در امانت نگه داشته می‌شود.', 'Funds remain held until the work is completed and approved.'),
        'HOLD_FAILED' => _t('تأمین وجه کامل نشده است؛ وضعیت را دوباره بررسی کنید.', 'Funding did not complete. Refresh the status before retrying.'),
        'REFUND_PENDING' => _t('درخواست بازپرداخت ثبت شده و در حال پردازش است.', 'The refund request is being processed.'),
        'REFUNDED' => _t('وجه این چرخه به کارفرما بازگردانده شده است.', 'The funds for this cycle have been returned to the client.'),
        'RELEASE_PENDING' => _t('تسویه در صف پردازش است.', 'Settlement is being processed.'),
        'RELEASE_FAILED' => _t('تسویه کامل نشده؛ پیش از اقدام مجدد وضعیت را بررسی کنید.', 'Settlement did not complete. Check the status before retrying.'),
        'RELEASED' => _t('این چرخه کامل شده و مبلغ به کیف پول مجری رسیده است.', 'This cycle is complete and the provider has been settled.'),
        _ => _t('وضعیت مالی را می‌توانید از همین صفحه پیگیری کنید.', 'You can track the financial state from this page.'),
      };

  String _statusLabel(String status) => switch (status) {
        'NO_TRANSACTION' => _t('بدون تأمین وجه', 'Not funded'),
        'HOLD_PENDING' => _t('تأمین وجه در حال انجام', 'Funding in progress'),
        'HELD' => _t('وجه در امانت', 'Funds held'),
        'HOLD_FAILED' => _t('تأمین وجه ناموفق', 'Funding failed'),
        'REFUND_PENDING' => _t('بازپرداخت در حال انجام', 'Refund pending'),
        'REFUNDED' => _t('بازپرداخت انجام شد', 'Refunded'),
        'RELEASE_PENDING' => _t('تسویه در حال انجام', 'Settlement pending'),
        'RELEASE_FAILED' => _t('تسویه ناموفق', 'Settlement needs retry'),
        'RELEASED' => _t('تسویه نهایی شد', 'Settled'),
        _ => _t('نیازمند بررسی', 'Needs review'),
      };

  int _stepFor(HopeJob? job, String paymentStatus) {
    if (paymentStatus == 'RELEASED') return 5;
    if (job?.status == 'COMPLETED') return 4;
    if (job?.status == 'DELIVERED' || job?.status == 'UNDER_REVIEW') return 3;
    if (job?.status == 'IN_PROGRESS') return 2;
    if (paymentStatus == 'HELD' || job?.status == 'FUNDED') return 1;
    if (paymentStatus == 'HOLD_PENDING' || paymentStatus == 'HOLD_FAILED') return 0;
    return -1;
  }

  Future<void> _confirmAction(String operation) async {
    final fa = operation == 'refund'
        ? ('بازپرداخت وجه', 'بازگشت وجه انجام شود؟ پس از ثبت، وضعیت مالی این کار تغییر می‌کند.')
        : ('عملیات مالی', 'این عملیات روی وضعیت مالی کار اثر می‌گذارد.') ;
    final en = operation == 'refund'
        ? ('Request refund', 'Request a refund for the held funds? The financial state will change.')
        : ('Financial action', 'This action changes the financial state of this job.');
    final title = _t(fa.$1, en.$1);
    final message = _t(fa.$2, en.$2);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('تأیید', 'Confirm')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await action(operation);
  }

  Future<void> _jobAction(String operation) async {
    if (loading || payment?.job == null) return;
    setState(() => loading = true);
    try {
      final controller = TransactionController(
        repository: widget.repository,
        jobId: widget.jobId,
      );
      await controller.executeJob(operation);
      if (!mounted) return;
      // Job commands can atomically advance the payment as well (for example
      // Approve & complete moves HELD -> RELEASE_PENDING). Refresh the
      // aggregate instead of patching only the job, otherwise the CTA/state
      // panel can remain stale until the user manually refreshes.
      await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('وضعیت کار به‌روزرسانی شد.', 'Job state updated.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(apiErrorMessage(
            e,
            fallback: _t(
              'این عملیات در وضعیت فعلی مجاز نیست.',
              'This action is not allowed in the current state.',
            ),
          )),
        ),
      );
      await refresh();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) => _buildPage(context);
}

Widget _moneyRow(BuildContext context, String label, dynamic value, {bool strong = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              moneyLabel(context, value ?? '—'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
