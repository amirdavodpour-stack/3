import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../marketplace/job.dart';
import '../router/app_routes.dart';
import '../theme/hope_v2_design.dart';
import 'components.dart';
import 'hope_l10n.dart';
import 'premium_components.dart';

// Core marketplace card pattern for the HOPE visual system.
enum OpportunityCardVariant { compact, standard, featured, expanded }

class _MatchBadge extends StatelessWidget {
  const _MatchBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final value = (score <= 1 ? score * 100 : score).clamp(0, 100);
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: HopeV2Colors.secondary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(HopeV2Radii.pill),
        border: Border.all(
          color: HopeV2Colors.secondary.withValues(alpha: .24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: HopeV2Colors.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            value.round().toString() + '% ' + _t(context, 'تطابق', 'match'),
            style: const TextStyle(
              color: HopeV2Colors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;
}

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
  String _reason(BuildContext context, String value) {
    final copy = HopeCopy.of(context);
    return switch (value) {
      'SKILL_MATCH' => copy.copy_match_skill,
      'CATEGORY_MATCH' => copy.copy_match_category,
      'VERY_NEAR' => copy.copy_match_very_near,
      'NEARBY' => copy.copy_near_1df6db0,
      'REMOTE' => copy.copy_remote_dcbb625,
      'WORK_MODE_MATCH' => copy.copy_match_work_mode,
      'SALARY_FIT' => copy.copy_match_salary_fit,
      'BEHAVIOR_MATCH' => copy.copy_match_preference_fit,
      'GENERAL_MATCH' => copy.copy_match_general_fit,
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final compact = variant == OpportunityCardVariant.compact;
    final featured = variant == OpportunityCardVariant.featured;
    final expanded = variant == OpportunityCardVariant.expanded;
    final copy = HopeCopy.of(context);
    final city = job.city?.trim().isNotEmpty == true ? job.city! : copy.copy_remote_dcbb625;
    final amount = job.isMission
        ? [job.budgetMin, job.budgetMax].where((v) => v?.isNotEmpty == true).join(' – ')
        : (job.monthlySalary ?? job.budgetMin ?? '');
    final title = job.title.trim().isEmpty ? copy.copy_untitled_d89410e : job.title;
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
              ? _compact(context, title, city, amount, primary, copy)
              : _standard(context, title, city, amount, primary, reasons, expanded, featured, copy),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context, String title, String city, String amount, Color primary, HopeCopy copy) {
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
          Directionality.of(context) == ui.TextDirection.rtl
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
          semanticLabel: copy.copy_view_details,
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
    HopeCopy copy,
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
                  Row(
                    children: [
                      Flexible(
                        child: PremiumTag(
                          label: featured
                              ? _t(context, 'پیشنهاد ویژه', 'Best match')
                              : (job.isMission
                                  ? copy.copy_mission_fb4c5e1
                                  : copy.copy_job_ce2feba),
                          icon: featured
                              ? Icons.auto_awesome_rounded
                              : (job.isMission
                                  ? Icons.bolt_rounded
                                  : Icons.business_center_rounded),
                          color: primary,
                        ),
                      ),
                      if (featured && job.recommendationScore != null) ...[
                        const SizedBox(width: 8),
                        _MatchBadge(score: job.recommendationScore!),
                      ],
                    ],
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
              PremiumTag(icon: Icons.lock_outline_rounded, label: copy.copy_specialized_5d1ca04, color: HopeV2Colors.warning),
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
                        job.isMission ? copy.copy_mission_budget_923bb6e : copy.copy_monthly_salary_1d770dc,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatAmount(amount)} ${copy.copy_toman}',
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
          Text(copy.copy_match_signals, style: Theme.of(context).textTheme.labelLarge),
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
            Expanded(child: Text(job.isMission ? copy.copy_view_and_act_on_mission : copy.copy_view_details_and_act, style: Theme.of(context).textTheme.bodyMedium)),
            Icon(
              Directionality.of(context) == ui.TextDirection.rtl
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              size: 20,
              color: primary,
              semanticLabel: copy.copy_view_details,
            ),
          ],
        ),
      ],
    );
  }
}
