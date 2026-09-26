import 'package:flutter/material.dart';
import '../theme/hope_v2_design.dart';
import '../transactions/payment.dart';
import 'premium_components.dart';
import 'components.dart';

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
    return labels[payment.status] ??
        _label(context, 'نیازمند بررسی', 'Needs review');
  }

  String _label(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _money(BuildContext context, dynamic value) {
    if (value == null) return '—';
    final raw = '$value'.trim();
    final parsed = num.tryParse(raw);
    final normalized = parsed != null && parsed == parsed.truncate()
        ? parsed.toInt().toString()
        : raw;
    final amount = int.tryParse(normalized);
    if (amount == null) {
      return "$normalized ${_label(context, 'تومان', 'Toman')}";
    }
    final digits = amount.abs().toString();
    final parts = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      parts.insert(0, digits.substring(start, end));
    }
    final grouped = amount < 0 ? '-${parts.join(',')}' : parts.join(',');
    return "$grouped ${_label(context, 'تومان', 'Toman')}";
  }
  Object _statusIcon() {
    switch (payment.status) {
      case 'RELEASED':
        return HopeV2Icons.completed;
      case 'REFUNDED':
        return HopeV2Icons.transferIn;
      case 'HOLD_FAILED':
      case 'RELEASE_FAILED':
        return HopeV2Icons.error;
      case 'HELD':
        return HopeV2Icons.secure;
      default:
        return HopeV2Icons.payments;
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = payment.amount;
    final fees = payment.fees;
    final status = _statusLabel(context);
    return Semantics(
      container: true,
      label: _label(
        context,
        'وضعیت پرداخت: $status، مبلغ ${_money(context, amount)}',
        'Payment status: $status, amount ${_money(context, amount)}',
      ),
      child: PremiumPanel(
        padding: const EdgeInsets.all(HopeV2Spacing.lg),
        semanticLabel: _label(context, 'جزئیات پرداخت، $status', 'Payment details, $status'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HopeIcon(
                  _statusIcon(),
                  size: 22,
                  color: payment.status == 'RELEASED' || payment.status == 'REFUNDED'
                      ? HopeV2Colors.success
                      : payment.status.contains('FAILED')
                          ? HopeV2Colors.danger
                          : HopeV2Colors.primary,
                ),
                const SizedBox(width: HopeV2Spacing.sm),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (amount != null)
                  Text(
                    _money(context, amount),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
              ],
            ),
            if (fees != null) ...[
              const SizedBox(height: HopeV2Spacing.md),
              Wrap(
                spacing: HopeV2Spacing.md,
                runSpacing: HopeV2Spacing.sm,
                children: [
                  if (fees.employerCharge != null)
                    _Metric(
                      label: _label(context, 'مبلغ نهایی', 'Total charge'),
                      value: _money(context, fees.employerCharge),
                    ),
                  if (fees.providerPayout != null)
                    _Metric(
                      label: _label(context, 'دریافتی مجری', 'Provider payout'),
                      value: _money(context, fees.providerPayout),
                    ),
                  if (fees.platformFee != null)
                    _Metric(
                      label: _label(context, 'کارمزد پلتفرم', 'Platform fee'),
                      value: _money(context, fees.platformFee),
                    ),
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
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}
