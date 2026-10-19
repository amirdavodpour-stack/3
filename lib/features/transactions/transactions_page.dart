import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/hope_display_formatters.dart';
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
    const icons = <Object>[HopeV2Icons.campaign, HopeV2Icons.assign, HopeV2Icons.play, HopeV2Icons.upload, HopeV2Icons.completed];
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
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: HopeV2Colors.muted,
          fontWeight: FontWeight.w800,
        );
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
        );
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: enlargedText
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HopeIcon(icon, size: 18, color: accent, strokeWidth: 1.9),
                const SizedBox(height: 4),
                Text(
                  label,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: labelStyle,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: valueStyle,
                ),
              ],
            )
          : Row(
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
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle,
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
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final settled = _isWorkCenterSettled(status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusAccent = settled
        ? (dark ? HopeV2Colors.successDark : HopeV2Colors.success)
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumPanel(
        quiet: true,
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact ? 12 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HopeIconTile(
                  settled ? HopeV2Icons.completed : HopeV2Icons.pending,
                  color: statusAccent,
                  size: 36,
                  filled: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: enlargedText ? null : 2,
                        softWrap: true,
                        overflow: enlargedText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          PremiumTag(
                            icon: HopeV2Icons.activity,
                            label: _jobStatusLabel(context, status),
                            color: statusAccent,
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
            const SizedBox(height: 6),
            PremiumLifecycle(
              key: ValueKey('work-center-lifecycle-${job.id}'),
              compact: MediaQuery.textScalerOf(context).scale(1) <= 1.2,
              steps: _stepsForStatus(status),
              title: _t('مسیر همکاری', 'Work flow'),
              subtitle: enlargedText
                  ? _t(
                      'وضعیت فعلی همکاری را در یک نگاه دنبال کنید.',
                      'Follow the current collaboration state at a glance.',
                    )
                  : null,
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
                    const SizedBox(height: 8),
                    PremiumPaymentSummary(payment: payment),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('transaction-status-semantic-target'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.standard,
                      ),
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

  Widget _workCenterLoadingSkeleton(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < HopeV2Breakpoints.compact;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    const gap = 8.0;
    final columns = enlargedText ? 2 : 3;

    Widget metricSkeleton(double cellWidth, int index) => Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: HopeV2Surfaces.panelSoft(context),
            borderRadius: BorderRadius.circular(HopeV2Radii.sm),
            border: Border.all(
              color: HopeV2Surfaces.border(context).withValues(alpha: .24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SkeletonBox(
                height: 10,
                width: cellWidth * (index == 0 ? .48 : .58),
                radius: HopeV2Radii.sm,
              ),
              const SizedBox(height: 6),
              SkeletonBox(
                height: 16,
                width: cellWidth * (index == 1 ? .28 : .38),
                radius: HopeV2Radii.sm,
              ),
            ],
          ),
        );

    Widget workItemSkeleton(int index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PremiumPanel(
            key: ValueKey('work-center-loading-job-$index'),
            quiet: true,
            padding: EdgeInsets.all(compact ? 12 : 14),
            child: Row(
              children: [
                SkeletonBox(
                  width: compact ? 34 : 36,
                  height: compact ? 34 : 36,
                  radius: HopeV2Radii.md,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        height: 12,
                        width: compact ? 124 : 174,
                        radius: HopeV2Radii.sm,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SkeletonBox(
                            height: 18,
                            width: compact ? 58 : 68,
                            radius: HopeV2Radii.sm,
                          ),
                          const SizedBox(width: 6),
                          SkeletonBox(
                            height: 18,
                            width: compact ? 62 : 78,
                            radius: HopeV2Radii.sm,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Semantics(
      key: const ValueKey('work-center-loading-skeleton'),
      container: true,
      liveRegion: true,
      label: _t('در حال بارگذاری کارگاه و امور مالی', 'Loading workshop and finance'),
      child: ExcludeSemantics(
        child: PremiumPageFrame(
          page: HopePageId.workCenter,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
          child: ListView(
            padding: HopeV2Navigation.scrollEndPadding(context),
            children: [
              PremiumHeader(
                page: HopePageId.workCenter,
                domain: HopeProductDomain.work,
                eyebrow: _t('مرکز کار', 'WORK CENTER'),
                title: _t('کارگاه و امور مالی', 'Workshop and finance'),
                subtitle: _t(
                  'کارهای فعال و تسویه مالی را پیگیری کنید.',
                  'Track active work and settlement.',
                ),
                trailing: const HopeIconTile(
                  HopeV2Icons.workshop,
                  size: 42,
                  filled: true,
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final metricWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    key: const ValueKey('work-center-loading-metrics'),
                    spacing: gap,
                    runSpacing: 8,
                    children: [
                      for (var index = 0; index < 3; index++)
                        SizedBox(
                          width: metricWidth,
                          child: metricSkeleton(metricWidth, index),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              PremiumPanel(
                key: const ValueKey('work-center-loading-focus-strip'),
                glass: false,
                quiet: true,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    SkeletonBox(
                      width: compact ? 36 : 38,
                      height: compact ? 36 : 38,
                      radius: HopeV2Radii.md,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(height: 10, width: 94),
                          const SizedBox(height: 6),
                          SkeletonBox(
                            height: 12,
                            width: compact ? 154 : 220,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PremiumSectionHeader(
                page: HopePageId.workCenter,
                domain: HopeProductDomain.work,
                title: _t('جریان همکاری‌ها', 'Work stream'),
                subtitle: _t(
                  'وضعیت جاری همکاری‌ها',
                  'Current collaboration status',
                ),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < 2; index++) workItemSkeleton(index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isGuest) {
      return PremiumPageFrame(
                page: HopePageId.workCenter,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        child: ListView(
          padding: HopeV2Navigation.scrollEndPadding(context),
          children: [
            PremiumHeader(
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
              eyebrow: _t('کارگاه', 'WORKSHOP'),
              title: _t('کارگاه شخصی شما', 'Your workspace'),
              subtitle: _t('برای مشاهده پروژه‌ها و پرداخت‌ها وارد شوید.', 'Sign in to view projects and payments.'),
              trailing: const HopeIconTile(
                HopeV2Icons.secure,
                size: 42,
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            PremiumPanel(
              padding: const EdgeInsets.all(12),
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
      return _workCenterLoadingSkeleton(context);
    }
    return FutureBuilder<List<HopeJob>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _workCenterLoadingSkeleton(context);
          }
          if (snap.hasError) {
            return RefreshIndicator(
              onRefresh: reload,
              child: PremiumPageFrame(
                page: HopePageId.workCenter,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                child: ListView(
                  padding: HopeV2Navigation.scrollEndPadding(context),
                  children: [
                    PremiumHeader(
              dense: true,
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
                      eyebrow: _t('مرکز کار', 'WORK CENTER'),
                      title: _t('بارگذاری کارگاه ناموفق بود', 'Could not load workshop'),
                      
                      trailing: const HopeIconTile(
                        HopeV2Icons.pending,
                        size: 42,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PremiumPanel(
                      padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                child: ListView(
                  padding: HopeV2Navigation.scrollEndPadding(context),
                  children: [
                    PremiumHeader(
              dense: true,
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
                      eyebrow: _t('مرکز کار', 'WORK CENTER'),
                      title: _t('هنوز فعالیتی ثبت نشده است', 'No work activity yet'),
                      subtitle: _t('درخواست‌ها و پیشنهادهای شما اینجا نمایش داده می‌شوند.', 'Your applications and offers appear here.'),
                      trailing: const HopeIconTile(
                        HopeV2Icons.insights,
                        size: 42,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _activityNavigation(context),
                    PremiumPanel(
                      padding: const EdgeInsets.all(12),
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
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                child: ListView(
                  padding: HopeV2Navigation.scrollEndPadding(context),
                  children: [
                    PremiumHeader(
              dense: true,
              page: HopePageId.workCenter,
              domain: HopeProductDomain.work,
                      eyebrow: _t('مرکز کار', 'WORK CENTER'),
                      title: _t('کارگاه و امور مالی', 'Workshop and finance'),
                      subtitle: _t(
                        'کارهای فعال و تسویه مالی را پیگیری کنید.',
                        'Track active work and settlement.',
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
                        final enlargedText =
                            MediaQuery.textScalerOf(context).scale(1) > 1.2;
                        const gap = 8.0;
                        final columns = enlargedText ? 2 : 3;
                        final metricWidth =
                            (constraints.maxWidth - gap * (columns - 1)) /
                                columns;
                        final metrics = [
                          _workCenterMetric(
                            label: _t('همکاری‌ها', 'Collaborations'),
                            value: HopeDisplayFormatter.integer(items.length, locale: Localizations.localeOf(context).languageCode),
                            icon: HopeV2Icons.job,
                            accent: Theme.of(context).colorScheme.primary,
                          ),
                          _workCenterMetric(
                            label: _t('در حال اجرا', 'Active work'),
                            value: HopeDisplayFormatter.integer(activeCount, locale: Localizations.localeOf(context).languageCode),
                            icon: HopeV2Icons.mission,
                            accent: secondaryAccent(context),
                          ),
                          _workCenterMetric(
                            label: _t('تسویه‌شده', 'Settled'),
                            value: HopeDisplayFormatter.integer(settledCount, locale: Localizations.localeOf(context).languageCode),
                            icon: HopeV2Icons.completed,
                            accent: HopeV2Colors.success,
                          ),
                        ];

                        return Wrap(
                          key: const ValueKey('work-center-metrics'),
                          spacing: gap,
                          runSpacing: 8,
                          children: [
                            for (final metric in metrics)
                              SizedBox(width: metricWidth, child: metric),
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
                                          '${HopeDisplayFormatter.integer(activeCount, locale: Localizations.localeOf(context).languageCode)} همکاری در جریان است',
                                          '${HopeDisplayFormatter.integer(activeCount, locale: Localizations.localeOf(context).languageCode)} active collaborations',
                                        )
                                      : _t(
                                          '${HopeDisplayFormatter.integer(settledCount, locale: Localizations.localeOf(context).languageCode)} همکاری تسویه شده است',
                                          '${HopeDisplayFormatter.integer(settledCount, locale: Localizations.localeOf(context).languageCode)} collaborations settled',
                                        ),
                                  maxLines: 2,
                                  softWrap: true,
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
                              label: '${HopeDisplayFormatter.integer(settledCount, locale: Localizations.localeOf(context).languageCode)} ${_t('تسویه', 'settled')}',
                              color: HopeV2Colors.success,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _activityNavigation(context),
                    const SizedBox(height: 10),
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
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      ...settledItems.map(_workItemCard),
                    ],
                    const SizedBox(height: 8),
                    _activityNavigation(context),
                  ],
                ),
              ));
        });
  }
}
