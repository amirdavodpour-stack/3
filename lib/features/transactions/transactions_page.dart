import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import 'package:provider/provider.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/transactions/payment.dart';
import '../../core/marketplace/job.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/ui/components.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/uploads/upload_queue.dart';
import '../../core/router/app_routes.dart';
import '../../core/application/application_registry.dart';

import '../../core/ui/premium_components.dart';
import '../../core/ui/premium_lifecycle.dart';
import '../../core/ui/premium_payment_summary.dart';
import '../../core/ui/hope_async_state.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    this.repository,
    this.showPrimaryNavigation = true,
  });

  final TransactionRepository? repository;
  final bool showPrimaryNavigation;
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  Future<List<HopeJob>>? future;
  String? loadedUserId;
  String? _reloadError;
  int _reloadRequestId = 0;
  final Map<String, Future<HopePayment?>> _paymentFutures =
      <String, Future<HopePayment?>>{};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.read<AuthController>().user?['id']?.toString();
    if (id != loadedUserId) {
      loadedUserId = id;
      _reloadError = null;
      final ApplicationRegistry registry = applicationRegistryOf(context);
      final source = widget.repository;
      future = id == null
          ? null
          : (source ?? registry.transactionsOrThrow).listMyJobs();
      _paymentFutures.clear();
    }
  }

  Future<void> reload() async {
    if (!mounted) return;
    final requestId = ++_reloadRequestId;
    final source = widget.repository ?? applicationRegistryOf(context).transactionsOrThrow;
    final next = source.listMyJobs();
    try {
      final items = await next;
      if (!mounted || requestId != _reloadRequestId) return;
      setState(() {
        _reloadError = null;
        future = Future<List<HopeJob>>.value(items);
      });
      _paymentFutures.clear();
    } catch (_) {
      if (!mounted || requestId != _reloadRequestId) return;
      setState(() {
        _reloadError = HopeCopy.of(context).copy_could_not_load_activity_335b923;
      });
    }
  }

  Future<HopePayment?> _tryGetPayment(String jobId) {
    return _paymentFutures.putIfAbsent(jobId, () async {
      try {
        final source = widget.repository ?? applicationRegistryOf(context).transactionsOrThrow;
        return await source.getPayment(jobId);
      } catch (_) {
        // Payment details are supplementary to the activity list. A missing,
        // unavailable, or not-yet-created payment must never make the whole
        // authenticated transactions page fail to render.
        return null;
      }
    });
  }

  String _jobStatusLabel(BuildContext context, String rawStatus) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    final labels = en ? <String, String>{
      'PUBLISHED': 'Published',
      'ASSIGNED': 'Assigned',
      'IN_PROGRESS': 'In progress',
      'DELIVERED': 'Delivered',
      'UNDER_REVIEW': 'Under review',
      'COMPLETED': 'Completed',
      'RELEASED': 'Settled',
      'SETTLED': 'Settled',
    } : <String, String>{
      'PUBLISHED': 'منتشر شده',
      'ASSIGNED': 'تخصیص داده شده',
      'IN_PROGRESS': 'در حال انجام',
      'DELIVERED': 'تحویل شده',
      'UNDER_REVIEW': 'در حال بررسی',
      'COMPLETED': 'تکمیل شده',
      'RELEASED': 'تسویه شده',
      'SETTLED': 'تسویه شده',
    };
    return labels[rawStatus.toUpperCase()] ??
        _t('نیازمند بررسی', 'Needs review');
  }

  bool _isWorkCenterActive(String status) => const {
        'ASSIGNED',
        'IN_PROGRESS',
        'DELIVERED',
        'UNDER_REVIEW',
        'COMPLETED',
      }.contains(status.toUpperCase());

  bool _isWorkCenterSettled(String status) => const {
        'RELEASED',
        'SETTLED',
      }.contains(status.toUpperCase());

  int _countWorkCenterActive(List<HopeJob> items) =>
      items.where((job) => _isWorkCenterActive(job.status ?? '')).length;

  int _countWorkCenterSettled(List<HopeJob> items) =>
      items.where((job) => _isWorkCenterSettled(job.status ?? '')).length;

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  List<PremiumLifecycleStep> _stepsForStatus(String rawStatus) {
    final status = rawStatus.toUpperCase();
    const order = <String>['PUBLISHED', 'ASSIGNED', 'IN_PROGRESS', 'DELIVERED', 'COMPLETED'];
    var index = order.indexOf(status);
    if (index < 0 && {'RELEASED', 'SETTLED'}.contains(status)) index = order.length - 1;
    if (index < 0) index = 0;
    final labels = <String>[
      _t('منتشر شده', 'Published'),
      _t('تخصیص داده شده', 'Assigned'),
      _t('در حال انجام', 'In progress'),
      _t('تحویل شده', 'Delivered'),
      _t('تکمیل شده', 'Completed'),
    ];
    const icons = <Object>[Icons.campaign_rounded, Icons.assignment_ind_rounded, Icons.play_circle_rounded, Icons.file_upload_rounded, HopeV2Icons.completed];
    return List.generate(order.length, (i) => PremiumLifecycleStep(
      label: labels[i],
      icon: icons[i],
      active: i == index,
      complete: i < index,
    ));
  }

  Widget _activityNavigation(BuildContext context) {
    final copy = HopeCopy.of(context);
    return PremiumQuickActionStrip(
      domain: HopeProductDomain.work,
      glass: false,
      quiet: true,
      title: _t('دسترسی سریع', 'Quick access'),
      subtitle: _t(
        'درخواست‌ها، پیشنهادها و اعلان‌ها را بدون باز کردن منوی کناری در دسترس داشته باشید.',
        'Reach applications, offers, and notifications without opening the side menu.',
      ),
      actions: [
        PremiumQuickAction(
          label: copy.copy_applications_6655869,
          icon: HopeV2Icons.mission,
          onPressed: () => Navigator.push(
            context,
            HopeRoutes.myApplications(),
          ),
          primary: true,
        ),
        PremiumQuickAction(
          label: copy.copy_offers,
          icon: HopeV2Icons.featured,
          onPressed: () => Navigator.push(
            context,
            HopeRoutes.offers(),
          ),
        ),
        PremiumQuickAction(
          label: copy.copy_notifications_370b4a1,
          icon: HopeV2Icons.notifications,
          onPressed: () => Navigator.push(
            context,
            HopeRoutes.notifications(),
          ),
        ),
      ],
    );
  }

  Widget _workCenterMetric({
    required String label,
    required String value,
    required Object icon,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
          children: [
            HopeIcon(icon, size: 18, color: accent, strokeWidth: 1.9),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: HopeV2Colors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _workItemCard(HopeJob job) {
    final status = job.status ?? '—';
    final settled = _isWorkCenterSettled(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumPanel(
        quiet: true,
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact ? 14 : 17,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HopeIconTile(
                  settled ? HopeV2Icons.completed : HopeV2Icons.pending,
                  color: settled ? HopeV2Colors.success : HopeV2Colors.primary,
                  filled: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          PremiumTag(
                            icon: HopeV2Icons.activity,
                            label: _jobStatusLabel(context, status),
                            color: settled
                                ? HopeV2Colors.success
                                : HopeV2Colors.primary,
                          ),
                          if (job.city?.isNotEmpty == true)
                            PremiumTag(
                              icon: HopeV2Icons.location,
                              label: job.city!,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PremiumLifecycle(
              compact: true,
              steps: _stepsForStatus(status),
              title: _t('مسیر همکاری', 'Work flow'),
              subtitle: _t(
                'وضعیت فعلی همکاری را در یک نگاه دنبال کنید.',
                'Follow the current collaboration state at a glance.',
              ),
            ),
            FutureBuilder<HopePayment?>(
              future: _tryGetPayment(job.id),
              builder: (context, paymentSnap) {
                if (paymentSnap.connectionState != ConnectionState.done ||
                    paymentSnap.data == null) {
                  return const SizedBox.shrink();
                }
                final payment = paymentSnap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    PremiumPaymentSummary(payment: payment),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        HopeRoutes.transaction(
                          repository: context.read<TransactionRepository>(),
                          uploadQueue: context.read<UploadQueue>(),
                          jobId: job.id,
                        ),
                      ),
                      icon: const HopeIcon(
                        HopeV2Icons.arrowRight,
                        size: 19,
                      ),
                      label: Text(
                        HopeCopy.of(context).copy_view_transaction_a91f1e6,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!widget.showPrimaryNavigation) return content;
    return PremiumPrimaryNavigationScaffold(
      selectedIndex: 2,
      onDestinationSelected: (index) => _navigatePrimary(context, index),
      child: content,
    );
  }

  void _navigatePrimary(BuildContext context, int index) {
    if (index == 2) return;
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        HopeRoutes.home(),
        (_) => false,
      );
      return;
    }
    final route = switch (index) {
      1 => HopeRoutes.jobs(),
      2 => HopeRoutes.transactions(),
      3 => HopeRoutes.walletFromContext(context),
      4 => HopeRoutes.profile(),
      _ => null,
    };
    if (route != null) {
      Navigator.of(context).pushReplacement(route);
    }
  }

  Widget _buildContent(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isGuest) {
      return PremiumPageFrame(
                page: HopePageId.workCenter,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        child: ListView(
          children: [
            PremiumHeader(
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
              eyebrow: _t('مرکز کار', 'WORK CENTER'),
              title: _t('مرکز کار خصوصی شما', 'Your private work center'),
              subtitle: HopeCopy.of(context)
                  .copy_sign_in_to_view_your_projects_and_payments_32a2bc2,
              trailing: const HopeIconTile(
                HopeV2Icons.secure,
                size: 42,
                filled: true,
              ),
            ),
            const SizedBox(height: 20),
            PremiumPanel(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.push(context, HopeRoutes.login()),
                icon: const HopeIcon(HopeV2Icons.login, size: 19),
                label: Text(HopeCopy.of(context).copy_log_in_b4c960b),
              ),
            ),
          ],
        ),
      );
    }
    if (future == null) {
      return const PremiumPageFrame(
                page: HopePageId.workCenter,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return FutureBuilder<List<HopeJob>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return RefreshIndicator(
              onRefresh: reload,
              child: PremiumPageFrame(
                page: HopePageId.workCenter,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                child: ListView(
                  children: [
                    PremiumHeader(
              dense: true,
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
                      eyebrow: _t('مرکز کار', 'WORK CENTER'),
                      title: _t('مرکز کار بارگذاری نشد', 'Work center could not be loaded'),
                      subtitle: HopeCopy.of(context)
                          .copy_pull_down_to_try_again_c41d215,
                      trailing: const HopeIconTile(
                        HopeV2Icons.pending,
                        size: 42,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PremiumPanel(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: reload,
                        icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                        label: Text(HopeCopy.of(context).copy_retry_49f3eba),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snap.data ?? const <HopeJob>[];
          final activeItems =
              items.where((job) => _isWorkCenterActive(job.status ?? '')).toList();
          final settledItems =
              items.where((job) => _isWorkCenterSettled(job.status ?? '')).toList();
          final otherItems = items
              .where((job) =>
                  !_isWorkCenterActive(job.status ?? '') &&
                  !_isWorkCenterSettled(job.status ?? ''))
              .toList();
          final activeCount = _countWorkCenterActive(items);
          final settledCount = _countWorkCenterSettled(items);
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: reload,
              child: PremiumPageFrame(
                page: HopePageId.workCenter,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                child: ListView(
                  children: [
                    PremiumHeader(
              dense: true,
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
                      eyebrow: _t('مرکز کار', 'WORK CENTER'),
                      title: _t('هنوز کاری ثبت نشده است', 'No work activity yet'),
                      subtitle: HopeCopy.of(context)
                          .copy_your_projects_applications_and_payments_wi_bec5340,
                      trailing: const HopeIconTile(
                        HopeV2Icons.insights,
                        size: 42,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _activityNavigation(context),
                    PremiumPanel(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          HopeRoutes.jobs(),
                        ),
                        icon: const HopeIcon(HopeV2Icons.workshop, size: 19),
                        label: Text(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? 'Explore opportunities'
                              : 'مشاهده فرصت‌ها',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
              onRefresh: reload,
              child: PremiumPageFrame(
                page: HopePageId.workCenter,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 76),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    PremiumHeader(
              dense: true,
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
                      eyebrow: _t('مرکز کار', 'WORK CENTER'),
                      title: _t('مرکز مالی و همکاری‌ها', 'Work & finance center'),
                      subtitle: _t(
                        'همکاری‌های فعال، وضعیت اجرا و تسویه مالی را در یک نگاه دنبال کنید.',
                        'Track active work, execution state, and financial settlement in one view.',
                      ),                    ),
                    const SizedBox(height: 6),
                    if (_reloadError != null) ...[
                      HopeAsyncState(
                        kind: HopeStateKind.error,
                        title: _reloadError!,
                        message: HopeCopy.of(context).copy_pull_down_to_try_again_c41d215,
                        action: FilledButton.icon(
                          onPressed: reload,
                          icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                          label: Text(HopeCopy.of(context).copy_retry_49f3eba),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final metricWidth = (constraints.maxWidth - 16) / 3;
                        final metrics = [
                          _workCenterMetric(
                            label: _t('همکاری‌ها', 'Collaborations'),
                            value: '${items.length}',
                            icon: HopeV2Icons.job,
                            accent: Theme.of(context).colorScheme.primary,
                          ),
                          _workCenterMetric(
                            label: _t('در حال اجرا', 'Active work'),
                            value: '$activeCount',
                            icon: HopeV2Icons.mission,
                            accent: secondaryAccent(context),
                          ),
                          _workCenterMetric(
                            label: _t('تسویه‌شده', 'Settled'),
                            value: '$settledCount',
                            icon: HopeV2Icons.completed,
                            accent: HopeV2Colors.success,
                          ),
                        ];

                        return Row(
                          key: const ValueKey('work-center-metrics'),
                          children: [
                            for (var index = 0; index < metrics.length; index++) ...[
                              SizedBox(width: metricWidth, child: metrics[index]),
                              if (index != metrics.length - 1)
                                const SizedBox(width: 8),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    PremiumPanel(
                      key: const ValueKey('work-center-focus-strip'),
                      glass: false,
                      quiet: true,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          HopeIconTile(
                            activeItems.isNotEmpty
                                ? HopeV2Icons.activity
                                : HopeV2Icons.completed,
                            size: 38,
                            filled: true,
                            color: activeItems.isNotEmpty
                                ? Theme.of(context).colorScheme.primary
                                : HopeV2Colors.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeItems.isNotEmpty
                                      ? _t('تمرکز فعلی', 'Current focus')
                                      : _t('وضعیت مالی', 'Financial status'),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: HopeV2Colors.muted,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activeItems.isNotEmpty
                                      ? _t(
                                          '$activeCount همکاری در جریان است',
                                          '$activeCount active collaborations',
                                        )
                                      : _t(
                                          '$settledCount همکاری تسویه شده است',
                                          '$settledCount collaborations settled',
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (settledItems.isNotEmpty)
                            PremiumTag(
                              icon: HopeV2Icons.completed,
                              label: '$settledCount ${_t('تسویه', 'settled')}',
                              color: HopeV2Colors.success,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (activeItems.isNotEmpty || settledItems.isNotEmpty) ...[
                      PremiumSectionHeader(
                        page: HopePageId.workCenter,
                        domain: HopeProductDomain.work,
                        title: _t('جریان همکاری‌ها', 'Work stream'),
                        subtitle: _t(
                          'وضعیت جاری را جدا از همکاری‌های تسویه‌شده دنبال کنید.',
                          'Track current work separately from financially settled collaborations.',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (activeItems.isNotEmpty) ...[
                      PremiumSectionHeader(
                        page: HopePageId.workCenter,
                        domain: HopeProductDomain.work,
                        title: _t('در حال اجرا', 'Active work'),
                        subtitle: _t(
                          'همکاری‌هایی که هنوز در چرخهٔ اجرا یا بررسی هستند.',
                          'Collaborations still in execution or review.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...activeItems.map(_workItemCard),
                    ],
                    if (otherItems.isNotEmpty) ...[
                      if (activeItems.isNotEmpty)
                        const SizedBox(height: 8),
                      PremiumSectionHeader(
                        page: HopePageId.workCenter,
                        domain: HopeProductDomain.work,
                        title: _t('سایر وضعیت‌ها', 'Other work'),
                        subtitle: _t(
                          'وضعیت‌هایی که هنوز در مسیر نهایی مالی نیستند.',
                          'Other collaboration states before final settlement.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...otherItems.map(_workItemCard),
                    ],
                    if (settledItems.isNotEmpty) ...[
                      if (activeItems.isNotEmpty || otherItems.isNotEmpty)
                        const SizedBox(height: 8),
                      PremiumSectionHeader(
                        page: HopePageId.workCenter,
                        domain: HopeProductDomain.finance,
                        title: _t('تسویه‌شده', 'Settled'),
                        subtitle: _t(
                          'همکاری‌هایی که چرخهٔ مالی آن‌ها پایان یافته است.',
                          'Collaborations whose financial lifecycle is complete.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...settledItems.map(_workItemCard),
                    ],
                    const SizedBox(height: 12),
                    _activityNavigation(context),
                  ],
                ),
              ));
        });
  }
}
