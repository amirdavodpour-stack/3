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
            const SizedBox(width: HopeV2Spacing.sm),
            _item(
              context,
              label: copy.copy_missions_a833d13,
              selected: kind == 'MISSION',
              onTap: () => onKindChanged('MISSION'),
              icon: HopeV2Icons.mission,
            ),
            const SizedBox(width: HopeV2Spacing.sm),
            _item(
              context,
              label: copy.copy_jobs_ebf9a80,
              selected: kind == 'JOB',
              onTap: () => onKindChanged('JOB'),
              icon: HopeV2Icons.job,
            ),
            const SizedBox(width: HopeV2Spacing.sm),
            _item(
              context,
              label: copy.copy_public_21e97be,
              selected: visibility == 'PUBLIC',
              onTap: () => onVisibilityChanged('PUBLIC'),
            ),
            const SizedBox(width: HopeV2Spacing.sm),
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
        const SizedBox(height: HopeV2Spacing.md),
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
                PremiumIconButton(
                  icon: HopeV2Icons.add,
                  tooltip: copy.copy_save_search,
                  onPressed: onSaveSearch,
                ),
                if (savedSearchCount > 0) ...[
                  const SizedBox(width: HopeV2Spacing.xs),
                  PremiumIconButton(
                    icon: HopeV2Icons.savedSearches,
                    tooltip: copy.copy_saved_searches,
                    onPressed: onOpenSavedSearches,
                  ),
                ],
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
        HopeOpportunityRefinementGroup(
          kind: kind,
          visibility: visibility,
          onKindChanged: onKindChanged,
          onVisibilityChanged: onVisibilityChanged,
        ),
        const SizedBox(height: HopeV2Spacing.sm),
        if (categoryError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: HopeV2Spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    categoryError!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onRetryCategories,
                  child: Text(copy.copy_retry_49f3eba),
                ),
              ],
            ),
          ),
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