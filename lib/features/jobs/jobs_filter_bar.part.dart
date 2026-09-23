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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PremiumHeader(
                eyebrow: HopeCopy.of(context).copy_explore_115e9fd,
                title: HopeCopy.of(context).copy_find_the_right_opportunity,
                subtitle: HopeCopy.of(context)
                    .copy_see_missions_and_jobs_together_then_narrow_7e573a3,
              ),
            ),
            const SizedBox(width: HopeV2Spacing.md),
            PremiumTag(
              icon: Icons.grid_view_rounded,
              label: '\$resultCount ${HopeCopy.of(context).copy_results_2d120a3}',
            ),
          ],
        ),
        const SizedBox(height: HopeV2Spacing.lg),
        PremiumPanel(
          padding: const EdgeInsets.all(HopeV2Spacing.md),
          highlight: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: PremiumSearchBar(
                      onChanged: onQueryChanged,
                      hint: HopeCopy.of(context).copy_title_city_or_skill_bccb024,
                    ),
                  ),
                  const SizedBox(width: HopeV2Spacing.sm),
                  IconButton.filledTonal(
                    onPressed: onSaveSearch,
                    tooltip: HopeCopy.of(context).copy_save_search,
                    icon: onSaveSearch == null
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                  ),
                  if (savedSearchCount > 0)
                    IconButton.filledTonal(
                      onPressed: onOpenSavedSearches,
                      tooltip: HopeCopy.of(context).copy_saved_searches,
                      icon: const Icon(Icons.bookmarks_outlined),
                    ),
                ],
              ),
              const SizedBox(height: HopeV2Spacing.md),
              SizedBox(
                height: HopeV2Touch.minimum,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip(
                      context,
                      HopeCopy.of(context).copy_all_ba7d5b6,
                      kind == 'ALL',
                      () => onKindChanged('ALL'),
                    ),
                    _chip(
                      context,
                      HopeCopy.of(context).copy_missions_a833d13,
                      kind == 'MISSION',
                      () => onKindChanged('MISSION'),
                      icon: Icons.bolt_rounded,
                    ),
                    _chip(
                      context,
                      HopeCopy.of(context).copy_jobs_ebf9a80,
                      kind == 'JOB',
                      () => onKindChanged('JOB'),
                      icon: Icons.business_center_rounded,
                    ),
                    const SizedBox(width: HopeV2Spacing.sm),
                    _chip(
                      context,
                      HopeCopy.of(context).copy_public_21e97be,
                      visibility == 'PUBLIC',
                      () => onVisibilityChanged('PUBLIC'),
                    ),
                    _chip(
                      context,
                      HopeCopy.of(context).copy_specialized_5d1ca04,
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
                        child: Text(HopeCopy.of(context).copy_retry_49f3eba),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: HopeV2Spacing.sm,
                runSpacing: HopeV2Spacing.sm,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.location_on_outlined, size: 17),
                    label: Text(cityLabel),
                    onPressed: onPickCity,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.category_outlined, size: 17),
                    label: Text(categoryLabel),
                    onPressed: onPickCategory,
                  ),
                ],
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
    IconData? icon,
  }) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          selected: selected,
          label: Text(text),
          avatar: icon == null ? null : Icon(icon, size: 17),
          onSelected: (_) => onTap(),
        ),
      );
}
