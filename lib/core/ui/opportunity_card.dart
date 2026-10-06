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
enum OpportunityCardVariant { compact, standard, featured, featuredScan, expanded }

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
    final featuredScan = variant == OpportunityCardVariant.featuredScan;
    final expanded = variant == OpportunityCardVariant.expanded;
    final copy = HopeCopy.of(context);
    final city = job.city?.trim().isNotEmpty == true ? job.city! : copy.copy_remote_dcbb625;
    final amount = job.isMission
        ? [job.budgetMin, job.budgetMax].where((v) => v?.isNotEmpty == true).join(' – ')
        : (job.monthlySalary ?? job.budgetMin ?? '');
    final title = job.title.trim().isEmpty ? copy.copy_untitled_d89410e : job.title;
    final primary = featured
        ? HopeV2Colors.primary
        : (job.isMission ? HopeV2Colors.primary : secondaryAccent(context));
    final reasons = [
      ...job.aiRecommendationReasons,
      ...job.recommendationReasons,
    ].take(3).toList(growable: false);
    final mediaUrl = _mediaUrl(job);

    return Semantics(
      button: true,
      label: '$title, $city${amount.isEmpty ? '' : ', $amount'}',
      child: PressableScale(
        onTap: onTap ?? () => Navigator.push(context, HopeRoutes.jobDetail(job)),
        child: Container(
          decoration: BoxDecoration(
            gradient: featured || featuredScan
                ? LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [
                            primary.withValues(alpha: .10),
                            const Color(0xFF101522),
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
              HopeV2Radii.lg,
            ),
            border: Border.all(
              color: featured || featuredScan
                  ? primary.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? (featuredScan ? .18 : .21)
                          : .18,
                    )
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: .055)
                      : HopeV2Surfaces.border(context).withValues(alpha: .60)),
            ),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? [
                    if (featured || featuredScan)
                      BoxShadow(
                        color: primary.withValues(alpha: .015),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                  ]
                : HopeV2Shadows.card,
          ),
          padding: EdgeInsets.all(
            featured ? 11 : (featuredScan ? 11 : (compact ? 11 : 13)),
          ),
          child: compact
              ? _compact(context, title, city, amount, primary, mediaUrl, copy)
              : _standard(
                  context,
                  title,
                  city,
                  amount,
                  primary,
                  reasons,
                  expanded,
                  featured,
                  featuredScan,
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

  // Premium runtime certification: featured opportunity bloom is restrained.
  // Runtime certification: featured card glow is intentionally restrained.
  // Runtime certification: featured card stays compact and neon-free.
  Widget _mediaHeader(
    BuildContext context, {
    required String title,
    required Color primary,
    required String? mediaUrl,
    required double? score,
    required bool featured,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final percent = score == null ? null : (score <= 1 ? score * 100 : score);
    return ClipRRect(
      borderRadius: BorderRadius.circular(HopeV2Radii.lg),
      child: SizedBox(
        key: const ValueKey('opportunity-media-header'),
        height: featured
            ? (MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium ? 148 : 166)
            : (MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium ? 88 : 104),
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
                      Colors.black.withValues(alpha: .06),
                      Colors.black.withValues(alpha: .18),
                      Colors.black.withValues(alpha: dark ? .58 : .46),
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
                    : '${percent.round()}% ${_t(context, 'تطابق', 'match')}',
                color: HopeV2Colors.secondaryDark,
                inverse: true,
              ),
            ),
            PositionedDirectional(
              start: 14,
              end: 14,
              bottom: 9,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  height: 1.08,
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
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: [
            primary.withValues(alpha: .34),
            const Color(0xFF151A31),
            const Color(0xFF090C14),
          ],
          stops: const [0, .44, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            end: -28,
            top: -36,
            child: Container(
              width: 150,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .11),
                ),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: BorderDirectional(
                            start: i == 0
                                ? BorderSide.none
                                : BorderSide(
                                    color: Colors.white.withValues(alpha: .06),
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: -22,
            bottom: -30,
            child: Container(
              width: 105,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: HopeV2Colors.secondary.withValues(alpha: .08),
                border: Border.all(
                  color: HopeV2Colors.secondary.withValues(alpha: .12),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 16,
            bottom: 16,
            child: Container(
              width: 82,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .07),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 24,
            bottom: 24,
            child: Container(
              width: 44,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.center,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: .20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .13),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: .18),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: const Center(
                child: HopeIcon(
                  HopeV2Icons.featured,
                  color: Colors.white,
                  size: 20,
                  strokeWidth: 1.6,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topCenter,
                  end: AlignmentDirectional.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .02),
                    Colors.black.withValues(alpha: .20),
                    Colors.black.withValues(alpha: .52),
                  ],
                  stops: const [0, .55, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compact(
    BuildContext context,
    String title,
    String city,
    String amount,
    Color primary,
    String? mediaUrl,
    HopeCopy copy,
  ) {
    final media = ClipRRect(
      borderRadius: BorderRadius.circular(HopeV2Radii.md),
      child: SizedBox(
        width: 70,
        height: 70,
        child: mediaUrl != null && mediaUrl.trim().isNotEmpty
            ? Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackMedia(context, primary),
              )
            : _fallbackMedia(context, primary),
      ),
    );
    return Row(
      children: [
        media,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (amount.isNotEmpty) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${_formatAmount(amount)} ${copy.copy_toman}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: primary,
              ),
            ),
          ),
        ],
        const SizedBox(width: 4),
        HugeIcon(
          icon: Directionality.of(context) == ui.TextDirection.rtl
              ? HopeV2Icons.arrowLeft
              : HopeV2Icons.arrowRight,
          size: 18,
          color: primary,
          strokeWidth: 1.9,
        ),
      ],
    );
  }

  Widget _featuredStandard(
    BuildContext context, {
    required String title,
    required String city,
    required String amount,
    required Color primary,
    required double? score,
    required String? mediaUrl,
    required HopeCopy copy,
  }) {
    final company = _companyName();
    final mode = _workMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mediaHeader(
          context,
          title: title,
          primary: primary,
          mediaUrl: mediaUrl,
          score: score,
          featured: true,
        ),
        const SizedBox(height: HopeV2Spacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrowMeta = constraints.maxWidth < 280;
            final tags = Wrap(
              spacing: HopeV2Spacing.sm,
              runSpacing: HopeV2Spacing.xs,
              children: [
                PremiumTag(
                  icon: job.isMission ? HopeV2Icons.mission : HopeV2Icons.job,
                  label: job.isMission
                      ? copy.copy_mission_fb4c5e1
                      : copy.copy_job_ce2feba,
                  color: primary,
                ),
                if (company != null)
                  PremiumTag(
                    icon: HopeV2Icons.profile,
                    label: company,
                    color: HopeV2Colors.muted,
                  ),
                if (mode != null)
                  PremiumTag(
                    icon: HopeV2Icons.workshop,
                    label: mode,
                    color: secondaryAccent(context),
                  ),
                PremiumTag(
                  icon: HopeV2Icons.location,
                  label: city,
                  color: secondaryAccent(context),
                ),
              ],
            );

            final amountText = amount.isEmpty
                ? null
                : Text(
                    '${_formatAmount(amount)} ${copy.copy_toman}',
                    maxLines: narrowMeta ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: HopeV2Type.metric(context).copyWith(
                      fontSize: narrowMeta ? 14 : 15,
                      color: primary,
                    ),
                  );

            if (narrowMeta) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tags,
                  if (amountText != null) ...[
                    const SizedBox(height: HopeV2Spacing.xs),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: amountText,
                      ),
                    ),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: tags),
                if (amountText != null) ...[
                  const SizedBox(width: HopeV2Spacing.sm),
                  Flexible(child: amountText),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: HopeV2Spacing.sm),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
          // The whole opportunity card is already the interaction surface.
          // Featured opportunity gets one intentional action emphasis; list cards stay de-boxed.
          decoration: BoxDecoration(
            color: primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(HopeV2Radii.button),
            border: Border.all(color: primary.withValues(alpha: .24)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium
                      ? _t(context, 'مشاهده جزئیات', 'View details')
                      : (job.isMission
                          ? copy.copy_view_and_act_on_mission
                          : copy.copy_view_details_and_act),
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
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
    bool featuredScan,
    String? mediaUrl,
    HopeCopy copy,
  ) {
    if (featured) {
      return _featuredStandard(
        context,
        title: title,
        city: city,
        amount: amount,
        primary: primary,
        score: job.recommendationScore,
        mediaUrl: mediaUrl,
        copy: copy,
      );
    }

    if (featuredScan) {
      return _scanStandard(
        context,
        title: title,
        city: city,
        amount: amount,
        primary: primary,
        mediaUrl: mediaUrl,
        copy: copy,
      );
    }

    if (!expanded) {
      return _scanStandard(
        context,
        title: title,
        city: city,
        amount: amount,
        primary: primary,
        mediaUrl: mediaUrl,
        copy: copy,
      );
    }

    return _expandedStandard(
      context,
      title: title,
      city: city,
      amount: amount,
      primary: primary,
      reasons: reasons,
      mediaUrl: mediaUrl,
      copy: copy,
    );
  }

  String? _rawText(List<String> keys) {
    for (final key in keys) {
      final value = job.raw[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _companyName() => _rawText(
        const ['companyName', 'employerName', 'ownerName', 'company'],
      );

  String? _workMode(BuildContext context) {
    final value = _rawText(
      const ['workMode', 'mode', 'locationType', 'work_mode'],
    );
    if (value == null) return null;
    return switch (value.toUpperCase()) {
      'REMOTE' => _t(context, 'دورکاری', 'Remote'),
      'HYBRID' => _t(context, 'هیبریدی', 'Hybrid'),
      'ONSITE' || 'ON_SITE' => _t(context, 'حضوری', 'On-site'),
      _ => value,
    };
  }

  String? _matchLabel(BuildContext context) {
    final score = job.recommendationScore;
    if (score == null) return null;
    final percent = score <= 1 ? score * 100 : score;
    return "${percent.round()} ${_t(context, 'تطابق', 'match')}";
  }

  Widget _scanStandard(
    BuildContext context, {
    required String title,
    required String city,
    required String amount,
    required Color primary,
    required String? mediaUrl,
    required HopeCopy copy,
  }) {
    final company = _companyName();
    final mode = _workMode(context);
    final match = _matchLabel(context);
    final compactViewport =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final mediaSize = compactViewport ? 72.0 : 88.0;
    final media = ClipRRect(
      borderRadius: BorderRadius.circular(HopeV2Radii.md),
      child: SizedBox(
        width: mediaSize,
        height: mediaSize,
        child: mediaUrl != null && mediaUrl.trim().isNotEmpty
            ? Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _fallbackMedia(context, primary),
              )
            : _fallbackMedia(context, primary),
      ),
    );

    final tags = Wrap(
      spacing: HopeV2Spacing.sm,
      runSpacing: HopeV2Spacing.xs,
      children: [
        if ((job.category ?? '').isNotEmpty)
          PremiumTag(
            icon: HopeV2Icons.category,
            label: job.category!,
            color: HopeV2Colors.muted,
          ),
        if (job.visibility == 'SPECIALIZED')
          PremiumTag(
            icon: HopeV2Icons.secure,
            label: copy.copy_specialized_5d1ca04,
            color: HopeV2Colors.warning,
          ),
        if (job.distanceKm != null)
          PremiumTag(
            icon: HopeV2Icons.distance,
            label: '${job.distanceKm!.toStringAsFixed(1)} km',
            color: secondaryAccent(context),
          ),
      ],
    );

    final meta = <Widget>[
      if (mode != null)
        _metaText(
          context,
          HopeV2Icons.workshop,
          mode,
          secondaryAccent(context),
        ),
      if (amount.isNotEmpty)
        _metaText(
          context,
          HopeV2Icons.payments,
          '${_formatAmount(amount)} ${copy.copy_toman}',
          primary,
          emphasize: true,
        ),
      if (city.trim().isNotEmpty)
        _metaText(
          context,
          HopeV2Icons.location,
          city,
          secondaryAccent(context),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            media,
            SizedBox(width: compactViewport ? 8 : HopeV2Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: HopeV2Spacing.xs,
                    runSpacing: HopeV2Spacing.xs,
                    children: [
                      PremiumTag(
                        label: job.isMission
                            ? copy.copy_mission_fb4c5e1
                            : copy.copy_job_ce2feba,
                        icon: job.isMission
                            ? HopeV2Icons.mission
                            : HopeV2Icons.job,
                        color: primary,
                      ),
                      if (match != null)
                        PremiumTag(
                          icon: HopeV2Icons.match,
                          label: match,
                          color: HopeV2Colors.success,
                        ),
                    ],
                  ),
                  const SizedBox(height: HopeV2Spacing.xs),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                  ),
                  if (company != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (meta.isNotEmpty) ...[
          SizedBox(height: compactViewport ? 5 : 7),
          if (compactViewport && amount.isNotEmpty && city.trim().isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: _metaText(
                    context,
                    HopeV2Icons.payments,
                    '${_formatAmount(amount)} ${copy.copy_toman}',
                    primary,
                    emphasize: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metaText(
                    context,
                    HopeV2Icons.location,
                    city,
                    secondaryAccent(context),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: HopeV2Spacing.sm,
              runSpacing: HopeV2Spacing.xs,
              children: meta,
            ),
          if (compactViewport && mode != null) ...[
            const SizedBox(height: 4),
            _metaText(
              context,
              HopeV2Icons.workshop,
              mode,
              secondaryAccent(context),
            ),
          ],
        ],
        if (tags.children.isNotEmpty && !compactViewport) ...[
          SizedBox(height: HopeV2Spacing.sm),
          tags,
        ],
        SizedBox(height: compactViewport ? 6 : HopeV2Spacing.sm),
        Container(
          key: const ValueKey('opportunity-card-cta'),
          constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
          padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 8, 7),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: .055),
            borderRadius: BorderRadius.circular(HopeV2Radii.button),
            border: Border.all(color: primary.withValues(alpha: .12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  compactViewport
                      ? _t(context, 'مشاهده جزئیات', 'View details')
                      : (job.isMission
                          ? copy.copy_view_and_act_on_mission
                          : copy.copy_view_details_and_act),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              HugeIcon(
                icon: Directionality.of(context) == ui.TextDirection.rtl
                    ? HopeV2Icons.arrowLeft
                    : HopeV2Icons.arrowRight,
                size: 19,
                color: primary,
                strokeWidth: 1.9,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaText(
    BuildContext context,
    dynamic icon,
    String label,
    Color color, {
    bool emphasize = false,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: icon,
            size: 15,
            color: color,
            strokeWidth: 1.8,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: emphasize ? color : null,
                    fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedStandard(
    BuildContext context, {
    required String title,
    required String city,
    required String amount,
    required Color primary,
    required List<String> reasons,
    required String? mediaUrl,
    required HopeCopy copy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mediaHeader(
          context,
          title: title,
          primary: primary,
          mediaUrl: mediaUrl,
          score: job.recommendationScore,
          featured: false,
        ),
        const SizedBox(height: HopeV2Spacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mediaUrl != null && mediaUrl.trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(HopeV2Radii.md),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Image.network(
                    mediaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => HopeIconTile(
                      job.isMission ? HopeV2Icons.mission : HopeV2Icons.job,
                      color: primary,
                      filled: true,
                      size: 46,
                    ),
                  ),
                ),
              )
            else
              HopeIconTile(
                job.isMission ? HopeV2Icons.mission : HopeV2Icons.job,
                color: primary,
                filled: true,
                size: 46,
              ),
            const SizedBox(width: HopeV2Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: HopeV2Spacing.xs,
                    runSpacing: HopeV2Spacing.xs,
                    children: [
                      PremiumTag(
                        label: job.isMission
                            ? copy.copy_mission_fb4c5e1
                            : copy.copy_job_ce2feba,
                        icon: job.isMission
                            ? HopeV2Icons.mission
                            : HopeV2Icons.job,
                        color: primary,
                      ),
                      if (job.recommendationScore != null)
                        PremiumTag(
                          icon: HopeV2Icons.match,
                          label: '${((job.recommendationScore! <= 1
                                      ? job.recommendationScore! * 100
                                      : job.recommendationScore!))
                                  .round()}% ${_t(context, 'تطابق', 'match')}',
                          color: HopeV2Colors.success,
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
        const SizedBox(height: HopeV2Spacing.sm),
        Wrap(
          spacing: HopeV2Spacing.sm,
          runSpacing: HopeV2Spacing.xs,
          children: [
            PremiumTag(
              icon: HopeV2Icons.location,
              label: city,
              color: secondaryAccent(context),
            ),
            if ((job.category ?? '').isNotEmpty)
              PremiumTag(
                icon: HopeV2Icons.category,
                label: job.category!,
                color: HopeV2Colors.muted,
              ),
            if (job.distanceKm != null)
              PremiumTag(
                icon: HopeV2Icons.distance,
                label: '${job.distanceKm!.toStringAsFixed(1)} km',
                color: secondaryAccent(context),
              ),
            if (job.visibility == 'SPECIALIZED')
              PremiumTag(
                icon: HopeV2Icons.secure,
                label: copy.copy_specialized_5d1ca04,
                color: HopeV2Colors.warning,
              ),
          ],
        ),
        if (amount.isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.md),
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
              children: [
                HugeIcon(
                  icon: HopeV2Icons.payments,
                  color: primary,
                  size: 19,
                  strokeWidth: 1.9,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.isMission
                            ? copy.copy_mission_budget_923bb6e
                            : copy.copy_monthly_salary_1d770dc,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatAmount(amount)} ${copy.copy_toman}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HopeV2Type.metric(context).copyWith(
                          fontSize: 18,
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
          const SizedBox(height: HopeV2Spacing.sm),
          Text(
            copy.copy_match_signals,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: HopeV2Spacing.xs),
          Wrap(
            spacing: HopeV2Spacing.sm,
            runSpacing: HopeV2Spacing.sm,
            children: reasons
                .map(
                  (r) => PremiumTag(
                    icon: HopeV2Icons.completed,
                    label: _reason(context, r),
                    color: primary,
                  ),
                )
                .toList(),
          ),
        ],
        if (job.description.trim().isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.md),
          Text(
            job.description.trim(),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: HopeV2Spacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                job.isMission
                    ? copy.copy_view_and_act_on_mission
                    : copy.copy_view_details_and_act,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
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
