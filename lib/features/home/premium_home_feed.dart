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
    final displayName =
        ((auth.user?['displayName'] as String?)?.trim().isNotEmpty ?? false)
            ? (auth.user?['displayName'] as String).trim()
            : _t(context, 'فضای کاری', 'Workspace');
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'H';
    final avatarUrl = [
      auth.user?['photoUrl'],
      auth.user?['avatarUrl'],
      auth.user?['imageUrl'],
    ].map((value) => value?.toString().trim()).firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );

    return PremiumPageFrame(
      maxWidth: 1180,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, 'فضای کاری', 'Workspace'),
                          style: HopeV2Type.eyebrow(context).copyWith(
                            color: HopeV2Colors.secondaryDark,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _t(
                            context,
                            auth.isGuest
                                ? 'فرصت‌های مناسب خود را پیدا کنید'
                                : 'فرصت‌ها و کارهای شما',
                            auth.isGuest
                                ? 'Find opportunities that fit you'
                                : 'Your opportunities and active work',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: 25,
                                letterSpacing: -.65,
                              ),
                        ),
                        if (settings.city.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              settings.city,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    container: true,
                    explicitChildNodes: true,
                    label: _t(context, 'منو', 'App menu'),
                    child: ExcludeSemantics(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: widget.onOpenMenu,
                          child: Ink(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  HopeV2Colors.primary.withValues(alpha: .92),
                                  HopeV2Colors.secondary.withValues(alpha: .72),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: HopeV2Colors.primary.withValues(alpha: .22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: avatarUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      avatarUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
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
                final matchCount =
                    jobs.where((j) => j.isRecommended).length;
                final nearbyCount = jobs
                    .where((j) => j.distanceKm != null || j.city == settings.city)
                    .length;
                final activeCount = auth.isGuest
                    ? '—'
                    : _activeJobCount?.toString() ?? '—';
                final protected = !auth.isGuest && _walletData != null
                    ? _walletData!.lockedBalance.toString()
                    : '—';

                final stats = <({String value, String label, Object icon, Color accent})>[
                  (
                    value: pulseSnapshot.connectionState == ConnectionState.done
                        ? '$matchCount'
                        : '—',
                    label: _t(context, 'تطابق', 'matches'),
                    icon: HopeV2Icons.match,
                    accent: HopeV2Colors.primary,
                  ),
                  (
                    value: pulseSnapshot.connectionState == ConnectionState.done
                        ? '$nearbyCount'
                        : '—',
                    label: _t(context, 'نزدیک', 'near you'),
                    icon: HopeV2Icons.distance,
                    accent: HopeV2Colors.secondary,
                  ),
                  (
                    value: activeCount,
                    label: _t(context, 'فعال', 'active'),
                    icon: HopeV2Icons.mission,
                    accent: HopeV2Colors.primary,
                  ),
                  (
                    value: protected,
                    label: _t(context, 'محافظت‌شده', 'protected'),
                    icon: HopeV2Icons.protectedFunds,
                    accent: HopeV2Colors.warningDark,
                  ),
                ];

                return PremiumPanel(
                  padding: const EdgeInsets.all(HopeV2Spacing.lg),
                  highlight: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: HopeV2Colors.primary.withValues(alpha: .14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: HopeV2Colors.primary.withValues(alpha: .26),
                              ),
                            ),
                            child: Center(
                              child: HopeIcon(
                                HopeV2Icons.featured,
                                size: 15,
                                color: HopeV2Colors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              _t(context, 'HOPE Pulse', 'HOPE Pulse'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          PremiumTag(
                            icon: HopeV2Icons.insights,
                            label: _t(context, 'زنده', 'Live'),
                            color: HopeV2Colors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: HopeV2Spacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Mobile keeps the pulse readable as a 2x2 metric grid;
                          // desktop can expand to four compact metrics.
                          final columns = constraints.maxWidth < 540 ? 2 : 4;
                          final gap = HopeV2Spacing.sm;
                          final width =
                              (constraints.maxWidth - gap * (columns - 1)) /
                                  columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (var index = 0; index < stats.length; index++)
                                SizedBox(
                                  key: ValueKey('home-pulse-stat-$index'),
                                  width: width,
                                  child: _homePulseStat(
                                    context,
                                    value: stats[index].value,
                                    label: stats[index].label,
                                    icon: stats[index].icon,
                                    accent: stats[index].accent,
                                  ),
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
                    title: _t(
                      context,
                      'فرصت‌ها در دسترس نیستند',
                      'Opportunities are unavailable',
                    ),
                    message: _t(
                      context,
                      'اتصال را بررسی کنید و دوباره تلاش کنید.',
                      'Check your connection and try again.',
                    ),
                    action: FilledButton.icon(
                      onPressed: _refresh,
                      icon: HugeIcon(
                        icon: HopeV2Icons.refresh,
                        size: 20,
                      ),
                      label: Text(_t(context, 'تلاش دوباره', 'Retry')),
                    ),
                  );
                }
                final jobs = snapshot.data ?? const <HopeJob>[];
                return _opportunitySections(context, jobs, settings);
              },
            ),
            const SizedBox(height: HopeV2Spacing.xl),
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

  Widget _homePulseStat(
    BuildContext context, {
    required String value,
    required String label,
    required Object icon,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: HopeV2Colors.panelSoftDark,
        borderRadius: BorderRadius.circular(HopeV2Radii.md),
        border: Border.all(
          color: accent.withValues(alpha: .14),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 112;
          final metric = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HopeV2Type.metric(context).copyWith(
                  fontSize: compact ? 17 : (value.length > 7 ? 15 : 20),
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: HopeV2Colors.darkMuted,
                    ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ExcludeSemantics(
                  child: HopeIcon(
                    icon,
                    size: 16,
                    color: accent,
                    strokeWidth: 1.9,
                  ),
                ),
                const SizedBox(height: 5),
                metric,
              ],
            );
          }
          return Row(
            children: [
              ExcludeSemantics(
                child: HopeIcon(
                  icon,
                  size: 17,
                  color: accent,
                  strokeWidth: 1.9,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(child: metric),
            ],
          );
        },
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

