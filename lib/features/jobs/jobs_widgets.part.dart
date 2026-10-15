part of 'jobs_page.dart';

String _t(BuildContext context, String fa, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : fa;


// Opportunity presentation is shared by Home and Explore via OpportunityCard.

class _JobsResultsSliver extends StatelessWidget {
  const _JobsResultsSliver({
    required this.jobs,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  final List<HopeJob> jobs;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 56),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            const OpportunitySkeletonCard(),
            const SizedBox(height: 12),
            const OpportunitySkeletonCard(),
          ]),
        ),
      );
    }

    if (hasError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: HopeCopy.of(context).copy_connection_failed_1b34bc9,
          message: HopeCopy.of(context)
              .copy_the_server_did_not_return_data_try_again_bccfbb3,
          action: FilledButton.icon(
            key: const ValueKey('explore-retry-opportunities'),
            onPressed: onRetry,
            icon: const HopeIcon(HopeV2Icons.refresh, size: 18),
            label: Text(_t(context, 'تلاش دوباره', 'Try again')),
          ),
        ),
      );
    }

    if (jobs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: HopeCopy.of(context).copy_no_matching_opportunity_d85e775,
          message: HopeCopy.of(context)
              .copy_broaden_your_filters_or_try_another_city_e8e32cb,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 56),
      sliver: SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Explore remains a readable list on very narrow layouts or when
            // accessibility text scaling makes a two-column card too dense.
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            // Prefer readable single-column cards when users enlarge text;
            // adaptive density must not outrank accessibility readability.
            // Keep a true editorial list on phone widths. The two-column
            // layout makes key opportunity facts too small and cards too tall
            // once real Persian titles and full budget ranges are rendered.
            final columns = textScale > 1.2
                ? 1
                : constraints.maxWidth >= HopeV2Breakpoints.expanded
                    ? 3
                    : constraints.maxWidth >= 420
                        ? 2
                        : 1;
            final recommendedIndex = jobs.indexWhere(
              (job) => job.isRecommended && job.recommendationScore != null,
            );
            final HopeJob? featuredJob = recommendedIndex < 0
                ? null
                : jobs[recommendedIndex];
            // A listing item must not be promoted to "recommended" without a
            // real server-provided recommendation signal.
            final remaining = [
              for (final job in jobs)
                if (featuredJob == null || !identical(job, featuredJob)) job,
            ];

            final opportunitiesLabel = Text(
              _t(
                context,
                featuredJob == null ? 'فرصت‌های موجود' : 'پیشنهادشده برای شما',
                featuredJob == null ? 'Available opportunities' : 'Recommended for you',
              ),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            );

            if (columns == 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  opportunitiesLabel,
                  const SizedBox(height: HopeV2Spacing.xs),
                  if (featuredJob != null)
                    AnimatedEntrance(
                      child: OpportunityCard(
                        job: featuredJob,
                        variant: OpportunityCardVariant.featuredScan,
                      ),
                    ),
                  if (featuredJob != null && remaining.isNotEmpty)
                    const SizedBox(height: HopeV2Spacing.sm),
                  for (var i = 0; i < remaining.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: HopeV2Spacing.sm,
                      ),
                      child: AnimatedEntrance(
                        delay: Duration(
                          milliseconds: 35 * (i + 1).clamp(0, 10),
                        ),
                        child: OpportunityCard(
                          job: remaining[i],
                          // Larger system text needs the roomier editorial card,
                          // not the compressed summary reserved for default scale.
                          variant: textScale > 1.2
                              ? OpportunityCardVariant.standard
                              : OpportunityCardVariant.compact,
                        ),
                      ),
                    ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                opportunitiesLabel,
                const SizedBox(height: HopeV2Spacing.xs),
                if (featuredJob != null)
                  OpportunityCard(
                    job: featuredJob,
                    variant: OpportunityCardVariant.featuredScan,
                  ),
                if (featuredJob != null && remaining.isNotEmpty)
                  const SizedBox(height: HopeV2Spacing.sm),
                if (featuredJob != null && remaining.isNotEmpty)
                  Text(
                    _t(context, 'فرصت‌های بیشتر', 'More opportunities'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                if (featuredJob != null && remaining.isNotEmpty)
                  const SizedBox(height: HopeV2Spacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: remaining.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: HopeV2Spacing.md,
                    mainAxisSpacing: HopeV2Spacing.sm,
                    childAspectRatio: columns == 3 ? 1.04 : 0.86,
                  ),
                  itemBuilder: (context, index) => AnimatedEntrance(
                    delay: Duration(milliseconds: 35 * index.clamp(0, 10)),
                    child: OpportunityCard(
                      job: remaining[index],
                      variant: columns == 2
                          ? OpportunityCardVariant.compactGrid
                          : OpportunityCardVariant.standard,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
