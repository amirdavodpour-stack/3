import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/marketplace/employer_candidate_matching_repository.dart';
import '../../core/theme/hope_v2_design.dart';
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

  String _reason(BuildContext context, String value) => switch (value) {
        'SKILL_MATCH' => _t(context, 'مهارت', 'Skills'),
        'EXPERIENCE_MATCH' => _t(context, 'تجربه', 'Experience'),
        'CATEGORY_MATCH' => _t(context, 'دسته‌بندی', 'Category'),
        'LOCATION_MATCH' => _t(context, 'مکان', 'Location'),
        'WORK_MODE_MATCH' => _t(context, 'شیوه کار', 'Work mode'),
        'KIND_MATCH' => _t(context, 'نوع همکاری', 'Work type'),
        'SALARY_FIT' => _t(context, 'حقوق مناسب', 'Salary fit'),
        'BUDGET_FIT' => _t(context, 'بودجه مناسب', 'Budget fit'),
        'AVAILABILITY_MATCH' => _t(context, 'دردسترس', 'Availability'),
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    return PremiumPageFrame(
      page: HopePageId.candidateMatches,
      domain: HopeProductDomain.intelligence,
      maxWidth: 920,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: ListView(
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
                  icon: const HugeIcon(icon: HopeV2Icons.refresh, size: 18),
                  label: Text(_t(context, 'به‌روزرسانی', 'Refresh')),
                ),
              ],
            ),
          )
        else
          ...data.candidates.map(
            (candidate) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumPanel(
                glass: false,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HopeV2Colors.primary.withValues(alpha: .12),
                          ),
                          child: Center(
                            child: Text(
                              '${candidate.rank}',
                              style: const TextStyle(fontWeight: FontWeight.w900,
                                fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                candidate.displayName.isEmpty
                                    ? _t(context, 'کارگر', 'Worker')
                                    : candidate.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: HopeV2Colors.primary.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(HopeV2Radii.md),
                            border: Border.all(
                              color: HopeV2Colors.primary.withValues(alpha: .20),
                            ),
                          ),
                          child: Text(
                            '${candidate.score.toStringAsFixed(candidate.score == candidate.score.roundToDouble() ? 0 : 1)}٪',
                            style: HopeV2Type.metric(context).copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (candidate.reasons.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: candidate.reasons
                            .map(
                              (reason) => PremiumTag(
                                icon: HopeV2Icons.match,
                                label: _reason(context, reason),
                                color: HopeV2Colors.secondary,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    if ((candidate.skills ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        candidate.skills!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (candidate.offerPrice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_t(context, 'پیشنهاد مالی: ', 'Offer: ')}${candidate.offerPrice} تومان',
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
