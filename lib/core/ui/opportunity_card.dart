import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
        color: HopeV2Colors.orange.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(HopeV2Radii.pill),
        border: Border.all(
          color: HopeV2Colors.orange.withValues(alpha: .28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HopeV2Icons.match,
            size: 14,
            color: HopeV2Colors.orange,
            strokeWidth: 1.9,
          ),
          const SizedBox(width: 5),
          Text(
            value.round().toString() + '% ' + _t(context, 'تطابق', 'match'),
            style: const TextStyle(
              color: HopeV2Colors.orange,
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

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

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
    final mediaUrl = _mediaUrl(job);

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
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            const Color(0xFF171A2B),
                            const Color(0xFF10131F),
                            Theme.of(context).colorScheme.surface,
                          ]
                        : [
                            primary.withValues(alpha: .09),
                            Theme.of(context).colorScheme.surface,
                            Theme.of(context).colorScheme.surface,
                          ],
                    stops: const [0, .44, 1],
                  )
                : null,
            color: featured ? null : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(
              featured ? HopeV2Radii.xl : HopeV2Radii.lg,
            ),
            border: Border.all(
              color: featured
                  ? primary.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? .34
                          : .24,
                    )
                  : HopeV2Surfaces.border(context),
            ),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? [
                    if (featured)
                      BoxShadow(
                        color: primary.withValues(alpha: .13),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                  ]
                : HopeV2Shadows.card,
          ),
          padding: EdgeInsets.all(compact ? HopeV2Spacing.md : HopeV2Spacing.lg),
          child: compact
              ? _compact(context, title, city, amount, primary, copy)
              : _standard(
                  context,
                  title,
                  city,
                  amount,
                  primary,
                  reasons,
                  expanded,
                  featured,
                  mediaUrl,
                  copy,
                ),
        ),
      ),
    );
  }

  String? _mediaUrl(HopeJob job) {
    const keys = <String>[
      'imageUrl',
      'coverUrl',
      'thumbnailUrl',
      'image',
      'coverImage',
      'mediaUrl',
    ];
    for (final key in keys) {
      final value = job.raw[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Widget _mediaHeader(
    BuildContext context, {
    required String title,
    required Color primary,
    required String? mediaUrl,
    required double? score,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final percent = score == null ? null : (score <= 1 ? score * 100 : score);
    return ClipRRect(
      borderRadius: BorderRadius.circular(HopeV2Radii.lg),
      child: SizedBox(
        height: 168,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaUrl != null)
              Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackMedia(context, primary),
              )
            else
              _fallbackMedia(context, primary),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topCenter,
                    end: AlignmentDirectional.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: .08),
                      Colors.black.withValues(alpha: .22),
                      Colors.black.withValues(alpha: dark ? .64 : .50),
                    ],
                    stops: const [0, .48, 1],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: 10,
              top: 10,
              child: PremiumTag(
                icon: HopeV2Icons.featured,
                label: percent == null
                    ? _t(context, 'پیشنهاد ویژه', 'Featured')
                    : percent.round().toString() + '% ' + _t(context, 'تطابق', 'match'),
                color: HopeV2Colors.secondaryDark,
                inverse: true,
              ),
            ),
            PositionedDirectional(
              start: 14,
              end: 14,
              bottom: 11,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.06,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackMedia(BuildContext context, Color primary) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            primary.withValues(alpha: .62),
            const Color(0xFF17203A),
            const Color(0xFF080D18),
          ],
          stops: const [0, .48, 1],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -24,
            top: -38,
            child: Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .10),
              ),
            ),
          ),
          PositionedDirectional(
            start: -40,
            bottom: -62,
            child: Container(
              width: 172,
              height: 172,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: .10),
                ),
              ),
            ),
          ),
          Center(
            child: Opacity(
              opacity: .25,
              child: HopeIcon(
                HopeV2Icons.featured,
                color: Colors.white,
                size: 58,
                strokeWidth: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compact(BuildContext context, String title, String city, String amount, Color primary, HopeCopy copy) {
    return Row(
      children: [
        HopeIconTile(job.isMission ? HopeV2Icons.mission : HopeV2Icons.job, color: primary, filled: true, size: 46),
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
        HugeIcon(
          icon: Directionality.of(context) == ui.TextDirection.rtl
              ? HopeV2Icons.arrowLeft
              : HopeV2Icons.arrowRight,
          size: 19,
          color: primary,
          strokeWidth: 1.9,
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
    String? mediaUrl,
    HopeCopy copy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (featured || expanded) ...[
          _mediaHeader(
            context,
            title: title,
            primary: primary,
            mediaUrl: mediaUrl,
            score: job.recommendationScore,
          ),
          const SizedBox(height: HopeV2Spacing.md),
        ],
        if (!featured) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HopeIconTile(
                job.isMission
                    ? HopeV2Icons.mission
                    : HopeV2Icons.job,
                color: primary,
                filled: true,
                size: 46,
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
                            label: job.isMission
                                ? copy.copy_mission_fb4c5e1
                                : copy.copy_job_ce2feba,
                            icon: job.isMission
                                ? HopeV2Icons.mission
                                : HopeV2Icons.job,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HopeV2Spacing.sm),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: HopeV2Spacing.md),
        Wrap(
          spacing: HopeV2Spacing.sm,
          runSpacing: HopeV2Spacing.sm,
          children: [
            PremiumTag(icon: HopeV2Icons.location, label: city, color: secondaryAccent(context)),
            if ((job.category ?? '').isNotEmpty)
              PremiumTag(icon: HopeV2Icons.category, label: job.category!, color: HopeV2Colors.muted),
            if (job.distanceKm != null)
              PremiumTag(icon: HopeV2Icons.distance, label: '${job.distanceKm!.toStringAsFixed(1)} km', color: secondaryAccent(context)),
            if (job.visibility == 'SPECIALIZED')
              PremiumTag(icon: HopeV2Icons.secure, label: copy.copy_specialized_5d1ca04, color: HopeV2Colors.warning),
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
                HugeIcon(
                  icon: HopeV2Icons.payments,
                  color: primary,
                  size: 21,
                  strokeWidth: 1.9,
                ),
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
                        style: HopeV2Type.metric(context).copyWith(
                          fontSize: featured ? 22 : 20,
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
            children: reasons.map((r) => PremiumTag(icon: HopeV2Icons.completed, label: _reason(context, r), color: primary)).toList(),
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
            HugeIcon(
              icon: Directionality.of(context) == ui.TextDirection.rtl
                  ? HopeV2Icons.arrowLeft
                  : HopeV2Icons.arrowRight,
              size: 20,
              color: primary,
              strokeWidth: 1.9,
            ),
          ],
        ),
      ],
    );
  }
}
