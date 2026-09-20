import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/application/application_registry_context.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/marketplace/job.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/transactions/wallet.dart';
import '../../core/ui/components.dart';
import '../../core/ui/opportunity_card.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/ui/premium_components.dart';

class PremiumHomeFeed extends StatefulWidget {
  const PremiumHomeFeed({
    super.key,
    required this.onOpenExplore,
    required this.onOpenMenu,
  });
  final VoidCallback onOpenExplore;
  final VoidCallback onOpenMenu;

  @override
  State<PremiumHomeFeed> createState() => _PremiumHomeFeedState();
}

class _PremiumHomeFeedState extends State<PremiumHomeFeed> {
  Future<List<HopeJob>>? _opportunities;
  Future<List<HopeJob>>? _activeJobs;
  Future<HopeWallet>? _wallet;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opportunities != null) return;
    _load();
  }

  void _load() {
    final settings = context.read<HopeSettingsController>();
    final registry = applicationRegistryOf(context);
    try {
      _opportunities = registry.listOpportunities(
        city: settings.personalizedRecommendations ? settings.city : null,
        personalizedRecommendations: settings.personalizedRecommendations,
        latitude: settings.locationEnabled ? settings.latitude : null,
        longitude: settings.locationEnabled ? settings.longitude : null,
      );
    } catch (_) {
      // A focused host/test may intentionally provide only the settings/auth
      // surface. Discovery is read-only, so an unavailable repository should
      // degrade to an empty state rather than crash the entire shell.
      _opportunities = Future.value(const <HopeJob>[]);
      _error = 'load';
    }
    final auth = context.read<AuthController>();
    if (!auth.isGuest) {
      try {
        _activeJobs = registry.listMyJobs();
        _wallet = registry.walletsOrThrow.getWallet();
      } catch (_) {
        _activeJobs = Future.value(const <HopeJob>[]);
        _wallet = null;
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _error = null;
      _opportunities = null;
      _activeJobs = null;
      _wallet = null;
    });
    _load();
    try {
      await _opportunities;
    } catch (_) {
      if (mounted) setState(() => _error = 'load');
    }
  }

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<HopeSettingsController>();
    final auth = context.watch<AuthController>();
    if (_opportunities == null) _load();

    return PremiumPageFrame(
      maxWidth: 1180,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PremiumSectionHeader(
              title: _t(context, 'خانه', 'Home'),
              subtitle: _t(
                context,
                'فرصت، کار فعال و وضعیت مالی را یکجا ببینید.',
                'Opportunities, active work, and finances in one place.',
              ),
              action: IconButton.filledTonal(
                onPressed: widget.onOpenMenu,
                tooltip: _t(context, 'منوی برنامه', 'App menu'),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            const SizedBox(height: HopeV2Spacing.lg),
            PremiumHero(
              eyebrow: _t(context, 'بازار کار', 'Work marketplace'),
              title: _t(context, 'فرصت مناسب خود را پیدا کنید', 'Find the right opportunity'),
              message: _t(
                context,
                'ماموریت و شغل را جست‌وجو کنید یا فرصت جدید ثبت کنید.',
                'Search missions and jobs, or post a new opportunity.',
              ),
              icon: Icons.work_outline_rounded,
              height: 272,
              action: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: widget.onOpenExplore,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(_t(context, 'جست‌وجوی فرصت‌ها', 'Explore opportunities')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      HopeRoutes.createJob(),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_t(context, 'ثبت فرصت جدید', 'Post opportunity')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: HopeV2Spacing.xl),
            if (!auth.isGuest)
              PremiumPanel(
                highlight: true,
                padding: const EdgeInsets.all(HopeV2Spacing.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final name =
                        ((auth.user?['displayName'] as String?)?.trim().isNotEmpty ??
                                false)
                            ? (auth.user?['displayName'] as String).trim()
                            : _t(context, 'حساب کاربری', 'Account');
                    final account = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, 'فضای کاری', 'Workspace'),
                          style: HopeV2Type.eyebrow(context),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t(
                            context,
                            'وضعیت حساب، کارهای فعال و کیف پول.',
                            'Account status, active work, and wallet.',
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                    final action = FilledButton.tonalIcon(
                      onPressed: () => Navigator.push(
                        context,
                        HopeRoutes.profile(),
                      ),
                      icon: const Icon(Icons.person_outline_rounded),
                      label: Text(_t(context, 'پروفایل', 'Profile')),
                    );
                    return compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [account, const SizedBox(height: 12), action],
                          )
                        : Row(
                            children: [
                              Expanded(child: account),
                              action,
                            ],
                          );
                  },
                ),
              ),
            if (!auth.isGuest) const SizedBox(height: HopeV2Spacing.xl),
            FutureBuilder<List<HopeJob>>(
              future: _opportunities,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PulseSkeleton();
                }
                if (snapshot.hasError || _error != null) {
                  return HopeAsyncState(
                    kind: HopeStateKind.error,
                    title: _t(context, 'فرصت‌ها در دسترس نیستند', 'Opportunities are unavailable'),
                    message: _t(context, 'اتصال را بررسی کنید و دوباره تلاش کنید.', 'Check your connection and try again.'),
                    action: FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: Text(_t(context, 'تلاش دوباره', 'Retry'))),
                  );
                }
                final jobs = snapshot.data ?? const <HopeJob>[];
                return _opportunitySections(context, jobs, settings);
              },
            ),
            if (!auth.isGuest) ...[
              const SizedBox(height: HopeV2Spacing.section),
              _activeWork(context),
              const SizedBox(height: HopeV2Spacing.section),
              _financialSnapshot(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _opportunitySections(BuildContext context, List<HopeJob> jobs, HopeSettingsController settings) {
    final recommended = jobs.where((j) => j.isRecommended).toList();
    final nearby = jobs.where((j) => j.distanceKm != null || j.city == settings.city).toList();
    final used = {...recommended, ...nearby};
    final remaining = jobs.where((j) => !used.contains(j)).toList();
    if (jobs.isEmpty) {
      return PremiumPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t(context, 'فعلاً فرصت مرتبطی پیدا نشد', 'No matching opportunities yet'), style: HopeV2Type.section(context)),
          const SizedBox(height: HopeV2Spacing.sm),
          Text(_t(context, 'می‌توانید در Explore فیلترها را بازتر کنید.', 'Try broadening filters in Explore.'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: HopeV2Spacing.lg),
          OutlinedButton.icon(onPressed: widget.onOpenExplore, icon: const Icon(Icons.explore_outlined), label: Text(_t(context, 'رفتن به Explore', 'Open Explore'))),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumSectionHeader(
          title: _t(context, 'فرصت‌ها', 'Opportunities'),
          subtitle: _t(context, '\${jobs.length} فرصت', '\${jobs.length} opportunities'),
        ),
        const SizedBox(height: HopeV2Spacing.lg),
        if (recommended.isNotEmpty) ...[
          OpportunityCard(job: recommended.first, variant: OpportunityCardVariant.featured),
          const SizedBox(height: HopeV2Spacing.lg),
        ],
        _section(context, _t(context, 'تطابق‌ها', 'Matches'), recommended.skip(recommended.isNotEmpty ? 1 : 0).take(3).toList(), widget.onOpenExplore),
        const SizedBox(height: HopeV2Spacing.section),
        _section(context, _t(context, 'نزدیک شما', 'Near you'), nearby.take(3).toList(), widget.onOpenExplore),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.section),
          _section(context, _t(context, 'سایر فرصت‌ها', 'Other opportunities'), remaining.take(4).toList(), widget.onOpenExplore),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<HopeJob> jobs, VoidCallback action) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PremiumSectionHeader(title: title, action: TextButton(onPressed: action, child: Text(_t(context, 'مشاهده همه', 'View all')))),
      const SizedBox(height: HopeV2Spacing.md),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= HopeV2Breakpoints.expanded ? 3 : constraints.maxWidth >= HopeV2Breakpoints.medium ? 2 : 1;
        if (columns == 1) return Column(children: [for (final j in jobs) Padding(padding: const EdgeInsets.only(bottom: HopeV2Spacing.md), child: OpportunityCard(job: j))]);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: jobs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: HopeV2Spacing.md, mainAxisSpacing: HopeV2Spacing.md, childAspectRatio: columns == 3 ? 1.05 : 1.18),
          itemBuilder: (_, i) => OpportunityCard(job: jobs[i]),
        );
      }),
    ]);
  }

  Widget _activeWork(BuildContext context) {
    return FutureBuilder<List<HopeJob>>(
      future: _activeJobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const _PulseSkeleton();
        final jobs = (snapshot.data ?? const <HopeJob>[]).where((j) => {'ASSIGNED','IN_PROGRESS','DELIVERED','UNDER_REVIEW'}.contains(j.status?.toUpperCase())).toList();
        if (jobs.isEmpty) return const SizedBox.shrink();
        final job = jobs.first;
        final state = job.status?.toUpperCase() ?? '';
        final action = switch (state) {
          'ASSIGNED' => _t(context, 'شروع کار', 'Start work'),
          'IN_PROGRESS' => _t(context, 'ادامه کار', 'Continue work'),
          'DELIVERED' || 'UNDER_REVIEW' => _t(context, 'پیگیری تحویل', 'Review delivery'),
          _ => _t(context, 'مشاهده پروژه', 'Open project'),
        };
        return PremiumPanel(
          highlight: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PremiumSectionHeader(title: _t(context, 'اقدام بعدی شما', 'Your next action'), subtitle: _t(context, 'اولویت با کاری است که همین حالا فعال است.', 'Active work takes priority over discovery.')),
            const SizedBox(height: HopeV2Spacing.lg),
            OpportunityCard(job: job, variant: OpportunityCardVariant.compact),
            const SizedBox(height: HopeV2Spacing.md),
            Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: () => Navigator.push(context, HopeRoutes.jobDetail(job)), icon: const Icon(Icons.arrow_forward_rounded), label: Text(action))),
          ]),
        );
      },
    );
  }

  Widget _financialSnapshot(BuildContext context) {
    return FutureBuilder<HopeWallet>(
      future: _wallet,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final wallet = snapshot.data!;
        String money(int v) => '${v.toString().replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (_) => ',')} ${wallet.currency == 'TOMAN' ? _t(context, 'تومان', 'TOMAN') : wallet.currency}';
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          PremiumSectionHeader(title: _t(context, 'وضعیت مالی', 'Financial snapshot')),
          const SizedBox(height: HopeV2Spacing.md),
          LayoutBuilder(builder: (_, c) {
            final two = c.maxWidth >= HopeV2Breakpoints.compact;
            final children = [
              PremiumStatCard(label: _t(context, 'قابل استفاده', 'Available'), value: money(wallet.availableBalance), icon: Icons.account_balance_wallet_outlined),
              PremiumStatCard(label: _t(context, 'قفل‌شده', 'Locked'), value: money(wallet.lockedBalance), icon: Icons.lock_outline_rounded),
            ];
            return two ? Row(children: [Expanded(child: children[0]), const SizedBox(width: HopeV2Spacing.md), Expanded(child: children[1])]) : Column(children: [children[0], const SizedBox(height: HopeV2Spacing.md), children[1]]);
          }),
        ]);
      },
    );
  }
}

class _PulseSkeleton extends StatelessWidget {
  const _PulseSkeleton();
  @override
  Widget build(BuildContext context) => const Column(children: [
    OpportunitySkeletonCard(),
    SizedBox(height: HopeV2Spacing.md),
    OpportunitySkeletonCard(),
  ]);
}

