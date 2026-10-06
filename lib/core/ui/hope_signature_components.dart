import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../transactions/wallet.dart';
import '../theme/hope_v2_design.dart';
import 'components.dart';
import 'premium_components.dart';

/// Shared visual signature for the creation flow. It mirrors only values that
/// the user has already entered; it never invents marketplace data.
class HopeOpportunityLivePreview extends StatelessWidget {
  const HopeOpportunityLivePreview({
    super.key,
    required this.kind,
    required this.visibility,
    required this.schedule,
    required this.city,
    required this.titleController,
    required this.descriptionController,
    required this.minBudgetController,
    required this.maxBudgetController,
    required this.salaryController,
  });

  final String kind;
  final String visibility;
  final String schedule;
  final String city;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController minBudgetController;
  final TextEditingController maxBudgetController;
  final TextEditingController salaryController;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _formatAmount(String value) {
    final formatter = NumberFormat.decimalPattern('en_US');
    return value
        .split(' – ')
        .map((part) {
          final trimmed = part.trim();
          final parsed = int.tryParse(trimmed);
          return parsed == null ? part : formatter.format(parsed);
        })
        .join(' – ');
  }

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge(<Listenable>[
      titleController,
      descriptionController,
      minBudgetController,
      maxBudgetController,
      salaryController,
    ]);

    return AnimatedBuilder(
      animation: merged,
      builder: (context, _) {
        final isJob = kind.toUpperCase() == 'JOB';
        final title = titleController.text.trim();
        final description = descriptionController.text.trim();
        final minBudget = minBudgetController.text.trim();
        final maxBudget = maxBudgetController.text.trim();
        final salary = salaryController.text.trim();
        final amount = isJob
            ? salary
            : [minBudget, maxBudget]
                .where((value) => value.isNotEmpty)
                .join(' – ');
        final cityText = city.trim();
        final visibilityLabel = visibility.toUpperCase() == 'SPECIALIZED'
            ? _t(context, 'تخصصی', 'Specialized')
            : _t(context, 'عمومی', 'Public');

        return PremiumPanel(
          key: const ValueKey('opportunity-live-preview'),
          glass: false,
          quiet: true,
          highlight: true,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          semanticLabel: _t(
            context,
            'پیش‌نمایش زنده فرصت',
            'Live opportunity preview',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HopeIconTile(
                    isJob ? HopeV2Icons.job : HopeV2Icons.mission,
                    size: 38,
                    filled: true,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, 'پیش‌نمایش زنده', 'LIVE PREVIEW'),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .7,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isJob
                              ? _t(context, 'فرصت شغلی', 'Job opportunity')
                              : _t(context, 'ماموریت', 'Mission'),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  PremiumTag(
                    icon: HopeV2Icons.route,
                    label: visibilityLabel,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                title.isEmpty
                    ? _t(context, 'عنوان فرصت شما', 'Your opportunity title')
                    : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HopeV2Colors.muted,
                        height: 1.35,
                      ),
                ),
              ],
              const SizedBox(height: 9),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (amount.isNotEmpty)
                    PremiumTag(
                      icon: HopeV2Icons.payments,
                      label:
                          "\${_formatAmount(amount)} \${_t(context, 'تومان', 'Toman')}",
                      color: HopeV2Colors.primary,
                    ),
                  if (cityText.isNotEmpty)
                    PremiumTag(
                      icon: HopeV2Icons.location,
                      label: cityText,
                      color: HopeV2Colors.secondary,
                    ),
                  if (isJob && schedule.trim().isNotEmpty)
                    PremiumTag(
                      icon: HopeV2Icons.activity,
                      label: schedule == 'PART_TIME'
                          ? _t(context, 'پاره‌وقت', 'Part time')
                          : _t(context, 'تمام‌وقت', 'Full time'),
                      color: HopeV2Colors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const HopeIcon(
                    HopeV2Icons.insights,
                    size: 15,
                    color: HopeV2Colors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _t(
                        context,
                        'با تغییر فرم، این پیش‌نمایش هم‌زمان به‌روز می‌شود.',
                        'This preview updates as you edit the form.',
                      ),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: HopeV2Colors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Financial signature used on the Wallet surface. Values are taken directly
/// from the internal ledger model, so the visual never implies a nonexistent
/// fee or external payout provider.
class HopeWalletFlowSignature extends StatelessWidget {
  const HopeWalletFlowSignature({
    super.key,
    required this.wallet,
  });

  final HopeWallet wallet;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _money(BuildContext context, int value) {
    return "\${NumberFormat.decimalPattern('en_US').format(value)} \${wallet.currency == 'TOMAN' ? _t(context, 'تومان', 'Toman') : wallet.currency}";
  }

  @override
  Widget build(BuildContext context) {
    final nodes = <({
      Object icon,
      String label,
      String value,
      Color color,
    })>[
      (
        icon: HopeV2Icons.wallet,
        label: _t(context, 'کل موجودی', 'Total'),
        value: _money(context, wallet.totalBalance),
        color: HopeV2Colors.primary,
      ),
      (
        icon: HopeV2Icons.protectedFunds,
        label: _t(context, 'محافظت‌شده', 'Protected'),
        value: _money(context, wallet.lockedBalance),
        color: HopeV2Colors.warningDark,
      ),
      (
        icon: HopeV2Icons.payments,
        label: _t(context, 'قابل استفاده', 'Available'),
        value: _money(context, wallet.availableBalance),
        color: HopeV2Colors.secondary,
      ),
      (
        icon: HopeV2Icons.completed,
        label: _t(context, 'وضعیت', 'Status'),
        value: wallet.isActive
            ? _t(context, 'فعال', 'Active')
            : wallet.status,
        color: wallet.isActive
            ? HopeV2Colors.success
            : HopeV2Colors.warning,
      ),
    ];

    return PremiumPanel(
      key: const ValueKey('wallet-money-flow-signature'),
      glass: false,
      quiet: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HopeIcon(
                HopeV2Icons.route,
                size: 18,
                color: HopeV2Colors.secondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _t(context, 'نمای مالی دفترکل', 'Ledger flow'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              PremiumTag(
                icon: HopeV2Icons.secure,
                label: _t(
                  context,
                  'داخلی و محافظت‌شده',
                  'Internal & protected',
                ),
                color: HopeV2Colors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 4 : 2;
              const gap = 7.0;
              final width = columns == 4
                  ? (constraints.maxWidth - gap * 3) / 4
                  : (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final node in nodes)
                    SizedBox(
                      width: width,
                      child: _FlowNode(
                        icon: node.icon,
                        label: node.label,
                        value: node.value,
                        color: node.color,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final Object icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(HopeV2Radii.md),
        border: Border.all(color: color.withValues(alpha: .13)),
      ),
      child: Row(
        children: [
          HopeIcon(icon, size: 17, color: color, strokeWidth: 1.9),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: HopeV2Colors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
