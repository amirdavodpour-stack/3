import 'package:flutter/material.dart';

import '../transactions/wallet.dart';
import '../marketplace/job.dart';
import '../theme/hope_v2_design.dart';
import 'components.dart';
import 'premium_components.dart';
import 'hope_display_formatters.dart';

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

  String _formatAmount(String value, BuildContext context) => HopeDisplayFormatter.amount(
        value,
        locale: Localizations.localeOf(context).languageCode,
      );

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
                          "${_formatAmount(amount, context)} ${_t(context, 'تومان', 'Toman')}",
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

/// Compact, data-preserving explanation of the internal money lifecycle.
/// Detailed balances remain in the wallet summary so fields are not repeated.
class HopeWalletFlowSignature extends StatelessWidget {
  const HopeWalletFlowSignature({
    super.key,
    required this.wallet,
  });

  final HopeWallet wallet;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final compact =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact &&
            !enlargedText;
    final currencyLabel = wallet.currency == 'TOMAN'
        ? _t(context, 'تومان داخلی', 'Internal Toman')
        : wallet.currency;
    const compactFa = ['دفترکل', 'رزرو', 'آزادسازی'];
    const compactEn = ['Ledger', 'Hold', 'Release'];
    final steps = <({Object icon, String fa, String en, Color color})>[
      (
        icon: HopeV2Icons.wallet,
        fa: 'ثبت دفترکل',
        en: 'Ledger entry',
        color: HopeV2Colors.primary,
      ),
      (
        icon: HopeV2Icons.protectedFunds,
        fa: 'رزرو تا تأیید',
        en: 'Hold for approval',
        color: HopeV2Colors.warningDark,
      ),
      (
        icon: HopeV2Icons.completed,
        fa: 'آزادسازی وجه',
        en: 'Release funds',
        color: HopeV2Colors.secondary,
      ),
    ];

