import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/application/application_registry_context.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/marketplace/job.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/theme/app_theme.dart';
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
    required this.onOpenCreate,
  });
  final VoidCallback onOpenExplore;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenCreate;

  @override
  State<PremiumHomeFeed> createState() => _PremiumHomeFeedState();
}

class _PremiumHomeFeedState extends State<PremiumHomeFeed> {
  Future<List<HopeJob>>? _opportunities;
  Future<List<HopeJob>>? _activeJobs;
  Future<HopeWallet>? _wallet;
  String? _error;
  int _refreshRequestId = 0;
  String? _loadSignature;
  int? _activeJobCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<HopeSettingsController>();
    final auth = context.read<AuthController>();
    final signature = [
      settings.city,
      settings.personalizedRecommendations,
      settings.locationEnabled,
      settings.latitude,
      settings.longitude,
      auth.isGuest,
      auth.user?['id']?.toString(),
    ].join('|');
    if (signature == _loadSignature) return;
    _loadSignature = signature;
    _load();
  }

  void _load() {
    final settings = context.read<HopeSettingsController>();
    final registry = applicationRegistryOf(context);
    _error = null;
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
        _activeJobs!.then((jobs) {
          if (!mounted) return;
          setState(() => _activeJobCount = jobs.where((job) =>
              {'ASSIGNED', 'IN_PROGRESS', 'DELIVERED', 'UNDER_REVIEW'}
                  .contains(job.status?.toUpperCase())).length);
        }).catchError((_) {});
        _wallet = registry.walletsOrThrow.getWallet();
      } catch (_) {
        _activeJobs = Future.value(const <HopeJob>[]);
        _activeJobCount = 0;
        _wallet = null;
      }
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final requestId = ++_refreshRequestId;
    setState(() {
      _error = null;
      _opportunities = null;
      _activeJobs = null;
      _activeJobCount = null;
      _wallet = null;
    });
    _load();
    final opportunities = _opportunities;
    try {
      await opportunities;
    } catch (_) {
      if (mounted && requestId == _refreshRequestId) {
        setState(() => _error = 'load');
      }
    }
  }

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<HopeSettingsController>();
    final auth = context.watch<AuthController>();
    return PremiumPageFrame(
      maxWidth: 1180,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Builder(
              builder: (context) {
                final displayName =
                    ((auth.user?['displayName'] as String?)?.trim().isNotEmpty ?? false)
                        ? (auth.user?['displayName'] as String).trim()
                        : _t(context, 'فضای کاری', 'Workspace');
                final initial = displayName.trim().isNotEmpty
                    ? displayName.trim().substring(0, 1).toUpperCase()
                    : 'H';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(context, 'فضای کاری', 'Workspace'),
                                style: HopeV2Type.eyebrow(context),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: HopeV2Type.hero(context),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _refresh,
                          tooltip: _t(context, 'بازخوانی', 'Refresh'),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: HopeV2Colors.primary.withValues(alpha: .16),
                          child: Text(
                            initial,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: HopeV2Spacing.lg),
                    FutureBuilder<List<HopeJob>>(
                      future: _opportunities,
                      builder: (context, pulseSnapshot) {
                        final jobs = pulseSnapshot.data ?? const <HopeJob>[];
                        final matchCount = jobs.where((j) => j.isRecommended).length;
                        final nearbyCount = jobs.where(
                          (j) => j.distanceKm != null || j.city == settings.city,
                        ).length;
                        final locked =
                            _wallet == null ? null : _wallet!.lockedBalance;
                        String money(int value) => value
                            .toString()
                            .replaceAllMapped(
                              RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'),
                              (_) => ',',
                            );
                        Widget metric(String value, String label, IconData icon) {
                          return Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  icon,
                                  size: 17,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }
                        return PremiumPanel(
                          padding: const EdgeInsets.fromLTRB(
                            HopeV2Spacing.lg,
                            HopeV2Spacing.md,
                            HopeV2Spacing.lg,
                            HopeV2Spacing.md,
                          ),
                          highlight: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 17,
                                    color: HopeV2Colors.primaryDark,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    _t(context, 'HOPE Pulse', 'HOPE Pulse'),
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const Spacer(),
                                  Text(
                                    _t(context, 'وضعیت زنده', 'Live status'),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: HopeV2Spacing.lg),
                              Row(
                                children: [
                                  metric(
                                    pulseSnapshot.connectionState ==
                                            ConnectionState.done
                                        ? '$matchCount'
                                        : '—',
                                    _t(context, 'تطابق', 'matches'),
                                    Icons.auto_awesome_outlined,
                                  ),
                                  const SizedBox(width: 12),
                                  metric(
                                    pulseSnapshot.connectionState ==
                                            ConnectionState.done
                                        ? '$nearbyCount'
                                        : '—',
                                    _t(context, 'نزدیک شما', 'near you'),
                                    Icons.near_me_outlined,
                                  ),
                                  const SizedBox(width: 12),
                                  metric(
                                    auth.isGuest
                                        ? '—'
                                        : _activeJobs == null
                                            ? '—'
                                            : _activeJobCount?.toString() ?? '—',
                                    _t(context, 'کار فعال', 'active'),
                                    Icons.bolt_outlined,
                                  ),
                                  if (!auth.isGuest) ...[
                                    const SizedBox(width: 12),
                                    metric(
                                      locked == null ? '—' : money(locked),
                                      _t(context, 'قفل‌شده', 'protected'),
                                      Icons.shield_outlined,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: HopeV2Spacing.xl),
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
            Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: () => Navigator.push(context, HopeRoutes.jobDetail(job)), icon: Icon(
                              Directionality.of(context) == TextDirection.rtl
                                  ? Icons.arrow_back_rounded
                                  : Icons.arrow_forward_rounded,
                            ), label: Text(action))),
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
        String money(int v) =>
            '${v.toString().replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (_) => ',')} '
            '${wallet.currency == 'TOMAN' ? _t(context, 'تومان', 'TOMAN') : wallet.currency}';

        return PremiumPanel(
          highlight: true,
          padding: const EdgeInsets.all(HopeV2Spacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final balance = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(context, 'وضعیت مالی', 'Financial snapshot'),
                    style: HopeV2Type.eyebrow(context),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    money(wallet.availableBalance),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _t(context, 'موجودی قابل استفاده', 'Available balance'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );

              final details = Row(
                mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Flexible(
                    child: PremiumTag(
                      icon: Icons.lock_outline_rounded,
                      label:
                          '${_t(context, 'قفل‌شده', 'Locked')}: ${money(wallet.lockedBalance)}',
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      final repository =
                          applicationRegistryOf(context).walletsOrThrow;
                      Navigator.push(
                        context,
                        HopeRoutes.wallet(repository: repository),
                      );
                    },
                    tooltip: _t(context, 'باز کردن کیف پول', 'Open wallet'),
                    icon: const Icon(Icons.arrow_outward_rounded),
                  ),
                ],
              );

              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        balance,
                        const SizedBox(height: 14),
                        details,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: balance),
                        details,
                      ],
                    );
            },
          ),
        );
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

