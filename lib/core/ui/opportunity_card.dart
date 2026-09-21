import 'package:flutter/material.dart';

import '../marketplace/job.dart';
import '../router/app_routes.dart';
import '../theme/app_theme.dart';
import '../theme/hope_v2_design.dart';
import 'components.dart';
import 'premium_components.dart';

// Core marketplace card pattern for the HOPE visual system.
enum OpportunityCardVariant { compact, standard, featured, expanded }

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.job,
    this.variant = OpportunityCardVariant.standard,
    this.onTap,
  });

  final HopeJob job;
  final OpportunityCardVariant variant;
  final VoidCallback? onTap;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _reason(BuildContext context, String value) {
    const fa = {
      'SKILL_MATCH': 'مهارت مرتبط',
      'CATEGORY_MATCH': 'دسته‌بندی مرتبط',
      'VERY_NEAR': 'خیلی نزدیک',
      'NEARBY': 'نزدیک',
      'REMOTE': 'قابل انجام آنلاین',
      'WORK_MODE_MATCH': 'نوع همکاری مناسب',
      'SALARY_FIT': 'تناسب درآمد',
      'BEHAVIOR_MATCH': 'متناسب با ترجیحات',
      'GENERAL_MATCH': 'تناسب کلی',
    };
    const en = {
      'SKILL_MATCH': 'Skill match',
      'CATEGORY_MATCH': 'Category match',
      'VERY_NEAR': 'Very near',
      'NEARBY': 'Nearby',
      'REMOTE': 'Remote',
      'WORK_MODE_MATCH': 'Work mode fit',
      'SALARY_FIT': 'Salary fit',
      'BEHAVIOR_MATCH': 'Preference fit',
      'GENERAL_MATCH': 'General fit',
    };
    return (Localizations.localeOf(context).languageCode == 'en'
            ? en[value]
            : fa[value]) ??
        value;
  }

  @override
  Widget build(BuildContext context) {
    final compact = variant == OpportunityCardVariant.compact;
    final featured = variant == OpportunityCardVariant.featured;
    final expanded = variant == OpportunityCardVariant.expanded;
    final city = job.city?.trim().isNotEmpty == true ? job.city! : _t(context, 'آنلاین', 'Online');
    final amount = job.isMission
        ? [job.budgetMin, job.budgetMax].where((v) => v?.isNotEmpty == true).join(' – ')
        : (job.monthlySalary ?? job.budgetMin ?? '');
    final title = job.title.trim().isEmpty ? _t(context, 'فرصت بدون عنوان', 'Untitled opportunity') : job.title;
    final primary = job.isMission ? HopeV2Colors.primary : secondaryAccent(context);
    final reasons = job.recommendationReasons.take(3).toList(growable: false);

    return Semantics(
      button: true,
      label: '$title, $city${amount.isEmpty ? '' : ', $amount'}',
      child: PressableScale(
        onTap: onTap ?? () => Navigator.push(context, HopeRoutes.jobDetail(job)),
        child: Container(
          decoration: BoxDecoration(
            gradient: featured
                ? LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      primary.withValues(alpha: .09),
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surface,
                    ],
                    stops: const [0, .34, 1],
                  )
                : null,
            color: featured ? null : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(
              featured ? HopeV2Radii.xl : HopeV2Radii.lg,
            ),
            border: Border.all(
              color: featured
                  ? primary.withValues(alpha: .24)
                  : HopeV2Surfaces.border(context),
            ),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? const []
                : HopeV2Shadows.card,
          ),
          padding: EdgeInsets.all(compact ? HopeV2Spacing.md : HopeV2Spacing.lg),
          child: compact
              ? _compact(context, title, city, amount, primary)
              : _standard(context, title, city, amount, primary, reasons, expanded, featured),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, String title, String city, String amount, Color primary) {
    return Row(
      children: [
        HopeIconTile(job.isMission ? Icons.bolt_rounded : Icons.business_center_rounded, color: primary, filled: true, size: 46),
        const SizedBox(width: HopeV2Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 3),
              Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (amount.isNotEmpty) ...[
          const SizedBox(width: HopeV2Spacing.md),
          Flexible(child: Text(amount, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w800, color: primary))),
        ],
        const SizedBox(width: 4),
        Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          semanticLabel: _t(context, 'مشاهده جزئیات', 'View details'),
        ),
      ],
    );
  }

  Widget _standard(
    BuildContext context,
    String title,
    String city,
    String amount,
    Color primary,
    List<String> reasons,
    bool expanded,
    bool featured,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HopeIconTile(
              job.isMission
                  ? Icons.bolt_rounded
                  : Icons.business_center_rounded,
              color: primary,
              filled: true,
              size: featured ? 50 : 46,
            ),
            const SizedBox(width: HopeV2Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumTag(
                    label: job.isMission
                        ? _t(context, 'ماموریت', 'Mission')
                        : _t(context, 'استخدام', 'Job'),
                    icon: job.isMission
                        ? Icons.bolt_rounded
                        : Icons.business_center_rounded,
                    color: primary,
                  ),
                  const SizedBox(height: HopeV2Spacing.sm),
                  Text(
                    title,
                    maxLines: featured ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: featured
                        ? HopeV2Type.hero(context)
                        : Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: HopeV2Spacing.md),
        Wrap(
          spacing: HopeV2Spacing.sm,
          runSpacing: HopeV2Spacing.sm,
          children: [
            PremiumTag(icon: Icons.location_on_outlined, label: city, color: secondaryAccent(context)),
            if ((job.category ?? '').isNotEmpty)
              PremiumTag(icon: Icons.category_outlined, label: job.category!, color: HopeV2Colors.muted),
            if (job.distanceKm != null)
              PremiumTag(icon: Icons.near_me_rounded, label: '${job.distanceKm!.toStringAsFixed(1)} km', color: secondaryAccent(context)),
            if (job.visibility == 'SPECIALIZED')
              PremiumTag(icon: Icons.lock_outline_rounded, label: _t(context, 'تخصصی', 'Specialized'), color: HopeV2Colors.warning),
          ],
        ),
        if (amount.isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: HopeV2Spacing.md,
              vertical: HopeV2Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(HopeV2Radii.md),
              border: Border.all(color: primary.withValues(alpha: .12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, color: primary, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.isMission
                            ? _t(context, 'مبلغ پروژه', 'Project budget')
                            : _t(context, 'درآمد ماهانه', 'Monthly compensation'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${amount} ${_t(context, 'تومان', 'Toman')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: featured ? 22 : 19,
                          fontWeight: FontWeight.w900,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.md),
          Text(_t(context, 'دلایل تطابق', 'Match signals'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: HopeV2Spacing.xs),
          Wrap(
            spacing: HopeV2Spacing.sm,
            runSpacing: HopeV2Spacing.sm,
            children: reasons.map((r) => PremiumTag(icon: Icons.check_circle_outline_rounded, label: _reason(context, r), color: primary)).toList(),
          ),
        ],
        if (expanded && job.description.trim().isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.lg),
          Text(job.description.trim(), maxLines: 5, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: HopeV2Spacing.lg),
        Row(
          children: [
            Expanded(child: Text(job.isMission ? _t(context, 'مشاهده و اقدام برای ماموریت', 'View and act on mission') : _t(context, 'مشاهده جزئیات و اقدام', 'View details and act'), style: Theme.of(context).textTheme.bodyMedium)),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              size: 20,
              color: primary,
              semanticLabel: _t(context, 'مشاهده جزئیات', 'View details'),
            ),
          ],
        ),
      ],
    );
  }
}