    return PremiumPanel(
      key: const ValueKey('wallet-money-flow-signature'),
      glass: false,
      quiet: true,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 3 : 11,
        compact ? 10 : 12,
        compact ? 3 : 11,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (enlargedText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: HopeIcon(
                        HopeV2Icons.route,
                        size: 20,
                        color: HopeV2Colors.secondary,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _t(context, 'گردش وجه در دفترکل', 'Money flow in the ledger'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PremiumTag(
                  icon: HopeV2Icons.secure,
                  label: currencyLabel,
                  color: HopeV2Colors.success,
                ),
              ],
            )
          else
            Row(
              children: [
                HopeIcon(
                  HopeV2Icons.route,
                  size: compact ? 12 : 18,
                  color: HopeV2Colors.secondary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _t(
                      context,
                      compact ? 'گردش وجه' : 'گردش وجه در دفترکل',
                      compact ? 'Money flow' : 'Money flow in the ledger',
                    ),
                    style: (compact
                            ? Theme.of(context).textTheme.labelMedium
                            : Theme.of(context).textTheme.titleSmall)
                        ?.copyWith(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!compact)
                  PremiumTag(
                    icon: HopeV2Icons.secure,
                    label: currencyLabel,
                    color: HopeV2Colors.success,
                  ),
              ],
            ),
          if (!compact) const SizedBox(height: 6),
          if (!compact)
            Text(
              _t(
                context,
                compact
                  ? 'رزرو وجه تا تأیید کار'
                  : 'تغییرات موجودی در دفترکل داخلی ثبت می‌شود؛ وجه رزروشده پس از تأیید کار آزاد می‌شود.',
              compact
                  ? 'Funds held until work approval'
                  : 'Balance movements are recorded in the internal ledger; reserved funds are released after work approval.',
            ),
            maxLines: enlargedText ? null : (compact ? 1 : 2),
            overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: (compact
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.bodySmall)
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: compact ? 1.2 : 1.35,
                ),
          ),
          if (!compact) const SizedBox(height: 9),
          if (enlargedText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: steps[index].color.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(HopeV2Radii.md),
                      border: Border.all(
                        color: steps[index].color.withValues(alpha: .16),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: HopeIcon(
                            steps[index].icon,
                            size: 20,
                            color: steps[index].color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t(context, steps[index].fa, steps[index].en),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                for (var index = 0; index < steps.length; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(minHeight: compact ? 26 : 43),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 2 : 5,
                        vertical: compact ? 2 : 7,
                      ),
                      decoration: BoxDecoration(
                        color: steps[index].color.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(HopeV2Radii.md),
                        border: Border.all(
                          color: steps[index].color.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HopeIcon(
                            steps[index].icon,
                            size: compact ? 12 : 16,
                            color: steps[index].color,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _t(
                                context,
                                compact ? compactFa[index] : steps[index].fa,
                                compact ? compactEn[index] : steps[index].en,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.clip,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Target-aligned opportunity DNA signature. It only surfaces attributes
/// that are already present in the real opportunity model.
class HopeOpportunityDnaSignature extends StatelessWidget {
  const HopeOpportunityDnaSignature({
    super.key,
    required this.job,
    this.includeBudget = true,
    this.includeMatch = true,
  });

  final HopeJob job;
  final bool includeBudget;
  final bool includeMatch;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _categoryLabel(BuildContext context, String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return '—';
    const fa = <String, String>{
      'software': 'نرم‌افزار',
      'design': 'طراحی',
      'marketing': 'بازاریابی',
      'content': 'محتوا و ترجمه',
      'finance': 'مالی و حسابداری',
      'education': 'آموزش',
      'support': 'پشتیبانی',
      'construction': 'ساخت‌وساز و فنی',
      'video': 'تولید ویدیو و صدا',
      'ai': 'داده و هوش مصنوعی',
      'data': 'داده و هوش مصنوعی',
      'sales': 'فروش',
      'other': 'سایر',
    };
    const en = <String, String>{
      'نرم‌افزار': 'Software',
      'طراحی': 'Design',
      'بازاریابی': 'Marketing',
      'محتوا و ترجمه': 'Content & Translation',
      'مالی و حسابداری': 'Finance & Accounting',
      'آموزش': 'Education',
      'پشتیبانی': 'Support',
      'ساخت‌وساز و فنی': 'Construction & Technical',
      'تولید ویدیو و صدا': 'Video & Audio',
      'داده و هوش مصنوعی': 'Data & AI',
      'فروش': 'Sales',
      'سایر': 'Other',
    };
    final faValue = fa[value.toLowerCase()] ?? value;
    return Localizations.localeOf(context).languageCode == 'en'
        ? (en[faValue] ?? faValue)
        : faValue;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const secondary = HopeV2Colors.secondary;
    final dimensions = <({String label, String value, Color color})>[
      (
        label: _t(context, 'نوع همکاری', 'Work mode'),
        value: _workMode(context),
        color: primary,
      ),
      (
        label: _t(context, 'دسته‌بندی', 'Category'),
        value: _categoryLabel(context, job.category?.trim().isNotEmpty == true
            ? job.category
            : job.categoryId),
        color: secondary,
      ),
      (
        label: _t(context, 'مکان', 'Location'),
        value: job.city?.trim().isNotEmpty == true
            ? job.city!.trim()
            : _t(context, 'دورکاری', 'Remote'),
        color: HopeV2Colors.secondary,
      ),
      if (includeMatch)
        (
          label: _t(context, 'تطبیق', 'Match'),
          value: job.recommendationScore == null
              ? _t(context, 'ثبت نشده', 'Not scored')
              : '${job.recommendationScore!.clamp(0, 100).round()}%',
          color: primary,
        ),
      (
        label: _t(context, 'بودجه', 'Budget'),
        value: job.isMission
            ? [job.budgetMin, job.budgetMax]
                .where((v) => v?.trim().isNotEmpty == true)
                .join(' – ')
            : (job.monthlySalary ?? job.budgetMin ?? '—'),
        color: HopeV2Colors.warning,
      ),
    ];
    if (!includeBudget) dimensions.removeLast();

    return PremiumPanel(
      key: const ValueKey('opportunity-dna-signature'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      quiet: true,
      glass: false,
      semanticLabel: _t(
        context,
        'DNA فرصت بر اساس اطلاعات واقعی',
        'Opportunity DNA from real opportunity data',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HopeIcon(
                HopeV2Icons.insights,
                size: 19,
                color: HopeV2Colors.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _t(context, 'ویژگی‌های فرصت', 'Opportunity traits'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              PremiumTag(
                icon: HopeV2Icons.secure,
                label: _t(context, 'داده‌محور', 'Data-led'),
                color: HopeV2Colors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 400;
              final columns = constraints.maxWidth >= 560 ? 5 : 2;
              const gap = 7.0;
              final width = columns == 5
                  ? (constraints.maxWidth - gap * 4) / 5
                  : (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final dimension in dimensions)
                    SizedBox(
                      width: width,
                      child: Container(
                        constraints: BoxConstraints(minHeight: compact ? 50 : 58),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 9,
                          vertical: compact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: dimension.color.withValues(alpha: .055),
                          borderRadius: BorderRadius.circular(HopeV2Radii.md),
                          border: Border.all(color: dimension.color.withValues(alpha: .13)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dimension.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: HopeV2Colors.muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dimension.value.isEmpty ? '—' : dimension.value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ],
                        ),
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

  String _workMode(BuildContext context) {
    final raw = job.raw['workMode'] ??
        job.raw['mode'] ??
        job.raw['locationType'] ??
        job.raw['work_mode'];
    final value = raw?.toString().trim().toUpperCase();
    return switch (value) {
      'REMOTE' => _t(context, 'دورکاری', 'Remote'),
      'HYBRID' => _t(context, 'هیبریدی', 'Hybrid'),
      'ONSITE' || 'ON_SITE' => _t(context, 'حضوری', 'On-site'),
      _ => value == null || value.isEmpty ? '—' : raw.toString().trim(),
    };
  }
}