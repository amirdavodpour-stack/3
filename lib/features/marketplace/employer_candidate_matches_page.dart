import 'package:flutter/material.dart';

import '../../core/marketplace/employer_candidate_matching_repository.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/hope_display_formatters.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';

class EmployerCandidateMatchesPage extends StatelessWidget {
  const EmployerCandidateMatchesPage({
    super.key,
    required this.data,
    required this.onRetry,
  });

  final HopeEmployerCandidateMatchList data;
  final VoidCallback onRetry;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _percent(BuildContext context, num value, {int fractionDigits = 0}) =>
      HopeDisplayFormatter.percent(
        value,
        locale: Localizations.localeOf(context).languageCode,
        fractionDigits: fractionDigits,
      );

  String _candidateScoreLabel(BuildContext context, num score) {
    final normalized = HopeDisplayFormatter.matchPercentage(score);
    if (normalized == null) return '—';
    return _percent(
      context,
      normalized,
      fractionDigits: normalized == normalized.roundToDouble() ? 0 : 1,
    );
  }

  String? _reason(BuildContext context, String value) {
    final code = value.trim().toUpperCase();
    return switch (code) {
      'SKILL_MATCH' => _t(context, 'مهارت', 'Skills'),
      'EXPERIENCE_MATCH' => _t(context, 'تجربه', 'Experience'),
      'CATEGORY_MATCH' => _t(context, 'دسته‌بندی', 'Category'),
      'LOCATION_MATCH' => _t(context, 'مکان', 'Location'),
      'WORK_MODE_MATCH' => _t(context, 'شیوه کار', 'Work mode'),
      'KIND_MATCH' => _t(context, 'نوع همکاری', 'Work type'),
      'SALARY_FIT' => _t(context, 'حقوق مناسب', 'Salary fit'),
      'BUDGET_FIT' => _t(context, 'بودجه مناسب', 'Budget fit'),
      'AVAILABILITY_MATCH' => _t(context, 'دردسترس', 'Availability'),
      _ => null,
    };
  }

  String _componentLabel(BuildContext context, String key) => switch (key) {
    'skills' => _t(context, 'مهارت', 'Skills'),
    'experience' => _t(context, 'تجربه', 'Experience'),
    'location' => _t(context, 'مکان', 'Location'),
    'salary' => _t(context, 'درآمد', 'Salary'),
    _ => key,
  };

  double? _componentValue(HopeEmployerCandidateMatch candidate, String key) =>
      candidate.components[key] ??
      (key == 'salary' ? candidate.components['compensation'] : null);

