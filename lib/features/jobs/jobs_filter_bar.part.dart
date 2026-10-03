part of 'jobs_page.dart';

class HopeOpportunityRefinementGroup extends StatelessWidget {
  const HopeOpportunityRefinementGroup({
    super.key,
    required this.kind,
    required this.visibility,
    required this.onKindChanged,
    required this.onVisibilityChanged,
  });

  final String kind;
  final String visibility;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final copy = HopeCopy.of(context);
    return Wrap(
      spacing: HopeV2Spacing.sm,
      runSpacing: HopeV2Spacing.xs,
      children: [
            _item(
              context,
              label: copy.copy_all_ba7d5b6,
              selected: kind == 'ALL',
              onTap: () => onKindChanged('ALL'),
            ),
            _item(
              context,
              label: copy.copy_missions_a833d13,
              selected: kind == 'MISSION',
              onTap: () => onKindChanged('MISSION'),
              icon: HopeV2Icons.mission,
            ),
            _item(
              context,
              label: copy.copy_jobs_ebf9a80,
              selected: kind == 'JOB',
              onTap: () => onKindChanged('JOB'),
              icon: HopeV2Icons.job,
            ),
            _item(
              context,
              label: copy.copy_public_21e97be,
              selected: visibility == 'PUBLIC',
              onTap: () => onVisibilityChanged('PUBLIC'),
            ),
            _item(
              context,
              label: copy.copy_specialized_5d1ca04,
              selected: visibility == 'SPECIALIZED',
              onTap: () => onVisibilityChanged('SPECIALIZED'),
            ),
      ],
    );
  }

  Widget _item(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Object? icon,
  }) {
    return PremiumFilterChip(
      label: label,
      selected: selected,
      onTap: onTap,
      icon: icon,
    );
  }
}

class HopeOpportunityRefinementLauncher extends StatelessWidget {
  const HopeOpportunityRefinementLauncher({
    super.key,
    required this.activeCount,
    required this.kind,
    required this.visibility,
    required this.cityLabel,
    required this.categoryLabel,
    required this.categoryError,
    required this.onKindChanged,
    required this.onVisibilityChanged,
    required this.onPickCity,
    required this.onPickCategory,
    required this.onRetryCategories,
  });

