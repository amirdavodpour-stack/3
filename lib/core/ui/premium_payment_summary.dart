import 'package:flutter/material.dart';
import '../theme/hope_v2_design.dart';
import '../transactions/payment.dart';
import 'hope_display_formatters.dart';
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
    final locale = Localizations.localeOf(context).languageCode;
    final raw = '$value'.trim();
    final integralDecimal = RegExp(r'^([+-]?\d+)\.0+$').firstMatch(raw);
    final normalized = integralDecimal?.group(1) ?? raw;
    final parsed = HopeDisplayFormatter.parseInteger(normalized);
    if (parsed == null) return '—';
    return '${HopeDisplayFormatter.integer(parsed, locale: locale)} '
        '${_label(context, 'تومان', 'Toman')}';
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

  Color _statusColor(BuildContext context) {
    final status = payment.status.toUpperCase();
    if (status == 'RELEASED' || status == 'REFUNDED') {
      return HopeV2SemanticColors.success(context);
    }
    if (status.contains('FAILED')) {
      return HopeV2SemanticColors.error(context);
    }
    return HopeV2SemanticColors.pending(context);
  }

  @override
  Widget build(BuildContext context) {
    final amount = payment.amount;
    final fees = payment.fees;
    final baseAmount = fees?.baseAmount ?? amount;
    final employerCharge = fees?.employerCharge;
    final workerPayout = fees?.providerPayout;
    final status = _statusLabel(context);
    final semanticSeparator =
        Localizations.localeOf(context).languageCode == 'en' ? ', ' : '، ';
    final semanticLabel = <String>[
      _label(context, 'وضعیت پرداخت: $status', 'Payment status: $status'),
      '${_label(context, 'مبلغ پایه', 'Base amount')} ${_money(context, baseAmount)}',
      if (fees?.employerFee != null)
        '${_label(context, 'کارمزد کارفرما', 'Employer fee')} ${_money(context, fees!.employerFee)}',
      if (fees?.workerFee != null)
        '${_label(context, 'کارمزد کارجو', 'Worker fee')} ${_money(context, fees!.workerFee)}',
      if (employerCharge != null)
        '${_label(context, 'مبلغ پرداختی کارفرما', 'Employer charge')} ${_money(context, employerCharge)}',
      if (workerPayout != null)
        '${_label(context, 'دریافتی کارجو', 'Worker payout')} ${_money(context, workerPayout)}',
      if (fees?.platformFee != null)
        '${_label(context, 'کارمزد پلتفرم', 'Platform fee')} ${_money(context, fees!.platformFee)}',
    ].join(semanticSeparator);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: PremiumPanel(
        quiet: true,
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
        highlight: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HopeIcon(
                  _statusIcon(),
                  key: const ValueKey('premium-payment-status-icon'),
                  size: 22,
                  color: _statusColor(context),
                ),
                const SizedBox(width: HopeV2Spacing.sm),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (baseAmount != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _label(context, 'مبلغ پایه', 'Base amount'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _money(context, baseAmount),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: HopeV2SemanticColors.price(context),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (fees != null) ...[
              const SizedBox(height: HopeV2Spacing.md),
              Wrap(
                spacing: HopeV2Spacing.md,
                runSpacing: HopeV2Spacing.sm,
                children: [
                  if (fees.employerFee != null)
                    _Metric(
                      label: _label(context, 'کارمزد کارفرما', 'Employer fee'),
                      value: _money(context, fees.employerFee),
                    ),
                  if (fees.workerFee != null)
                    _Metric(
                      label: _label(context, 'کارمزد کارجو', 'Worker fee'),
                      value: _money(context, fees.workerFee),
                    ),
                  if (fees.employerCharge != null)
                    _Metric(
                      label: _label(context, 'مبلغ پرداختی کارفرما', 'Employer charge'),
                      value: _money(context, fees.employerCharge),
                    ),
                  if (fees.providerPayout != null)
                    _Metric(
                      label: _label(context, 'دریافتی کارجو', 'Worker payout'),
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
          color: HopeV2Surfaces.panelSoft(context),
          borderRadius: BorderRadius.circular(HopeV2Radii.sm),
          border: Border.all(
            color: HopeV2Surfaces.border(context).withValues(
              alpha: Theme.of(context).brightness == Brightness.dark ? .38 : .68,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? HopeV2Colors.darkMuted
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: HopeV2SemanticColors.price(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}