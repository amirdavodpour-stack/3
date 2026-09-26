part of 'jobs_page.dart';

class _JobsFilterHeader extends StatelessWidget {
  const _JobsFilterHeader({
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    copy.copy_explore_115e9fd.toUpperCase(),
                    style: HopeV2Type.eyebrow(context).copyWith(
                      color: HopeV2Colors.secondaryDark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    copy.copy_find_the_right_opportunity,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          // Keep discovery heading compact so the first viewport
                          // prioritizes search and opportunity content.
                          fontSize: 24,
                          letterSpacing: -.45,
                          height: 1.10,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.copy_see_missions_and_jobs_together_then_narrow_7e573a3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: HopeV2Spacing.md),
            PremiumTag(
              icon: HopeV2Icons.workshop,
              label: resultCount.toString() + ' ' + copy.copy_results_2d120a3,
            ),
          ],
        ),
        const SizedBox(height: HopeV2Spacing.lg),
        PremiumPanel(
          padding: const EdgeInsets.all(HopeV2Spacing.sm),
          highlight: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final search = PremiumSearchBar(
                onChanged: onQueryChanged,
                hint: copy.copy_title_city_or_skill_bccb024,
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filledTonal(
                    onPressed: onSaveSearch,
                    tooltip: copy.copy_save_search,
                    icon: onSaveSearch == null
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : HugeIcon(
                            icon: HopeV2Icons.add,
                            size: 19,
                          ),
                  ),
                  if (savedSearchCount > 0)
                    IconButton.filledTonal(
                      onPressed: onOpenSavedSearches,
                      tooltip: copy.copy_saved_searches,
                      icon: HugeIcon(
                        icon: HopeV2Icons.savedSearches,
                        size: 19,
                      ),
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
        ),
        const SizedBox(height: HopeV2Spacing.md),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _t(
                        context,
                        'تنظیم نتایج',
                        'Refine results',
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    _t(
                      context,
                      'نوع، دسترسی و زمینه',
                      'Type, access and context',
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: HopeV2Spacing.sm),
              SizedBox(
                height: HopeV2Touch.minimum,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip(
                      context,
                      copy.copy_all_ba7d5b6,
                      kind == 'ALL',
                      () => onKindChanged('ALL'),
                    ),
                    _chip(
                      context,
                      copy.copy_missions_a833d13,
                      kind == 'MISSION',
                      () => onKindChanged('MISSION'),
                      icon: HopeV2Icons.mission,
                    ),
                    _chip(
                      context,
                      copy.copy_jobs_ebf9a80,
                      kind == 'JOB',
                      () => onKindChanged('JOB'),
                      icon: HopeV2Icons.job,
                    ),
                    const SizedBox(width: HopeV2Spacing.sm),
                    _chip(
                      context,
                      copy.copy_public_21e97be,
                      visibility == 'PUBLIC',
                      () => onVisibilityChanged('PUBLIC'),
                    ),
                    _chip(
                      context,
                      copy.copy_specialized_5d1ca04,
                      visibility == 'SPECIALIZED',
                      () => onVisibilityChanged('SPECIALIZED'),
                    ),
                  ],
                ),
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
              SizedBox(
                height: HopeV2Touch.minimum,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    PremiumFilterChip(
                      icon: HopeV2Icons.location,
                      label: cityLabel,
                      selected: false,
                      onTap: onPickCity,
                      color: HopeV2Colors.secondary,
                    ),
                    const SizedBox(width: HopeV2Spacing.sm),
                    PremiumFilterChip(
                      icon: HopeV2Icons.category,
                      label: categoryLabel,
                      selected: false,
                      onTap: onPickCategory,
                      color: HopeV2Colors.primary,
                    ),
                  ],
                ),
              ),
            ],
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