  Widget _componentBreakdown(BuildContext context, HopeEmployerCandidateMatch candidate) {
    const keys = ['skills', 'experience', 'location', 'salary'];
    final values = <MapEntry<String, double>>[];
    for (final key in keys) {
      final value = _componentValue(candidate, key);
      if (value != null) values.add(MapEntry(key, value <= 1 ? value : value / 100));
    }
    if (values.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 360
            ? constraints.maxWidth
            : (constraints.maxWidth - 7) / 2;
        return Wrap(
          spacing: 7,
          runSpacing: 5,
          children: values.map((entry) {
            final ratio = entry.value.clamp(0.0, 1.0);
            return SizedBox(
              key: ValueKey('candidate-signal-${entry.key}'),
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _componentLabel(context, entry.key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? HopeV2Colors.darkMuted
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Text(
                        _percent(context, (ratio * 100).round()),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: ratio,
                      backgroundColor: HopeV2Surfaces.border(context).withValues(alpha: .35),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        HopeV2ChartColors.matchSignal(context),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget _candidateOverviewContent(
    BuildContext context, {
    required HopeEmployerCandidateMatch best,
    required String? gapValue,
    required bool enlargedText,
    required int candidateCount,
  }) {
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context, 'بهترین تطابق', 'Best fit'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? HopeV2Colors.darkMuted
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          best.displayName,
          maxLines: enlargedText ? null : 1,
          softWrap: true,
          overflow: enlargedText ? TextOverflow.visible : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
    final scoreTag = PremiumTag(
      key: const ValueKey('candidate-comparison-best-score'),
      icon: HopeV2Icons.match,
      label: _candidateScoreLabel(context, best.score),
      color: HopeV2ChartColors.matchSignal(context),
    );
    final gapTag = candidateCount > 1 && gapValue != null
        ? PremiumTag(
            label: _t(
              context,
              'اختلاف $gapValue واحد درصد',
              '$gapValue percentage-point gap',
            ),
            color: HopeV2Colors.secondary,
          )
        : null;

    if (enlargedText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity,
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              scoreTag,
              if (gapTag != null) gapTag,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: identity),
        scoreTag,
        if (gapTag != null) ...[
          const SizedBox(width: 7),
          gapTag,
        ],
      ],
    );
  }

  Widget _comparisonMatrix(BuildContext context) {
    final candidates = data.candidates.take(3).toList(growable: false);
    const keys = ['skills', 'experience', 'location', 'salary'];
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final widths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(86),
    };
    for (var index = 0; index < candidates.length; index++) {
      widths[index + 1] = const FixedColumnWidth(110);
    }

    Widget cell(
      String value, {
      bool heading = false,
      bool highlight = false,
      Key? key,
    }) {
      final primary = Theme.of(context).colorScheme.primary;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Container(
          key: key,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: highlight
              ? BoxDecoration(
                  color: primary.withValues(alpha: .075),
                  borderRadius: BorderRadius.circular(HopeV2Radii.sm),
                  border: Border.all(color: primary.withValues(alpha: .12)),
                )
              : null,
          child: Text(
            value,
            maxLines: enlargedText ? null : 2,
            softWrap: true,
            overflow: enlargedText
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: heading
                      ? HopeV2SemanticColors.textPrimary(context)
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: heading ? FontWeight.w900 : FontWeight.w700,
                ),
          ),
        ),
      );
    }

    String valueFor(HopeEmployerCandidateMatch candidate, String key) {
      final value = _componentValue(candidate, key);
      if (value != null) {
        final normalized = value <= 1 ? value * 100 : value;
        return _percent(context, normalized.clamp(0.0, 100.0).round());
      }
      if (key == 'skills' && (candidate.skills ?? '').trim().isNotEmpty) {
        return candidate.skills!.trim();
      }
      return _t(context, 'ثبت نشده', 'Not provided');
    }

    return PremiumPanel(
      key: const ValueKey('candidate-comparison-matrix'),
      quiet: true,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t(context, 'مقایسهٔ سریع نامزدها', 'Quick candidate comparison'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              columnWidths: widths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: HopeV2Surfaces.border(context).withValues(alpha: .24),
                ),
              ),
              children: [
                TableRow(
                  children: [
                    cell(_t(context, 'شاخص', 'Metric'), heading: true),
                    for (var candidateIndex = 0;
                        candidateIndex < candidates.length;
                        candidateIndex++)
                      cell(
                        candidates[candidateIndex].displayName.trim().isEmpty
                            ? _t(
                                context,
                                'نامزد ${HopeDisplayFormatter.integer(candidates[candidateIndex].rank, locale: Localizations.localeOf(context).languageCode)}',
                                'Candidate ${HopeDisplayFormatter.integer(candidates[candidateIndex].rank, locale: Localizations.localeOf(context).languageCode)}',
                              )
                            : candidates[candidateIndex].displayName.trim(),
                        heading: true,
                        highlight: candidateIndex == 0,
                        key: candidateIndex == 0
                            ? const ValueKey('candidate-comparison-leading-candidate-header')
                            : null,
                      ),
                  ],
                ),
                for (final key in keys)
                  TableRow(
                    children: [
                      cell(_componentLabel(context, key), heading: true),
                      for (var candidateIndex = 0;
                          candidateIndex < candidates.length;
                          candidateIndex++)
                        cell(
                          valueFor(candidates[candidateIndex], key),
                          highlight: candidateIndex == 0,
                        ),
                    ],
                  ),
                TableRow(
                  children: [
                    cell(_t(context, 'انطباق', 'Match'), heading: true),
                    for (var candidateIndex = 0;
                        candidateIndex < candidates.length;
                        candidateIndex++)
                      cell(
                        _candidateScoreLabel(
                          context,
                          candidates[candidateIndex].score,
                        ),
                        heading: true,
                        highlight: candidateIndex == 0,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return PremiumPageFrame(
      page: HopePageId.candidateMatches,
      domain: HopeProductDomain.intelligence,
      maxWidth: 920,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      child: ListView(
        padding: HopeV2Navigation.scrollEndPadding(context),
        children: [
        PremiumSectionHeader(
          page: HopePageId.candidateMatches,
          domain: HopeProductDomain.intelligence,
          title: _t(
            context,
            'پذیرندگان بر اساس انطباق',
            'Applicants by compatibility',
          ),
          subtitle: _t(
            context,
            'کارگران بر اساس مهارت، تجربه و شرایط موقعیت مرتب شده‌اند.',
            'Workers are ordered by skills, experience, and opportunity fit.',
          ),
        ),
        const SizedBox(height: 8),
        if (data.candidates.isNotEmpty)
          Builder(
            builder: (context) {
              final best = data.candidates.first;
              final bestScore =
                  HopeDisplayFormatter.matchPercentage(best.score);
              final secondScore = data.candidates.length > 1
                  ? HopeDisplayFormatter.matchPercentage(
                      data.candidates[1].score,
                    )
                  : null;
              final gap = bestScore != null && secondScore != null
                  ? (bestScore - secondScore).abs().clamp(0.0, 100.0)
                  : null;
              final gapValue = gap == null
                  ? null
                  : HopeDisplayFormatter.integer(
                      gap.round(),
                      locale: Localizations.localeOf(context).languageCode,
                    );
              return PremiumPanel(
                key: const ValueKey('candidate-comparison-overview'),
                quiet: true,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: _candidateOverviewContent(
                  context,
                  best: best,
                  gapValue: gapValue,
                  enlargedText: enlargedText,
                  candidateCount: data.candidates.length,
                ),
              );
            },
          ),
        if (data.candidates.length > 1) ...[
          _comparisonMatrix(context),
          const SizedBox(height: 8),
        ],
        if (data.candidates.isNotEmpty)
          const SizedBox(height: 8),
        if (data.candidates.isEmpty)
          PremiumPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t(
                    context,
                    'هنوز پذیرنده‌ای برای این موقعیت نیست.',
                    'No workers have accepted this opportunity yet.',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _t(
                    context,
                    'پس از ثبت درخواست یا پیشنهاد، فهرست انطباق اینجا آماده می‌شود.',
                    'Once applications or offers arrive, the compatibility list will appear here.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const HopeIcon( HopeV2Icons.refresh, size: 18),
                  label: Text(_t(context, 'به‌روزرسانی', 'Refresh')),
                ),
              ],
            ),
          )
        else
          ...data.candidates.map(
            (candidate) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: HopeV2Surfaces.divider(context).withValues(alpha: .38),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HopeV2ChartColors.matchSignal(context).withValues(alpha: .12),
                          ),
                          child: Center(
                            child: Text(
                              HopeDisplayFormatter.integer(candidate.rank, locale: Localizations.localeOf(context).languageCode),
                              style: const TextStyle(fontWeight: FontWeight.w900,
                                fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidate.displayName.isEmpty
                                    ? _t(context, 'کارگر', 'Worker')
                                    : candidate.displayName,
                                maxLines: enlargedText ? null : 1,
                                softWrap: true,
                                overflow: enlargedText
                                    ? TextOverflow.visible
                                    : TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _t(context, 'میزان انطباق', 'Compatibility'),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? HopeV2Colors.darkMuted
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          key: ValueKey('candidate-match-score-${candidate.userId}'),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: HopeV2ChartColors.matchSignal(context).withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(HopeV2Radii.sm),
                            border: Border.all(
                              color: HopeV2ChartColors.matchSignal(context).withValues(alpha: .14),
                            ),
                          ),
                          child: Text(
                            _candidateScoreLabel(context, candidate.score),
                            style: HopeV2Type.metric(context).copyWith(
                              color: HopeV2SemanticColors.info(context),
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (candidate.reasons.any((reason) => _reason(context, reason) != null)) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: candidate.reasons
                            .map((reason) => _reason(context, reason))
                            .whereType<String>()
                            .map(
                              (label) => PremiumTag(
                                icon: HopeV2Icons.match,
                                label: label,
                                color: HopeV2Colors.secondary,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if (candidate.components.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _componentBreakdown(context, candidate),
                    ],
                    if ((candidate.skills ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        candidate.skills!.trim(),
                        maxLines: enlargedText
                            ? null
                            : MediaQuery.sizeOf(context).width < HopeV2Breakpoints.medium
                                ? 1
                                : 2,
                        softWrap: true,
                        overflow: enlargedText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (candidate.offerPrice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_t(context, 'پیشنهاد مالی: ', 'Offer: ')}${HopeDisplayFormatter.money(
                          candidate.offerPrice,
                          locale: Localizations.localeOf(context).languageCode,
                        )}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
