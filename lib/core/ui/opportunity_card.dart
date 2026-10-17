import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../marketplace/job.dart';
import '../router/app_routes.dart';
import '../theme/hope_v2_design.dart';
import 'components.dart';
import 'hope_display_formatters.dart';
import 'hope_l10n.dart';
import 'premium_components.dart';

// Core marketplace card pattern for the HOPE visual system.
enum OpportunityCardVariant { compact, compactGrid, standard, featured, featuredScan, expanded }

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

  String _formatAmount(String value, BuildContext context) =>
      HopeDisplayFormatter.amount(
        value,
        locale: Localizations.localeOf(context).languageCode,
      );

  ({int lower, int upper})? _parseCompactRange(String value) {
    final parts = value.trim().split(RegExp(r'\s*[–-]\s*'));
    if (parts.length != 2) return null;
    final first = HopeDisplayFormatter.parseInteger(parts.first);
    final second = HopeDisplayFormatter.parseInteger(parts.last);
    if (first == null || second == null) return null;
    return first <= second
        ? (lower: first, upper: second)
        : (lower: second, upper: first);
  }

  // Compact cards keep both exact bounds together and display the currency
  // unit once, after the range. This reduces noise without rounding values.
  String _formatCompactRangeAmount(String value, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final range = _parseCompactRange(value);
    if (range == null) return _formatAmount(value, context);
    if (range.lower == range.upper) {
      return HopeDisplayFormatter.money(range.lower, locale: locale);
    }
    return '${HopeDisplayFormatter.integer(range.lower, locale: locale)} '
        '${_t(context, 'تا', '–')} '
        '${HopeDisplayFormatter.integer(range.upper, locale: locale)} '
        '${_t(context, 'تومان', 'TOMAN')}';
  }

  // Grid cards preserve the same exact range but stack the amounts to fit a
  // narrow two-column tile. The unit still appears once for quick scanning.
  String _formatCompactGridAmount(String value, BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final range = _parseCompactRange(value);
    if (range == null) return _formatAmount(value, context);
    if (range.lower == range.upper) {
      return HopeDisplayFormatter.money(range.lower, locale: locale);
    }
    return '${HopeDisplayFormatter.integer(range.lower, locale: locale)}\n'
        '${_t(context, 'تا', '–')} '
        '${HopeDisplayFormatter.integer(range.upper, locale: locale)}\n'
        '${_t(context, 'تومان', 'TOMAN')}';
  }
  String? _reason(BuildContext context, String value) =>
      hopeRecommendationReasonLabel(context, value);

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String? _knownCompactReasonLabel(BuildContext context, List<String> reasons) =>
      hopeFirstRecommendationReasonLabel(context, reasons);

  Widget? _compactMatchReasonTag(
    BuildContext context,
    List<String> reasons, {
    bool allowWrap = false,
  }) {
    final label = _knownCompactReasonLabel(context, reasons);
    if (label == null || label.trim().isEmpty) return null;
    return PremiumTag(
      key: const ValueKey('opportunity-card-match-reason'),
      icon: HopeV2Icons.insights,
      label: label,
      color: HopeV2SemanticColors.info(context),
      allowWrap: allowWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = variant == OpportunityCardVariant.compact;
    final compactGrid = variant == OpportunityCardVariant.compactGrid;
    final featured = variant == OpportunityCardVariant.featured;
    final featuredScan = variant == OpportunityCardVariant.featuredScan;
    final expanded = variant == OpportunityCardVariant.expanded;
    final copy = HopeCopy.of(context);
    final explicitWorkMode = _workMode(context);
    final city = job.city?.trim().isNotEmpty == true
        ? job.city!.trim()
        : (explicitWorkMode == _t(context, 'دورکاری', 'Remote')
            ? explicitWorkMode!
            : _t(context, 'مکان مشخص نشده', 'Location not specified'));
    final amount = job.isMission
        ? [job.budgetMin, job.budgetMax].where((v) => v?.isNotEmpty == true).join(' – ')
        : (job.monthlySalary?.isNotEmpty == true
            ? job.monthlySalary!
            : [job.budgetMin, job.budgetMax]
                .where((v) => v?.isNotEmpty == true)
                .join(' – '));
    final title = job.title.trim().isEmpty ? copy.copy_untitled_d89410e : job.title;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = featured || featuredScan || job.isMission
        ? (dark ? HopeV2Colors.primaryDark : HopeV2Colors.primary)
        : secondaryAccent(context);
    final reasons = [
      ...job.aiRecommendationReasons,
      ...job.recommendationReasons,
    ].take(3).toList(growable: false);
    final mediaUrl = _mediaUrl(job);
    final locale = Localizations.localeOf(context).languageCode;
    final categoryValue = _categoryValue();
    final category = categoryValue == null
        ? ''
        : hopeCategoryLabel(context, categoryValue);
    final opportunityKind = job.isMission
        ? _t(context, 'ماموریت', 'Mission')
        : _t(context, 'فرصت شغلی', 'Job');
    final matchPercent =
        HopeDisplayFormatter.matchPercentage(job.recommendationScore);
    final scoreLabel = matchPercent == null
        ? ''
        : '${HopeDisplayFormatter.percent(
            matchPercent.round(),
            locale: locale,
          )} ${_t(context, 'تطابق', 'match')}';
    final semanticAmount = compact || compactGrid
        ? _formatCompactRangeAmount(amount, context)
        : _formatAmount(amount, context);

    final cardAccent = _categoryArtwork(primary).accent;

    return PressableScale(
      semanticLabel: [
        title,
        opportunityKind,
        if (category.isNotEmpty) category,
        city,
        if (amount.isNotEmpty) semanticAmount,
        if (scoreLabel.isNotEmpty) scoreLabel,
      ].join(', '),
      onTap: onTap ?? () => Navigator.push(context, HopeRoutes.jobDetail(job)),
      child: Container(
        key: const ValueKey('opportunity-card-surface'),
        decoration: BoxDecoration(
          color: featured || featuredScan
              ? null
              : HopeV2Surfaces.panel(context),
          gradient: featured || featuredScan
              ? LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: dark
                      ? [
                          primary.withValues(alpha: .12),
                          HopeV2Colors.darkSurface,
                          Theme.of(context).colorScheme.surface,
                        ]
                      : [
                          primary.withValues(alpha: .06),
                          Theme.of(context).colorScheme.surface,
                          Theme.of(context).colorScheme.surface,
                        ],
                  stops: const [0, .44, 1],
                )
              : null,
          borderRadius: BorderRadius.circular(
            featured || featuredScan ? HopeV2Radii.md : HopeV2Radii.md,
          ),
          border: Border.all(
            color: featured || featuredScan
                ? primary.withValues(
                    alpha: dark
                        ? (featuredScan ? .18 : .21)
                        : .18,
                  )
                : (dark
                    ? HopeV2Colors.darkBorder
                    : HopeV2Surfaces.border(context)),
          ),
          boxShadow: featured || featuredScan
              ? [
                  BoxShadow(
                    color: dark
                        ? Colors.black.withValues(alpha: .20)
                        : cardAccent.withValues(alpha: .055),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  if (dark)
                    BoxShadow(
                      color: primary.withValues(alpha: .025),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                ]
              : const <BoxShadow>[],
        ),
        padding: EdgeInsets.all(
          (featured || featuredScan)
              ? (MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact
                  ? 5
                  : 8)
              : (compact
                  ? 7
                  : (compactGrid &&
                          MediaQuery.textScalerOf(context).scale(1) > 1.15
                      ? 3
                      : 6)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 5),
              child: compact
                  ? _compact(context, title, city, amount, primary, mediaUrl, copy)
                  : compactGrid
                      ? _compactGrid(
                          context,
                          title,
                          city,
                          amount,
                          primary,
                          mediaUrl,
                          copy,
                        )
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
            PositionedDirectional(
              start: 0,
              top: 6,
              bottom: 6,
              child: ExcludeSemantics(
                child: Container(
                  key: const ValueKey('opportunity-card-accent-rail'),
                  width: featured || featuredScan ? 3 : 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [
                        cardAccent.withValues(alpha: .28),
                        cardAccent.withValues(alpha: .88),
                        cardAccent.withValues(alpha: .42),
                      ],
                      stops: const [0, .52, 1],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: featured || featuredScan
                        ? [
                            BoxShadow(
                              color: cardAccent.withValues(alpha: .09),
                              blurRadius: 4,
                              offset: const Offset(0, 0),
                            ),
                          ]
                        : const <BoxShadow>[],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isWebImageUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String? _categoryValue() {
    final category = job.category?.trim();
    if (category != null && category.isNotEmpty) return category;
    final categoryId = job.categoryId?.trim();
    return categoryId != null && categoryId.isNotEmpty ? categoryId : null;
  }

  // Artwork variants use the stable taxonomy key, not localized display copy.
  String? _artworkCategoryValue() {
    final categoryId = job.categoryId?.trim();
    if (categoryId != null && categoryId.isNotEmpty) return categoryId;
    final category = job.category?.trim();
    return category != null && category.isNotEmpty ? category : null;
  }

  String _normalizedArtworkCategoryKey() =>
      (_artworkCategoryValue() ?? '')
          .trim()
          .toLowerCase()
          .replaceAll('_', '-')
          .replaceAll('  ', ' ');

  // One lookup keeps card framing and fallback illustration on the same
  // category identity; the palette is decorative, never a status or price cue.
  ({Color accent, Object icon, _CategoryArtworkStyle style})
      _categoryArtwork(Color fallback) {
    final categoryKey = _normalizedArtworkCategoryKey();
    return switch (categoryKey) {
      'software' ||
      'software-development' ||
      'development' ||
      'نرم‌افزار' ||
      'نرم افزار' => (
          accent: HopeV2OpportunityAccents.software,
          icon: HopeV2Icons.web,
          style: _CategoryArtworkStyle.software,
        ),
      'design' || 'graphic-design' || 'طراحی' => (
          accent: HopeV2OpportunityAccents.design,
          icon: HopeV2Icons.featured,
          style: _CategoryArtworkStyle.design,
        ),
      'marketing' || 'بازاریابی' => (
          accent: HopeV2OpportunityAccents.marketing,
          icon: HopeV2Icons.activity,
          style: _CategoryArtworkStyle.marketing,
        ),
      'content' ||
      'translation' ||
      'content-translation' ||
      'محتوا و ترجمه' => (
          accent: HopeV2OpportunityAccents.content,
          icon: HopeV2Icons.description,
          style: _CategoryArtworkStyle.content,
        ),
      'finance' ||
      'accounting' ||
      'finance-accounting' ||
      'مالی و حسابداری' => (
          accent: HopeV2OpportunityAccents.finance,
          icon: HopeV2Icons.payments,
          style: _CategoryArtworkStyle.finance,
        ),
      'education' || 'آموزش' => (
          accent: HopeV2OpportunityAccents.education,
          icon: HopeV2Icons.skills,
          style: _CategoryArtworkStyle.education,
        ),
      'support' || 'پشتیبانی' => (
          accent: HopeV2OpportunityAccents.support,
          icon: HopeV2Icons.message,
          style: _CategoryArtworkStyle.support,
        ),
      'construction' ||
      'technical' ||
      'construction-technical' ||
      'ساخت‌وساز و فنی' => (
          accent: HopeV2OpportunityAccents.construction,
          icon: HopeV2Icons.workshop,
          style: _CategoryArtworkStyle.construction,
        ),
      'video' ||
      'audio' ||
      'video-audio' ||
      'video-production' ||
      'تولید ویدیو و صدا' => (
          accent: HopeV2OpportunityAccents.media,
          icon: HopeV2Icons.device,
          style: _CategoryArtworkStyle.media,
        ),
      'data' ||
      'ai' ||
      'data-ai' ||
      'artificial-intelligence' ||
      'داده و هوش مصنوعی' => (
          accent: HopeV2OpportunityAccents.data,
          icon: HopeV2Icons.insights,
          style: _CategoryArtworkStyle.data,
        ),
      'sales' || 'فروش' => (
          accent: HopeV2OpportunityAccents.sales,
          icon: HopeV2Icons.activitySelected,
          style: _CategoryArtworkStyle.sales,
        ),
      _ => (
          accent: fallback,
          icon: HopeV2Icons.category,
          style: _CategoryArtworkStyle.general,
        ),
    };
  }

  // The detail cue is decorative; the entire card remains the single,
  // accessible tap target (minimum 48dp) and retains reduced-motion behavior.
  Widget _actionAffordance(BuildContext context) {
    final action = Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icon = Directionality.of(context) == ui.TextDirection.rtl
        ? HopeV2Icons.arrowLeft
        : HopeV2Icons.arrowRight;
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('opportunity-card-action-affordance'),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: action.withValues(alpha: dark ? .13 : .075),
          shape: BoxShape.circle,
          border: Border.all(
            color: action.withValues(alpha: dark ? .28 : .17),
          ),
        ),
        child: Center(
          child: HopeIcon( icon,
            size: 16,
            color: action,
            strokeWidth: 1.9,
          ),
        ),
      ),
    );
  }

  // Listing cards use only absolute HTTP(S) media from the opportunity payload.
  // When no usable media exists, the localized category identity becomes the visual fallback.
  String? _mediaUrl(HopeJob job) {
    final candidates = <dynamic>[
      job.raw['imageUrl'],
      job.raw['image_url'],
      job.raw['coverImageUrl'],
      job.raw['heroImageUrl'],
      job.raw['thumbnailUrl'],
      job.raw['mediaUrl'],
      job.raw['media_url'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        final value = candidate.trim();
        if (_isWebImageUrl(value)) return value;
      }
    }
    final media = job.raw['media'];
    if (media is List) {
      for (final item in media) {
        if (item is! Map) continue;
        for (final key in const ['url', 'src', 'imageUrl', 'image_url']) {
          final candidate = item[key];
          if (candidate is String && candidate.trim().isNotEmpty) {
            final value = candidate.trim();
            if (_isWebImageUrl(value)) return value;
          }
        }
      }
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
    bool showTitle = true,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasMedia = mediaUrl?.trim().isNotEmpty == true;
    final percent = HopeDisplayFormatter.matchPercentage(score);
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(HopeV2Radii.lg),
      child: SizedBox(
        key: const ValueKey('opportunity-media-header'),
        height: featured
            ? (hasMedia
                ? (MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact
                    ? 72
                    : (MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium
                        ? 84
                        : 96))
                : (MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium
                    ? 44
                    : 48))
            : (MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium
                ? 56
                : 64),
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaUrl != null)
              Image.network(
                mediaUrl,
                key: const ValueKey('opportunity-media-image'),
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
              start: 8,
              top: 8,
              child: PremiumTag(
                icon: HopeV2Icons.featured,
                label: percent == null
                    ? _t(context, 'پیشنهاد ویژه', 'Featured')
                    : '${HopeDisplayFormatter.percent(
                        percent.round(),
                        locale: Localizations.localeOf(context).languageCode,
                      )} ${_t(context, 'تطابق', 'match')}',
                color: HopeV2Colors.secondaryDark,
                inverse: true,
              ),
            ),
            if (showTitle && hasMedia && !enlargedText)
              PositionedDirectional(
                start: 12,
                end: 12,
                bottom: 8,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact ? 15.0 : 16.0,
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
    final categoryKey = _normalizedArtworkCategoryKey();
    final artwork = _categoryArtwork(primary);
    final accent = artwork.accent;
    final icon = artwork.icon;
    final artworkStyle = artwork.style;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final baseSurface =
        dark ? HopeV2Colors.darkCard : theme.colorScheme.surface;

    return DecoratedBox(
      key: const ValueKey('opportunity-fallback-media-surface'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: [
            accent.withValues(alpha: dark ? .13 : .075),
            baseSurface,
          ],
        ),
      ),
      child: CustomPaint(
        key: ValueKey('opportunity-fallback-category-artwork-$categoryKey'),
        painter: _CategoryFallbackPainter(
          style: artworkStyle,
          accent: accent,
          dark: dark,
        ),
        child: Center(
          child: Container(
            key: const ValueKey('opportunity-fallback-icon-container'),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: dark ? .07 : .04),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: dark ? .13 : .10),
              ),
            ),
            child: Center(
              child: HopeIcon(
                icon,
                color: accent.withValues(alpha: dark ? .92 : 1),
                size: 17,
                strokeWidth: 1.7,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactGrid(
    BuildContext context,
    String title,
    String city,
    String amount,
    Color primary,
    String? mediaUrl,
    HopeCopy copy,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final mediaHeight = 40.0;
    final categoryValue = _categoryValue();
    final category = categoryValue == null
        ? ''
        : hopeCategoryLabel(context, categoryValue);
    final match = _matchLabel(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enlargedText)
          Text(
            job.isMission ? copy.copy_mission_fb4c5e1 : copy.copy_job_ce2feba,
            key: const ValueKey('opportunity-card-compact-grid-kind'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: HopeV2SemanticColors.textSecondary(context),
                ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(HopeV2Radii.md),
            child: SizedBox(
              height: mediaHeight,
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
                  PositionedDirectional(
                    top: 5,
                    start: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: (dark ? Colors.black : Colors.white).withValues(alpha: .82),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        job.isMission ? copy.copy_mission_fb4c5e1 : copy.copy_job_ce2feba,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (match != null)
                    PositionedDirectional(
                      top: 5,
                      end: 5,
                      child: PremiumTag(
                        icon: HopeV2Icons.match,
                        label: match,
                        color: HopeV2SemanticColors.info(context),
                        inverse: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        SizedBox(height: enlargedText ? 2 : 4),
        Text(
          title,
          maxLines: enlargedText ? null : 2,
          softWrap: true,
          overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 14,
            height: 1.18,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (category.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            category,
            key: const ValueKey('opportunity-card-compact-grid-category'),
            maxLines: enlargedText ? null : 1,
            softWrap: true,
            overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: enlargedText ? 10.5 : 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
        SizedBox(height: enlargedText ? 2 : 3),
        Row(
          children: [
            HopeIcon(HopeV2Icons.location, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, strokeWidth: 1.8),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                city,
                key: const ValueKey('opportunity-card-compact-grid-location'),
                maxLines: enlargedText ? null : 1,
                softWrap: true,
                overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
        if (amount.isNotEmpty) ...[
          SizedBox(height: enlargedText ? 2 : 4),
          Text(
            _formatCompactGridAmount(amount, context),
            key: const ValueKey('opportunity-card-compact-grid-budget'),
            // At enlarged text sizes this visual variant becomes text-first and
            // the exact Toman range can grow naturally instead of clipping.
            maxLines: enlargedText ? null : 5,
            softWrap: true,
            overflow: enlargedText ? TextOverflow.visible : TextOverflow.clip,
            style: TextStyle(
              fontSize: enlargedText ? 11.5 : 10.5,
              height: 1.12,
              fontWeight: FontWeight.w900,
              color: HopeV2SemanticColors.amount(context),
            ),
          ),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Natural-height cards remain fully expanded in a Wrap. If a parent
        // imposes a finite tile height, large-text content becomes scrollable
        // rather than overflowing or truncating its title/financial range.
        if (enlargedText && constraints.hasBoundedHeight) {
          return SingleChildScrollView(child: content);
        }
        return content;
      },
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
    final locationColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final media = ClipRRect(
      key: const ValueKey('opportunity-compact-media'),
      borderRadius: BorderRadius.circular(HopeV2Radii.md),
      child: SizedBox(
        width: 72,
        height: 72,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        media,
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: enlargedText ? null : 2,
                softWrap: true,
                overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.24,
                    ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  HopeIcon(HopeV2Icons.location, size: 13, color: locationColor, strokeWidth: 1.8),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      city,
                      key: const ValueKey('opportunity-card-compact-location'),
                      maxLines: enlargedText ? null : 1,
                      softWrap: true,
                      overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: locationColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              if (amount.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _formatCompactRangeAmount(amount, context),
                  key: const ValueKey('opportunity-card-compact-budget'),
                  // Long Toman ranges can wrap each bound and unit separately
                  // at narrow widths and enlarged text. Let the text expand
                  // naturally rather than clipping any server-provided amount.
                  softWrap: true,
                  textAlign: TextAlign.start,
                  style: TextStyle(fontSize: 13, height: 1.2, fontWeight: FontWeight.w900, color: HopeV2SemanticColors.amount(context)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 4),
        _actionAffordance(context),
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
    required List<String> reasons,
  }) {
    final hasMedia = mediaUrl?.trim().isNotEmpty == true;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final matchReasonTag = _compactMatchReasonTag(context, reasons, allowWrap: enlargedText);
    final company = _companyName();
    final mode = _workMode(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _mediaHeader(
          context,
          title: title,
          primary: primary,
          mediaUrl: mediaUrl,
          score: score,
          featured: true,
          showTitle: hasMedia && !enlargedText,
        ),
        if (!hasMedia || enlargedText) ...[
          const SizedBox(height: 8),
          Text(
            title,
            key: const ValueKey('opportunity-featured-fallback-title'),
            maxLines: enlargedText ? null : 2,
            softWrap: true,
            overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: MediaQuery.sizeOf(context).width <
                          HopeV2Breakpoints.medium
                      ? 16
                      : 18,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrowMeta = constraints.maxWidth < 420;
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
                  allowWrap: enlargedText,
                ),
                if (matchReasonTag != null) matchReasonTag,
                if (company != null)
                  PremiumTag(
                    icon: HopeV2Icons.profile,
                    label: company,
                    color: HopeV2Colors.muted,
                    allowWrap: enlargedText,
                  ),
                if (mode != null && mode != city)
                  PremiumTag(
                    icon: HopeV2Icons.workshop,
                    label: mode,
                    color: secondaryAccent(context),
                    allowWrap: enlargedText,
                  ),
                PremiumTag(
                  icon: HopeV2Icons.location,
                  label: city,
                  color: secondaryAccent(context),
                  allowWrap: enlargedText,
                ),
              ],
            );

            final amountText = amount.isEmpty
                ? null
                : Text(
                    _formatAmount(amount, context),
                    key: const ValueKey('opportunity-card-standard-budget'),
                    maxLines: enlargedText ? null : 3,
                    overflow: enlargedText
                        ? TextOverflow.visible
                        : TextOverflow.clip,
                    softWrap: true,
                    textAlign: TextAlign.end,
                    style: HopeV2Type.metric(context).copyWith(
                      fontSize: narrowMeta ? 14 : 15,
                      color: HopeV2SemanticColors.amount(context),
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
        const SizedBox(height: 6),
        Semantics(
          container: true,
          label: MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium
              ? _t(context, 'مشاهده جزئیات فرصت', 'View opportunity details')
              : (job.isMission
                  ? copy.copy_view_and_act_on_mission
                  : copy.copy_view_details_and_act),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 2, 4),
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
                        color: HopeV2SemanticColors.textPrimary(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _actionAffordance(context),
                ],
              ),
            ),
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
    if (featuredScan) {
      return _featuredScanStandard(
        context,
        title: title,
        city: city,
        amount: amount,
        primary: primary,
        mediaUrl: mediaUrl,
        copy: copy,
        reasons: reasons,
      );
    }

    if (featured && MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact) {
      return _scanStandard(
        context,
        title: title,
        city: city,
        amount: amount,
        primary: primary,
        mediaUrl: mediaUrl,
        copy: copy,
        reasons: reasons,
        showMatchRationale: true,
      );
    }

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
        reasons: reasons,
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
        reasons: reasons,
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
    final percent =
        HopeDisplayFormatter.matchPercentage(job.recommendationScore);
    if (percent == null) return null;
    return "${HopeDisplayFormatter.percent(
      percent.round(),
      locale: Localizations.localeOf(context).languageCode,
    )} ${_t(context, 'تطابق', 'match')}";
  }

  Widget _featuredScanStandard(
    BuildContext context, {
    required String title,
    required String city,
    required String amount,
    required Color primary,
    required String? mediaUrl,
    required HopeCopy copy,
    required List<String> reasons,
  }) {
    final compactViewport =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final mediaSize = compactViewport ? 56.0 : 68.0;
    final categoryValue = _categoryValue();
    final category = categoryValue == null
        ? ''
        : hopeCategoryLabel(context, categoryValue);
    final match = _matchLabel(context);
    final mode = _workMode(context);
    final matchReasonTag = _compactMatchReasonTag(context, reasons, allowWrap: enlargedText);
    // Keep the first scan-line calm on phone widths. Type, specialized
    // visibility, category and match remain the highest-signal metadata;
    // secondary rationale is available lower in the card when space allows.
    final tags = <Widget>[
      PremiumTag(
        icon: job.isMission ? HopeV2Icons.mission : HopeV2Icons.job,
        label: job.isMission ? copy.copy_mission_fb4c5e1 : copy.copy_job_ce2feba,
        color: primary,
        allowWrap: enlargedText,
      ),
      if (job.visibility == 'SPECIALIZED')
        PremiumTag(
          icon: HopeV2Icons.secure,
          label: copy.copy_specialized_5d1ca04,
          color: HopeV2Colors.warning,
          allowWrap: enlargedText,
        ),
      if (category.isNotEmpty)
        PremiumTag(
          icon: HopeV2Icons.category,
          label: category,
          color: HopeV2Colors.muted,
          allowWrap: enlargedText,
        ),
      if (match != null)
        PremiumTag(
          icon: HopeV2Icons.match,
          label: match,
          color: HopeV2SemanticColors.info(context),
          allowWrap: enlargedText,
        ),
      if (matchReasonTag != null) matchReasonTag,
    ];
    final visibleTags = compactViewport && tags.length > 3
        ? tags.take(3).toList(growable: false)
        : tags;
    final media = ClipRRect(
      borderRadius: BorderRadius.circular(HopeV2Radii.md),
      child: SizedBox(
        key: const ValueKey('opportunity-featured-scan-media'),
        width: mediaSize,
        height: mediaSize,
        child: mediaUrl != null && mediaUrl.trim().isNotEmpty
            ? Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackMedia(context, primary),
              )
            : _fallbackMedia(context, primary),
      ),
    );

    return Column(
      key: const ValueKey('opportunity-featured-scan-layout'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            media,
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    key: const ValueKey('opportunity-featured-scan-tag-rail'),
                    spacing: HopeV2Spacing.xs,
                    runSpacing: 3,
                    children: [
                      for (final tag in visibleTags)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compactViewport ? 92 : 130,
                          ),
                          child: tag,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    key: const ValueKey('opportunity-featured-scan-title'),
                    maxLines: enlargedText ? null : 2,
                    softWrap: true,
                    overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: compactViewport ? 15 : 16,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (amount.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(amount, context),
                      key: const ValueKey('opportunity-featured-scan-budget'),
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HopeV2SemanticColors.amount(context),
                            fontSize: compactViewport ? 12.5 : 13.5,
                            height: 1.16,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: HopeV2Spacing.sm,
                    runSpacing: 2,
                    children: [
                      if (mode != null && mode != city)
                        _metaText(
                          context,
                          HopeV2Icons.workshop,
                          mode,
                          secondaryAccent(context),
                        ),
                      _metaText(
                        context,
                        HopeV2Icons.location,
                        city,
                        secondaryAccent(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize:
                        enlargedText ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      Flexible(
                        fit: enlargedText ? FlexFit.tight : FlexFit.loose,
                        child: Text(
                          _t(context, 'مشاهده جزئیات', 'View details'),
                          maxLines: enlargedText ? null : 1,
                          softWrap: true,
                          overflow: enlargedText
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: HopeV2SemanticColors.textPrimary(context),
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _actionAffordance(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scanStandard(
    BuildContext context, {
    required String title,
    required String city,
    required String amount,
    required Color primary,
    required String? mediaUrl,
    required HopeCopy copy,
    required List<String> reasons,
    bool showMatchRationale = false,
  }) {
    final company = _companyName();
    final mode = _workMode(context);
    final match = _matchLabel(context);
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final matchReasonTag = showMatchRationale
        ? _compactMatchReasonTag(context, reasons, allowWrap: enlargedText)
        : null;
    final compactViewport =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final mediaSize = compactViewport ? 56.0 : 88.0;
    final media = ClipRRect(
      borderRadius: BorderRadius.circular(HopeV2Radii.md),
      child: SizedBox(
        key: const ValueKey('opportunity-scan-media'),
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
        if (_categoryValue() != null)
          PremiumTag(
            icon: HopeV2Icons.category,
            label: hopeCategoryLabel(context, _categoryValue()!),
            color: HopeV2Colors.muted,
            allowWrap: enlargedText,
          ),
        if (job.visibility == 'SPECIALIZED')
          PremiumTag(
            icon: HopeV2Icons.secure,
            label: copy.copy_specialized_5d1ca04,
            color: HopeV2Colors.warning,
            allowWrap: enlargedText,
          ),
      ],
    );

    final meta = <Widget>[
      if (mode != null && mode != city)
        _metaText(
          context,
          HopeV2Icons.workshop,
          mode,
          secondaryAccent(context),
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
      mainAxisSize: MainAxisSize.min,
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
                  SingleChildScrollView(
                    key: const ValueKey('opportunity-scan-tag-rail'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: HopeV2Spacing.xs,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: PremiumTag(
                              label: job.isMission
                                  ? copy.copy_mission_fb4c5e1
                                  : copy.copy_job_ce2feba,
                              icon: job.isMission
                                  ? HopeV2Icons.mission
                                  : HopeV2Icons.job,
                              color: primary,
                              allowWrap: enlargedText,
                            ),
                          ),
                        ),
                        if (match != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: HopeV2Spacing.xs,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: PremiumTag(
                                icon: HopeV2Icons.match,
                                label: match,
                                color: HopeV2SemanticColors.info(context),
                                allowWrap: enlargedText,
                              ),
                            ),
                          ),
                        if (matchReasonTag != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: HopeV2Spacing.xs,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: matchReasonTag,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HopeV2Spacing.xs),
                  Text(
                    title,
                    maxLines: enlargedText ? null : 2,
                    softWrap: true,
                    overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.12,
                        ),
                  ),
                  if (company != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      company,
                      maxLines: enlargedText ? null : 1,
                      softWrap: true,
                      overflow: enlargedText
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
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
        if (amount.isNotEmpty) ...[
          SizedBox(height: compactViewport ? 5 : 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HopeIcon( HopeV2Icons.payments,
                size: 15,
                color: primary,
                strokeWidth: 1.8,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _formatAmount(amount, context),
                  key: const ValueKey('opportunity-card-budget-amount'),
                  // Financial ranges must wrap completely at accessibility text
                  // scales; a fixed line cap silently discards part of the value.
                  softWrap: true,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HopeV2SemanticColors.amount(context),
                        fontSize: compactViewport ? 12 : 13,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
        ],
        if (meta.isNotEmpty) ...[
          SizedBox(height: compactViewport ? 4 : 7),
          Wrap(
            spacing: HopeV2Spacing.sm,
            runSpacing: HopeV2Spacing.xs,
            children: meta,
          ),
        ],
        if (tags.children.isNotEmpty && !compactViewport) ...[
          const SizedBox(height: HopeV2Spacing.sm),
          tags,
        ],
        SizedBox(height: compactViewport ? 4 : HopeV2Spacing.sm),
        ConstrainedBox(
          key: const ValueKey('opportunity-card-cta'),
          constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 2, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    compactViewport
                        ? _t(context, 'مشاهده جزئیات', 'View details')
                        : (job.isMission
                            ? copy.copy_view_and_act_on_mission
                            : copy.copy_view_details_and_act),
                    maxLines: enlargedText ? null : 2,
                    overflow: enlargedText
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HopeV2SemanticColors.textPrimary(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _actionAffordance(context),
              ],
            ),
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
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final metadataMaxWidth = enlargedText
        ? (MediaQuery.sizeOf(context).width * 0.62)
            .clamp(180.0, 260.0)
            .toDouble()
        : 260.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: metadataMaxWidth),
      child: Row(
        // At enlarged text sizes, metadata occupies the available line width
        // so the label wraps inside the card instead of sizing the Row to its
        // intrinsic text width. Keep compact intrinsic sizing at normal scale.
        mainAxisSize:
            enlargedText ? MainAxisSize.max : MainAxisSize.min,
        children: [
          HopeIcon(
            icon,
            size: 15,
            color: color,
            strokeWidth: 1.8,
          ),
          const SizedBox(width: 5),
          Flexible(
            fit: enlargedText ? FlexFit.tight : FlexFit.loose,
            child: Text(
              label,
              maxLines: enlargedText ? null : 1,
              softWrap: true,
              overflow: enlargedText
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
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
    final compactViewport =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final reasonLabels = reasons
        .map((reason) => _reason(context, reason))
        .whereType<String>()
        .toList(growable: false);
    final matchPercent =
        HopeDisplayFormatter.matchPercentage(job.recommendationScore);
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
          showTitle: false,
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
                        allowWrap: enlargedText,
                      ),
                      if (matchPercent != null)
                        PremiumTag(
                          key: const ValueKey('opportunity-card-expanded-match-score'),
                          icon: HopeV2Icons.match,
                          label: '${HopeDisplayFormatter.percent(
                            matchPercent.round(),
                            locale: Localizations.localeOf(context).languageCode,
                          )} ${_t(context, 'تطابق', 'match')}',
                          color: HopeV2SemanticColors.info(context),
                          allowWrap: enlargedText,
                        ),
                    ],
                  ),
                  const SizedBox(height: HopeV2Spacing.sm),
                  Text(
                    title,
                    maxLines: enlargedText ? null : 2,
                    softWrap: true,
                    overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
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
              allowWrap: enlargedText,
            ),
            if (_categoryValue() != null)
              PremiumTag(
                icon: HopeV2Icons.category,
                label: hopeCategoryLabel(context, _categoryValue()!),
                color: HopeV2Colors.muted,
                allowWrap: enlargedText,
              ),
            if (job.visibility == 'SPECIALIZED')
              PremiumTag(
                icon: HopeV2Icons.secure,
                label: copy.copy_specialized_5d1ca04,
                color: HopeV2Colors.warning,
                allowWrap: enlargedText,
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
                HopeIcon( HopeV2Icons.payments,
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
                        _formatAmount(amount, context),
                        key: const ValueKey('opportunity-card-expanded-budget'),
                        maxLines: enlargedText
                            ? null
                            : (compactViewport ? 3 : 2),
                        softWrap: true,
                        overflow: enlargedText
                            ? TextOverflow.visible
                            : TextOverflow.clip,
                        style: HopeV2Type.metric(context).copyWith(
                          fontSize: compactViewport ? 14 : 18,
                          height: compactViewport ? 1.15 : 1.05,
                          color: HopeV2SemanticColors.amount(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (reasonLabels.isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.sm),
          Text(
            copy.copy_match_signals,
            key: const ValueKey('opportunity-card-match-signals-title'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: HopeV2Spacing.xs),
          Wrap(
            spacing: HopeV2Spacing.sm,
            runSpacing: HopeV2Spacing.sm,
            children: reasonLabels
                .map(
                  (label) => PremiumTag(
                    icon: HopeV2Icons.completed,
                    label: label,
                    color: primary,
                    allowWrap: enlargedText,
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (job.description.trim().isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.md),
          Text(
            job.description.trim(),
            maxLines: enlargedText ? null : 5,
            softWrap: true,
            overflow: enlargedText
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
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
            _actionAffordance(context),
          ],
        ),
      ],
    );
  }

}

enum _CategoryArtworkStyle {
  software, design, marketing, content, finance, education,
  support, construction, media, data, sales, general,
}

/// Deterministic vector artwork for missing/failed opportunity media.
/// Real server media remains authoritative; the artwork carries no metric data.
class _CategoryFallbackPainter extends CustomPainter {
  const _CategoryFallbackPainter({
    required this.style,
    required this.accent,
    required this.dark,
  });

  final _CategoryArtworkStyle style;
  final Color accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.save();
    canvas.scale(size.width / 320, size.height / 92);

    final soft = Paint()
      ..color = accent.withValues(alpha: dark ? .10 : .055);
    final fill = Paint()
      ..color = accent.withValues(alpha: dark ? .22 : .13);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: dark ? .54 : .36);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(alpha: dark ? .42 : .26);

    void line(double x1, double y1, double x2, double y2, Paint paint) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    void circle(double x, double y, double r, Paint paint) =>
        canvas.drawCircle(Offset(x, y), r, paint);
    void box(double x, double y, double w, double h, Paint paint,
        {double radius = 5}) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        ),
        paint,
      );
    }

    circle(289, 12, 36, soft);
    circle(31, 82, 25, soft);
    circle(126, 13, 2.2, fill);
    circle(198, 78, 2.2, fill);

    // Kinetic editorial duotone layer: category accent paired with HOPE indigo
    // and teal. These ornaments are decorative only and never encode status.
    final motionColor = dark ? HopeV2Colors.primaryDark : HopeV2Colors.primaryAction;
    final infoColor = dark ? HopeV2Colors.secondaryDark : HopeV2Colors.secondaryStrong;
    final motionFill = Paint()
      ..color = motionColor.withValues(alpha: dark ? .16 : .09);
    final motionStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = motionColor.withValues(alpha: dark ? .43 : .28);
    final infoStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..color = infoColor.withValues(alpha: dark ? .42 : .30);
    final slash = Path()
      ..moveTo(-8, 78)
      ..lineTo(36, 31)
      ..lineTo(51, 31)
      ..lineTo(7, 80)
      ..close()
      ..moveTo(268, 93)
      ..lineTo(307, 51)
      ..lineTo(326, 51)
      ..lineTo(288, 93)
      ..close();
    canvas.drawPath(slash, motionFill);
    final trajectory = Path()
      ..moveTo(-12, 68)
      ..cubicTo(47, 12, 94, 101, 154, 53)
      ..cubicTo(206, 13, 259, 13, 334, 30);
    canvas.drawPath(trajectory, infoStroke);
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(284, 45), radius: 25),
      -.9,
      2.05,
      false,
      motionStroke,
    );
    circle(303, 24, 3.2, Paint()..color = infoColor.withValues(alpha: .82));
    circle(26, 24, 2.5, Paint()..color = motionColor.withValues(alpha: .72));

    switch (style) {
      case _CategoryArtworkStyle.software:
        line(38, 22, 75, 67, thin);
        line(75, 67, 113, 29, thin);
        line(113, 29, 139, 42, thin);
        line(183, 43, 211, 26, thin);
        line(211, 26, 251, 65, thin);
        line(251, 65, 290, 25, thin);
        for (final point in const [
          Offset(38, 22), Offset(75, 67), Offset(113, 29),
          Offset(211, 26), Offset(251, 65), Offset(290, 25),
        ]) {
          circle(point.dx, point.dy, 5.2, fill);
          circle(point.dx, point.dy, 8.2, thin);
        }
        break;
      case _CategoryArtworkStyle.design:
        circle(59, 45, 25, stroke);
        circle(59, 45, 15, fill);
        box(88, 12, 39, 26, thin, radius: 4);
        box(31, 59, 31, 19, fill, radius: 4);
        box(231, 13, 52, 27, stroke, radius: 4);
        box(252, 50, 37, 27, fill, radius: 4);
        circle(224, 70, 7, stroke);
        break;
      case _CategoryArtworkStyle.marketing:
        box(26, 57, 13, 23, fill, radius: 3);
        box(47, 45, 13, 35, fill, radius: 3);
        box(68, 31, 13, 49, fill, radius: 3);
        box(89, 20, 13, 60, fill, radius: 3);
        line(208, 65, 237, 48, stroke);
        line(237, 48, 263, 51, stroke);
        line(263, 51, 295, 19, stroke);
        line(283, 19, 295, 19, thin);
        line(295, 19, 295, 32, thin);
        break;
      case _CategoryArtworkStyle.content:
        box(24, 12, 65, 68, stroke);
        box(32, 20, 50, 9, fill, radius: 2);
        line(34, 38, 78, 38, thin);
        line(34, 46, 72, 46, thin);
        line(34, 54, 78, 54, thin);
        line(34, 62, 65, 62, thin);
        box(226, 19, 60, 56, fill);
        line(238, 34, 274, 34, stroke);
        line(238, 43, 268, 43, thin);
        line(238, 52, 274, 52, thin);
        line(238, 61, 260, 61, thin);
        break;
      case _CategoryArtworkStyle.finance:
        box(25, 52, 15, 28, fill, radius: 3);
        box(47, 40, 15, 40, fill, radius: 3);
        box(69, 27, 15, 53, fill, radius: 3);
        box(91, 17, 15, 63, fill, radius: 3);
        circle(260, 29, 16, stroke);
        circle(260, 29, 8, thin);
        circle(285, 59, 12, fill);
        line(240, 74, 297, 74, thin);
        break;
      case _CategoryArtworkStyle.education:
        line(25, 22, 72, 16, stroke);
        line(72, 16, 150, 35, stroke);
        line(150, 35, 150, 78, stroke);
        line(25, 22, 25, 70, stroke);
        line(25, 70, 72, 61, stroke);
        line(72, 61, 150, 78, stroke);
        line(170, 35, 248, 16, stroke);
        line(248, 16, 295, 22, stroke);
        line(295, 22, 295, 70, stroke);
        line(295, 70, 248, 61, stroke);
        line(248, 61, 170, 78, stroke);
        line(170, 35, 170, 78, stroke);
        line(39, 34, 75, 30, thin);
        line(39, 44, 82, 40, thin);
        line(238, 30, 280, 34, thin);
        line(232, 40, 280, 44, thin);
        break;
      case _CategoryArtworkStyle.support:
        box(23, 14, 83, 43, stroke, radius: 11);
        line(40, 57, 33, 69, stroke);
        line(33, 69, 53, 57, stroke);
        circle(45, 35, 3, fill);
        circle(63, 35, 3, fill);
        circle(81, 35, 3, fill);
        box(229, 36, 67, 39, fill, radius: 10);
        line(274, 75, 284, 83, thin);
        line(284, 83, 283, 73, thin);
        circle(247, 55, 2.6, stroke);
        circle(262, 55, 2.6, stroke);
        circle(277, 55, 2.6, stroke);
        break;
      case _CategoryArtworkStyle.construction:
        line(22, 80, 75, 13, stroke);
        line(75, 13, 128, 80, stroke);
        line(35, 62, 115, 62, thin);
        line(45, 45, 102, 45, thin);
        line(210, 80, 255, 15, stroke);
        line(255, 15, 300, 80, stroke);
        line(221, 62, 289, 62, thin);
        line(232, 45, 277, 45, thin);
        line(234, 33, 276, 71, thin);
        line(276, 33, 234, 71, thin);
        break;
      case _CategoryArtworkStyle.media:
        box(22, 17, 66, 57, stroke, radius: 6);
        circle(55, 45, 13, fill);
        circle(55, 45, 4, stroke);
        const waveHeights = <double>[12, 28, 39, 18, 32, 22, 12];
        for (var index = 0; index < waveHeights.length; index++) {
          final x = 213.0 + index * 12;
          final height = waveHeights[index];
          line(x, 46 - height / 2, x, 46 + height / 2, stroke);
        }
        line(215, 77, 291, 77, thin);
        break;
      case _CategoryArtworkStyle.data:
        line(38, 22, 69, 48, thin);
        line(69, 48, 104, 18, thin);
        line(69, 48, 105, 76, thin);
        line(104, 18, 135, 36, thin);
        line(216, 20, 248, 48, thin);
        line(248, 48, 287, 23, thin);
        line(248, 48, 282, 76, thin);
        for (final point in const [
          Offset(38, 22), Offset(69, 48), Offset(104, 18), Offset(105, 76),
          Offset(135, 36), Offset(216, 20), Offset(248, 48), Offset(287, 23),
          Offset(282, 76),
        ]) {
          circle(point.dx, point.dy, 5, fill);
          circle(point.dx, point.dy, 7.5, thin);
        }
        break;
      case _CategoryArtworkStyle.sales:
        box(23, 58, 13, 22, fill, radius: 3);
        box(45, 45, 13, 35, fill, radius: 3);
        box(67, 32, 13, 48, fill, radius: 3);
        box(89, 19, 13, 61, fill, radius: 3);
        line(213, 68, 239, 54, stroke);
        line(239, 54, 261, 57, stroke);
        line(261, 57, 295, 22, stroke);
        line(283, 22, 295, 22, thin);
        line(295, 22, 295, 34, thin);
        break;
      case _CategoryArtworkStyle.general:
        circle(60, 45, 26, stroke);
        circle(60, 45, 14, thin);
        circle(60, 45, 4, fill);
        circle(260, 45, 22, stroke);
        circle(260, 45, 9, fill);
        line(222, 45, 237, 45, thin);
        line(283, 45, 300, 45, thin);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CategoryFallbackPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.accent != accent ||
      oldDelegate.dark != dark;
}
