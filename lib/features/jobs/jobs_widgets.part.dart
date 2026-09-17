part of 'jobs_page.dart';

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
            if (columns == 1) {
              return Column(
                children: [
                  for (var i = 0; i < jobs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: HopeV2Spacing.md,
                      ),
                      child: AnimatedEntrance(
                        delay: Duration(
                          milliseconds: 35 * i.clamp(0, 10),
                        ),
                        child: OpportunityCard(job: jobs[i]),
                      ),
                    ),
                ],
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jobs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: HopeV2Spacing.md,
                mainAxisSpacing: HopeV2Spacing.md,
                childAspectRatio: columns == 3 ? 1.04 : 1.12,
              ),
              itemBuilder: (context, index) => AnimatedEntrance(
                delay: Duration(milliseconds: 35 * index.clamp(0, 10)),
                child: OpportunityCard(job: jobs[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}