  final int activeCount;
  final String kind;
  final String visibility;
  final String cityLabel;
  final String categoryLabel;
  final String? categoryError;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onPickCity;
  final VoidCallback onPickCategory;
  final VoidCallback onRetryCategories;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            Text(
              _t(context, 'تنظیم نتایج', 'Refine results'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.35,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              _t(
                context,
                'فیلترهای جزئی را اینجا تنظیم کنید؛ viewport اصلی برای فرصت‌ها آزاد می‌ماند.',
                'Set secondary filters here and keep the main viewport focused on opportunities.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: HopeV2Spacing.md),
            HopeOpportunityRefinementGroup(
              kind: kind,
              visibility: visibility,
              onKindChanged: onKindChanged,
              onVisibilityChanged: onVisibilityChanged,
            ),
            if (categoryError != null) ...[
              const SizedBox(height: HopeV2Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      categoryError!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: onRetryCategories,
                    child: Text(_t(context, 'دوباره', 'Retry')),
                  ),
                ],
              ),
            ],
            const SizedBox(height: HopeV2Spacing.sm),
            Wrap(
              spacing: HopeV2Spacing.sm,
              runSpacing: HopeV2Spacing.xs,
              children: [
                PremiumFilterChip(
                  icon: HopeV2Icons.location,
                  label: cityLabel,
                  selected: false,
                  onTap: onPickCity,
                  color: HopeV2Colors.secondary,
                ),
                PremiumFilterChip(
                  icon: HopeV2Icons.category,
                  label: categoryLabel,
                  selected: false,
                  onTap: onPickCategory,
                  color: HopeV2Colors.primary,
                ),
              ],
            ),
            const SizedBox(height: HopeV2Spacing.lg),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext),
              child: Text(_t(context, 'اعمال فیلترها', 'Done')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = activeCount == 0
        ? _t(context, 'فیلترها', 'Filters')
        : _t(context, 'فیلترها · $activeCount', 'Filters · $activeCount');
    return Semantics(
      button: true,
      label: _t(context, 'باز کردن فیلترهای فرصت', 'Open opportunity filters'),
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const HopeIcon(HopeV2Icons.filter, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _JobsFilterHeader extends StatelessWidget {
  const _JobsFilterHeader({
    required this.domain,
    required this.kind,
    required this.visibility,
    required this.categoryError,
    required this.cityLabel,
    required this.categoryLabel,
    required this.resultCount,
    required this.onQueryChanged,
    required this.onKindChanged,
    required this.onVisibilityChanged,
    required this.onRetryCategories,
    required this.onPickCity,
    required this.onPickCategory,
    required this.savedSearchCount,
    required this.onSaveSearch,
    required this.onOpenSavedSearches,
  });

  final HopeProductDomain domain;
  final String kind;
  final String visibility;
  final String? categoryError;
  final String cityLabel;
  final String categoryLabel;
  final int resultCount;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onRetryCategories;
  final VoidCallback onPickCity;
  final VoidCallback onPickCategory;
  final int savedSearchCount;
  final VoidCallback? onSaveSearch;
  final VoidCallback onOpenSavedSearches;

  @override
  Widget build(BuildContext context) {
    final copy = HopeCopy.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _t(
                  context,
                  'فرصت بعدی خود را پیدا کنید',
                  'Find your next opportunity',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.45,
                    ),
              ),
            ),
            const SizedBox(width: HopeV2Spacing.sm),
            PremiumTag(
              icon: HopeV2Icons.workshop,
              label: '$resultCount ${copy.copy_results_2d120a3}',
            ),
          ],
        ),
        const SizedBox(height: HopeV2Spacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final search = PremiumSearchBar(
              onChanged: onQueryChanged,
              hint: copy.copy_title_city_or_skill_bccb024,
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HopeOpportunityRefinementLauncher(
                  activeCount: [
                    if (kind != 'ALL') 1,
                    if (visibility != 'ALL') 1,
                    if (cityLabel.trim().isNotEmpty &&
                        cityLabel != copy.copy_near_1df6db0) 1,
                    if (categoryLabel.trim().isNotEmpty &&
                        categoryLabel !=
                            HopeCopy.of(context).copy_all_fields_4f77401)
                      1,
                  ].length,
                  kind: kind,
                  visibility: visibility,
                  cityLabel: cityLabel,
                  categoryLabel: categoryLabel,
                  categoryError: categoryError,
                  onKindChanged: onKindChanged,
                  onVisibilityChanged: onVisibilityChanged,
                  onPickCity: onPickCity,
                  onPickCategory: onPickCategory,
                  onRetryCategories: onRetryCategories,
                ),
                if (savedSearchCount > 0) ...[
                  const SizedBox(width: HopeV2Spacing.xs),
                  PremiumIconButton(
                    icon: HopeV2Icons.savedSearches,
                    tooltip: copy.copy_saved_searches,
                    onPressed: onOpenSavedSearches,
                  ),
                ],
                const SizedBox(width: HopeV2Spacing.xs),
                PremiumIconButton(
                  icon: HopeV2Icons.add,
                  tooltip: copy.copy_save_search,
                  onPressed: onSaveSearch,
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: HopeV2Spacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: actions,
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: HopeV2Spacing.sm),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: HopeV2Spacing.xs),
        if (categoryError != null)
          Padding(
            padding: const EdgeInsets.only(top: HopeV2Spacing.xs),
            child: Text(
              categoryError!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    String text,
    bool selected,
    VoidCallback onTap, {
    Object? icon,
  }) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(end: HopeV2Spacing.sm),
        child: PremiumFilterChip(
          label: text,
          selected: selected,
          onTap: onTap,
          icon: icon,
        ),
      );
}