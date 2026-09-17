import 'package:flutter/material.dart';
import '../theme/hope_v2_design.dart';
import '../transactions/payment.dart';
import 'premium_components.dart';

class PremiumPaymentSummary extends StatelessWidget {
  const PremiumPaymentSummary({super.key, required this.payment});

  final HopePayment payment;

  String _statusLabel(BuildContext context) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    final labels = en ? <String, String>{
      'HELD': 'Funds held',
      'HOLD_PENDING': 'Funding in progress',
      'RELEASE_PENDING': 'Settlement pending',
      'RELEASED': 'Settled',
      'REFUNDED': 'Refunded',
      'HOLD_FAILED': 'Funding failed',
      'RELEASE_FAILED': 'Settlement needs retry',
      'NO_TRANSACTION': 'Not funded yet',
    } : <String, String>{
      'HELD': 'وجه در امانت',
      'HOLD_PENDING': 'تأمین وجه در حال انجام',
      'RELEASE_PENDING': 'در انتظار تسویه',
      'RELEASED': 'تسویه شده',
      'REFUNDED': 'بازپرداخت شده',
      'HOLD_FAILED': 'خطا در تأمین وجه',
      'RELEASE_FAILED': 'نیازمند تلاش مجدد',
      'NO_TRANSACTION': 'هنوز تأمین نشده',
    };
    return labels[payment.status] ?? payment.status;
  }

  String _label(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _money(BuildContext context, String? value, String currency) {
    if (value == null || value.trim().isEmpty) return '—';
    final raw = value.trim();
    final grouped = RegExp(r'^\d+$').hasMatch(raw)
        ? raw.replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (_) => ',')
        : raw;
    final unit = currency == 'TOMAN' ? _label(context, 'تومان', 'TOMAN') : currency;
    return '$grouped $unit';
  }

  IconData _statusIcon() {
    switch (payment.status) {
      case 'RELEASED':
        return Icons.check_circle_rounded;
      case 'REFUNDED':
        return Icons.undo_rounded;
      case 'HOLD_FAILED':
      case 'RELEASE_FAILED':
        return Icons.error_outline_rounded;
      case 'HELD':
        return Icons.lock_clock_rounded;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = payment.amount;
    final fees = payment.fees;
    final currency = (fees?.currency.isNotEmpty == true ? fees!.currency : 'TOMAN').toUpperCase();
    final status = _statusLabel(context);
    return Semantics(
      container: true,
      label: _label(context, 'وضعیت پرداخت: $status، مبلغ ${_money(context, amount, currency)}', 'Payment status: $status, amount ${_money(context, amount, currency)}'),
      child: PremiumPanel(
        padding: const EdgeInsets.all(HopeV2Spacing.lg),
        semanticLabel: _label(context, 'جزئیات پرداخت، $status', 'Payment details, $status'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon(), size: 22),
                const SizedBox(width: HopeV2Spacing.sm),
                Expanded(
                  child: Text(status,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (amount != null)
                  Text(_money(context, amount, currency),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            if (fees != null) ...[
              const SizedBox(height: HopeV2Spacing.md),
              Wrap(
                spacing: HopeV2Spacing.md,
                runSpacing: HopeV2Spacing.sm,
                children: [
                  if (fees.employerCharge != null)
                    _Metric(label: _label(context, 'مبلغ نهایی', 'Total charge'), value: _money(context, fees.employerCharge, currency)),
                  if (fees.providerPayout != null)
                    _Metric(label: _label(context, 'دریافتی مجری', 'Provider payout'), value: _money(context, fees.providerPayout, currency)),
                  if (fees.platformFee != null)
                    _Metric(label: _label(context, 'کارمزد پلتفرم', 'Platform fee'), value: _money(context, fees.platformFee, currency)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(HopeV2Radii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
