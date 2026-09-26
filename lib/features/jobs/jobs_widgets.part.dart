part of 'jobs_page.dart';

String _t(BuildContext context, String fa, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : fa;


// Opportunity presentation is shared by Home and Explore via OpportunityCard.

class _JobsResultsSliver extends StatelessWidget {
  const _JobsResultsSliver({
    required this.jobs,
    required this.isLoading,
    required this.hasError,
  });

  final List<HopeJob> jobs;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 122),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 122),
      sliver: SliverToBoxAdapter(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= HopeV2Breakpoints.expanded
                ? 3
                : constraints.maxWidth >= HopeV2Breakpoints.medium
                    ? 2
                    : 1;
            final featuredJob = jobs.firstWhere(
              (job) => job.isRecommended && job.recommendationScore != null,
              orElse: () => jobs.first,
            );
            final remaining = [
              for (final job in jobs)
                if (!identical(job, featuredJob)) job,
            ];

            if (columns == 1) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PremiumSectionHeader(
                    title: _t(context, 'پیشنهاد منتخب', 'Featured opportunity'),
                    subtitle: _t(
                      context,
                      'اولویت با فرصتی است که بیشترین سیگنال تطابق را دارد.',
                      'Lead with the opportunity carrying the strongest match signal.',
                    ),
                  ),
                  const SizedBox(height: HopeV2Spacing.md),
                  AnimatedEntrance(
                    child: OpportunityCard(
                      job: featuredJob,
                      variant: OpportunityCardVariant.featured,
                    ),
                  ),
                  if (remaining.isNotEmpty)
                    const SizedBox(height: HopeV2Spacing.lg),
                  for (var i = 0; i < remaining.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: HopeV2Spacing.md,
                      ),
                      child: AnimatedEntrance(
                        delay: Duration(
                          milliseconds: 35 * (i + 1).clamp(0, 10),
                        ),
                        child: OpportunityCard(job: remaining[i]),
                      ),
                    ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OpportunityCard(
                  job: featuredJob,
                  variant: OpportunityCardVariant.featured,
                ),
                if (remaining.isNotEmpty)
                  const SizedBox(height: HopeV2Spacing.xl),
                if (remaining.isNotEmpty)
                  Text(
                    _t(context, 'فرصت‌های بیشتر', 'More opportunities'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (remaining.isNotEmpty)
                  const SizedBox(height: HopeV2Spacing.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: remaining.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: HopeV2Spacing.md,
                    mainAxisSpacing: HopeV2Spacing.md,
                    childAspectRatio: columns == 3 ? 1.04 : 1.12,
                  ),
                  itemBuilder: (context, index) => AnimatedEntrance(
                    delay: Duration(milliseconds: 35 * index.clamp(0, 10)),
                    child: OpportunityCard(job: remaining[index]),
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
