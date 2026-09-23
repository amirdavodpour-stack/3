import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
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
  HopeWallet? _walletData;
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
        _wallet!.then((wallet) {
          if (!mounted) return;
          setState(() => _walletData = wallet);
        }).catchError((_) {});
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
      _walletData = null;
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
                    PremiumHeader(
                      eyebrow: _t(context, 'فضای کاری', 'Workspace'),
                      title: displayName,
                      subtitle: settings.city.trim().isEmpty
                          ? null
                          : settings.city,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            onPressed: widget.onOpenMenu,
                            tooltip: _t(context, 'منو', 'App menu'),
                            icon: HugeIcon(icon: HopeV2Icons.menu, size: 21),
                          ),
                          const SizedBox(width: HopeV2Spacing.xs),
                          IconButton.filledTonal(
                            onPressed: _refresh,
                            tooltip: _t(context, 'بازخوانی', 'Refresh'),
                            icon: HugeIcon(icon: HopeV2Icons.refresh, size: 21),
                          ),
                          const SizedBox(width: HopeV2Spacing.xs),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                HopeV2Colors.primary.withValues(alpha: .16),
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
                    ),
                    const SizedBox(height: HopeV2Spacing.xl),
                    FutureBuilder<List<HopeJob>>(
                      future: _opportunities,
                      builder: (context, pulseSnapshot) {
                        final jobs = pulseSnapshot.data ?? const <HopeJob>[];
                        final matchCount = jobs.where((j) => j.isRecommended).length;
                        final nearbyCount = jobs.where(
                          (j) => j.distanceKm != null || j.city == settings.city,
                        ).length;
                        String money(int value) => value
                            .toString()
                            .replaceAllMapped(
                              RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'),
                              (_) => ',',
                            );

                        final metrics = <Widget>[
                          PremiumStatCard(
                            value: pulseSnapshot.connectionState ==
                                    ConnectionState.done
                                ? '$matchCount'
                                : '—',
                            label: _t(context, 'تطابق', 'matches'),
                            icon: HopeV2Icons.match,
                            accent: HopeV2Colors.primary,
                          ),
                          PremiumStatCard(
                            value: pulseSnapshot.connectionState ==
                                    ConnectionState.done
                                ? '$nearbyCount'
                                : '—',
                            label: _t(context, 'نزدیک شما', 'near you'),
                            icon: HopeV2Icons.distance,
                            accent: HopeV2Colors.secondary,
                          ),
                          PremiumStatCard(
                            value: auth.isGuest
                                ? '—'
                                : _activeJobs == null
                                    ? '—'
                                    : _activeJobCount?.toString() ?? '—',
                            label: _t(context, 'کار فعال', 'active'),
                            icon: HopeV2Icons.mission,
                            accent: HopeV2Colors.primary,
                          ),
                          if (!auth.isGuest)
                            PremiumStatCard(
                              value: _walletData?.lockedBalance == null
                                  ? '—'
                                  : money(_walletData!.lockedBalance),
                              label: _t(context, 'قفل‌شده', 'protected'),
                              icon: HopeV2Icons.protectedFunds,
                              accent: HopeV2Colors.warning,
                            ),
                        ];

                        return PremiumPanel(
                          padding: const EdgeInsets.fromLTRB(
                            HopeV2Spacing.lg,
                            HopeV2Spacing.md,
                            HopeV2Spacing.lg,
                            HopeV2Spacing.lg,
                          ),
                          highlight: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  HugeIcon(
                                    icon: HopeV2Icons.featured,
                                    size: 17,
                                    color: HopeV2Colors.primaryDark,
                                    strokeWidth: 1.9,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    _t(context, 'HOPE Pulse', 'HOPE Pulse'),
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const Spacer(),
                                  PremiumTag(
                                    icon: HopeV2Icons.insights,
                                    label: _t(
                                      context,
                                      'وضعیت زنده',
                                      'Live status',
                                    ),
                                    color: HopeV2Colors.secondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: HopeV2Spacing.md),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns = constraints.maxWidth >= 760
                                      ? metrics.length
                                      : constraints.maxWidth >= 500
                                          ? 2
                                          : 1;
                                  final gap = HopeV2Spacing.md;
                                  final width =
                                      (constraints.maxWidth -
                                              gap * (columns - 1)) /
                                          columns;
                                  return Wrap(
                                    spacing: gap,
                                    runSpacing: gap,
                                    children: [
                                      for (final metric in metrics)
                                        SizedBox(
                                          width: width,
                                          child: metric,
                                        ),
                                    ],
                                  );
                                },
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
            _quickActions(context, auth),
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
                    action: FilledButton.icon(onPressed: _refresh, icon: HugeIcon(icon: HopeV2Icons.refresh, size: 20), label: Text(_t(context, 'تلاش دوباره', 'Retry'))),
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

  Widget _quickActions(BuildContext context, AuthController auth) {
    final actions = <_HomeQuickAction>[
      _HomeQuickAction(
        label: _t(context, 'کاوش فرصت‌ها', 'Explore opportunities'),
        caption: _t(context, 'بازار فرصت‌ها را بررسی کنید.', 'Browse the opportunity marketplace.'),
        icon: HopeV2Icons.workshop,
        color: HopeV2Colors.primary,
        onTap: widget.onOpenExplore,
      ),
      _HomeQuickAction(
        label: _t(context, 'ثبت فرصت جدید', 'Post an opportunity'),
        caption: _t(context, 'یک نیاز کاری جدید منتشر کنید.', 'Publish a new work request.'),
        icon: HopeV2Icons.add,
        color: HopeV2Colors.secondary,
        onTap: widget.onOpenCreate,
      ),
      if (!auth.isGuest)
        _HomeQuickAction(
          label: _t(context, 'کیف پول', 'Wallet'),
          caption: _t(context, 'موجودی و گردش مالی را ببینید.', 'Review balance and money activity.'),
          icon: HopeV2Icons.wallet,
          color: HopeV2Colors.warning,
          onTap: () {
            final repository = applicationRegistryOf(context).walletsOrThrow;
            Navigator.push(context, HopeRoutes.wallet(repository: repository));
          },
        ),
      if (!auth.isGuest)
        _HomeQuickAction(
          label: _t(context, 'فعالیت‌ها', 'Activity'),
          caption: _t(context, 'کارها و تراکنش‌های اخیر را ببینید.', 'Review recent work and transactions.'),
          icon: HopeV2Icons.activity,
          color: HopeV2Colors.secondaryStrong,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TransactionsPage(
                  repository: context.read<TransactionRepository>(),
                ),
              ),
            );
          },
        ),
    ];

    return PremiumPanel(
      padding: const EdgeInsets.all(HopeV2Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            title: _t(context, 'دسترسی سریع', 'Quick access'),
            subtitle: _t(
              context,
              'مسیرهای اصلی بدون خروج از صفحه اصلی در دسترس‌اند.',
              'Keep the primary actions close to the home surface.',
            ),
          ),
          const SizedBox(height: HopeV2Spacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760
                  ? actions.length.clamp(2, 4)
                  : constraints.maxWidth >= 500
                      ? 2
                      : 1;
              final gap = HopeV2Spacing.sm;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final action in actions)
                    SizedBox(width: width, child: action),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _opportunitySections(BuildContext context, List<HopeJob> jobs, HopeSettingsController settings) {
    final recommended = jobs.where((j) => j.isRecommended).toList();
    final nearby = jobs
        .where((j) => j.distanceKm != null || j.city == settings.city)
        .toList();
    final used = {...recommended, ...nearby};
    final remaining = jobs.where((j) => !used.contains(j)).toList();

    if (jobs.isEmpty) {
      return PremiumPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t(context, 'فعلاً فرصت مرتبطی پیدا نشد', 'No matching opportunities yet'),
              style: HopeV2Type.section(context),
            ),
            const SizedBox(height: HopeV2Spacing.sm),
            Text(
              _t(
                context,
                'می‌توانید در Explore فیلترها را بازتر کنید.',
                'Try broadening filters in Explore.',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: HopeV2Spacing.lg),
            OutlinedButton.icon(
              onPressed: widget.onOpenExplore,
              icon: HugeIcon(icon: HopeV2Icons.workshop, size: 18),
              label: Text(_t(context, 'رفتن به Explore', 'Open Explore')),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recommended.isNotEmpty) ...[
          PremiumSectionHeader(
            title: _t(context, 'پیشنهاد ویژه', 'Best match'),
            subtitle: _t(
              context,
              'فرصتی که بیشترین سیگنال تطابق را دارد.',
              'The opportunity with the strongest match signals.',
            ),
          ),
          const SizedBox(height: HopeV2Spacing.md),
          OpportunityCard(
            job: recommended.first,
            variant: OpportunityCardVariant.featured,
          ),
          const SizedBox(height: HopeV2Spacing.xl),
          _section(
            context,
            _t(context, 'تطابق‌ها', 'Matches'),
            recommended.skip(1).take(3).toList(),
            widget.onOpenExplore,
          ),
        ] else ...[
          PremiumSectionHeader(
            title: _t(context, 'فرصت‌ها', 'Opportunities'),
            subtitle: _t(
              context,
              '${jobs.length} فرصت',
              '${jobs.length} opportunities',
            ),
          ),
        ],
        const SizedBox(height: HopeV2Spacing.section),
        _section(
          context,
          _t(context, 'نزدیک شما', 'Near you'),
          nearby.take(3).toList(),
          widget.onOpenExplore,
        ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: HopeV2Spacing.section),
          _section(
            context,
            _t(context, 'سایر فرصت‌ها', 'Other opportunities'),
            remaining.take(4).toList(),
            widget.onOpenExplore,
          ),
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
            Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton.icon(onPressed: () => Navigator.push(context, HopeRoutes.jobDetail(job)), icon: HugeIcon(
                              icon: Directionality.of(context) == TextDirection.rtl
                                  ? HopeV2Icons.arrowLeft
                                  : HopeV2Icons.arrowRight,
                              size: 19,
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
                      icon: HopeV2Icons.secure,
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
                    icon: HugeIcon(icon: HopeV2Icons.arrowRight, size: 19),
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


class _HomeQuickAction extends StatelessWidget {
  const _HomeQuickAction({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final Object icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label. $caption',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HopeV2Radii.md),
          child: Ink(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.all(HopeV2Spacing.md),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(HopeV2Radii.md),
              border: Border.all(color: color.withValues(alpha: .13)),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: HopeIconTile(icon, color: color, filled: true, size: 42),
                ),
                const SizedBox(width: HopeV2Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: HopeV2Spacing.xs),
                HugeIcon(
                  icon: Directionality.of(context) == ui.TextDirection.rtl
                      ? HopeV2Icons.arrowLeft
                      : HopeV2Icons.arrowRight,
                  size: 18,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
