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
    required this.cityIsExplicit,
    required this.categoryLabel,
    required this.categoryError,
    required this.onKindChanged,
    required this.onVisibilityChanged,
    required this.onPickCity,
    required this.onPickCategory,
    required this.onRetryCategories,
    required this.savedSearchCount,
    required this.onSaveSearch,
    required this.onOpenSavedSearches,
  });

  final int activeCount;
  final String kind;
  final String visibility;
  final String cityLabel;
  final bool cityIsExplicit;
  final String categoryLabel;
  final String? categoryError;
  final ValueChanged<String> onKindChanged;
  final ValueChanged<String> onVisibilityChanged;
  final VoidCallback onPickCity;
  final VoidCallback onPickCategory;
  final VoidCallback onRetryCategories;
  final int savedSearchCount;
  final VoidCallback? onSaveSearch;
  final VoidCallback onOpenSavedSearches;

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
            if (savedSearchCount > 0 || onSaveSearch != null) ...[
              const SizedBox(height: HopeV2Spacing.md),
              Wrap(
                spacing: HopeV2Spacing.sm,
                runSpacing: HopeV2Spacing.xs,
                children: [
                  if (savedSearchCount > 0)
                    TextButton.icon(
                      onPressed: onOpenSavedSearches,
                      icon: const HopeIcon(HopeV2Icons.savedSearches, size: 18),
                      label: Text(
                        _t(
                          context,
                          'جستجوهای ذخیره‌شده · $savedSearchCount',
                          'Saved searches · $savedSearchCount',
                        ),
                      ),
                    ),
                  if (onSaveSearch != null)
                    TextButton.icon(
                      onPressed: onSaveSearch,
                      icon: const HopeIcon(HopeV2Icons.add, size: 18),
                      label: Text(_t(context, 'ذخیره این جستجو', 'Save this search')),
                    ),
                ],
              ),
            ],
            const SizedBox(height: HopeV2Spacing.md),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PremiumIconButton(
          key: const ValueKey('hope-opportunity-refinement-launcher'),
          icon: HopeV2Icons.filter,
          tooltip: label,
          selected: activeCount > 0,
          onPressed: () => _open(context),
        ),
        if (activeCount > 0)
          PositionedDirectional(
            top: -2,
            end: -2,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(HopeV2Radii.pill),
                  border: Border.all(
                    color: HopeV2Surfaces.page(context),
                    width: 1.5,
                  ),
                ),
                key: const ValueKey('hope-opportunity-refinement-active-count'),
                child: Text(
                  '$activeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
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
    required this.cityIsExplicit,
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
  final bool cityIsExplicit;
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
    final compact =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final filterCount = [
      if (kind != 'ALL') 1,
      if (visibility != 'ALL') 1,
      if (cityIsExplicit) 1,
      if (categoryLabel.trim().isNotEmpty &&
          categoryLabel != copy.copy_all_fields_4f77401)
        1,
    ].length;

    final searchField = PremiumSearchBar(
      onChanged: onQueryChanged,
      hint: compact
          ? _t(context, 'جستجو', 'Search')
          : copy.copy_title_city_or_skill_bccb024,
    );
    final refinement = HopeOpportunityRefinementLauncher(
      activeCount: filterCount,
      kind: kind,
      visibility: visibility,
      cityLabel: cityLabel,
      cityIsExplicit: cityIsExplicit,
      categoryLabel: categoryLabel,
      categoryError: categoryError,
      onKindChanged: onKindChanged,
      onVisibilityChanged: onVisibilityChanged,
      onPickCity: onPickCity,
      onPickCategory: onPickCategory,
      onRetryCategories: onRetryCategories,
      savedSearchCount: savedSearchCount,
      onSaveSearch: onSaveSearch,
      onOpenSavedSearches: onOpenSavedSearches,
    );
    final resultLabel = Text(
      '$resultCount ${copy.copy_results_2d120a3}',
      key: const ValueKey('hope-explore-result-count'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: HopeV2Colors.muted,
            fontWeight: FontWeight.w800,
          ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact) ...[
          searchField,
          const SizedBox(height: 6),
          Row(
            children: [
              resultLabel,
              const Spacer(),
              refinement,
            ],
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: searchField),
              const SizedBox(width: HopeV2Spacing.sm),
              resultLabel,
              const SizedBox(width: HopeV2Spacing.sm),
              refinement,
            ],
          ),
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