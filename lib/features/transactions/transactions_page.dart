import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import 'package:provider/provider.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/transactions/payment.dart';
import '../../core/marketplace/job.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/ui/components.dart';
import '../../core/theme/app_theme.dart';
import '../../core/uploads/upload_queue.dart';
import '../../core/router/app_routes.dart';
import '../../core/application/application_registry.dart';

import '../../core/ui/premium_components.dart';
import '../../core/ui/premium_lifecycle.dart';
import '../../core/ui/premium_payment_summary.dart';
import '../../core/ui/hope_async_state.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, this.repository});
  final TransactionRepository? repository;
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
    const icons = <IconData>[Icons.campaign_outlined, Icons.assignment_ind_outlined, Icons.play_circle_outline_rounded, Icons.upload_file_outlined, Icons.check_circle_outline_rounded];
    return List.generate(order.length, (i) => PremiumLifecycleStep(
      label: labels[i],
      icon: icons[i],
      active: i == index,
      complete: i < index,
    ));
  }

  Widget _activityNavigation(BuildContext context) {
    final copy = HopeCopy.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PremiumPanel(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                HopeRoutes.myApplications(),
              ),
              icon: const Icon(Icons.assignment_outlined),
              label: Text(copy.copy_applications_6655869),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                HopeRoutes.offers(),
              ),
              icon: const Icon(Icons.local_offer_outlined),
              label: Text(copy.copy_offers),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                HopeRoutes.notifications(),
              ),
              icon: const Icon(Icons.notifications_outlined),
              label: Text(copy.copy_notifications_370b4a1),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isGuest) {
      return PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        child: ListView(
          children: [
            PremiumHeader(
              eyebrow: HopeCopy.of(context).copy_activity_4b38716,
              title: HopeCopy.of(context).copy_your_activity_is_private_1363766,
              subtitle: HopeCopy.of(context)
                  .copy_sign_in_to_view_your_projects_and_payments_32a2bc2,
              trailing: const HopeIconTile(
                Icons.lock_outline_rounded,
                size: 50,
                filled: true,
              ),
            ),
            const SizedBox(height: 20),
            PremiumPanel(
              padding: const EdgeInsets.all(20),
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.push(context, HopeRoutes.login()),
                icon: const Icon(Icons.login_rounded),
                label: Text(HopeCopy.of(context).copy_log_in_b4c960b),
              ),
            ),
          ],
        ),
      );
    }
    if (future == null) {
      return const PremiumPageFrame(
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                child: ListView(
                  children: [
                    PremiumHeader(
                      eyebrow: HopeCopy.of(context).copy_activity_4b38716,
                      title: HopeCopy.of(context).copy_could_not_load_activity_335b923,
                      subtitle: HopeCopy.of(context)
                          .copy_pull_down_to_try_again_c41d215,
                      trailing: const HopeIconTile(
                        Icons.cloud_off_rounded,
                        size: 50,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PremiumPanel(
                      padding: const EdgeInsets.all(20),
                      child: FilledButton.icon(
                        onPressed: reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(HopeCopy.of(context).copy_retry_49f3eba),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snap.data ?? const <HopeJob>[];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: reload,
              child: PremiumPageFrame(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                child: ListView(
                  children: [
                    PremiumHeader(
                      eyebrow: HopeCopy.of(context).copy_activity_4b38716,
                      title: HopeCopy.of(context).copy_no_activity_yet_264ceb0,
                      subtitle: HopeCopy.of(context)
                          .copy_your_projects_applications_and_payments_wi_bec5340,
                      trailing: const HopeIconTile(
                        Icons.auto_graph_rounded,
                        size: 50,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _activityNavigation(context),
                    PremiumPanel(
                      padding: const EdgeInsets.all(20),
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          HopeRoutes.jobs(),
                        ),
                        icon: const Icon(Icons.explore_rounded),
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    PremiumHeader(
                      eyebrow: HopeCopy.of(context).copy_activity_4b38716,
                      title: HopeCopy.of(context).copy_latest_activity_a05277b,
                      subtitle: HopeCopy.of(context)
                          .copy_projects_progress_and_payments_at_a_glance_a0178c8,
                      trailing: const HopeIconTile(
                        Icons.swap_horizontal_circle_rounded,
                        size: 50,
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _activityNavigation(context),
                    if (_reloadError != null) ...[
                      HopeAsyncState(
                        kind: HopeStateKind.error,
                        title: _reloadError!,
                        message: HopeCopy.of(context).copy_pull_down_to_try_again_c41d215,
                        action: FilledButton.icon(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(HopeCopy.of(context).copy_retry_49f3eba),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final metrics = [
                          PremiumStatCard(
                            label: HopeCopy.of(context).copy_total_projects_78ce548,
                            value: '${items.length}',
                            icon: Icons.work_history_rounded,
                            caption: HopeCopy.of(context).copy_latest_activity_a05277b,
                          ),
                          PremiumStatCard(
                            label: HopeCopy.of(context).copy_status_b81f9c7,
                            value: HopeCopy.of(context).copy_active_5726b26,
                            icon: Icons.bolt_rounded,
                            accent: secondaryAccent(context),
                            caption: HopeCopy.of(context).copy_work_status_eb2d6f2,
                          ),
                        ];

                        if (constraints.maxWidth < 500) {
                          return Column(
                            children: [
                              metrics[0],
                              const SizedBox(height: 10),
                              metrics[1],
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: metrics[0]),
                            const SizedBox(width: 10),
                            Expanded(child: metrics[1]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    SectionTitle(
                        title:
                            HopeCopy.of(context).copy_latest_activity_a05277b,
                        subtitle: HopeCopy.of(context)
                            .copy_the_most_recent_project_updates_5e402d8),
                    const SizedBox(height: 12),
                    ...items.map((job) {
                      final status = job.status ?? '—';
                      final released = status == 'RELEASED' ||
                          status == 'COMPLETED' ||
                          status == 'SETTLED';
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PremiumPanel(
                            padding: const EdgeInsets.all(17),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    HopeIconTile(
                                      released
                                          ? Icons.check_rounded
                                          : Icons.hourglass_top_rounded,
                                      color: released
                                          ? AppColors.success
                                          : AppColors.primary,
                                      filled: true,
                                    ),
                                    const SizedBox(width: 12),
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
                                          Text(
                                            '${HopeCopy.of(context).copy_work_status_eb2d6f2}: ${_jobStatusLabel(context, job.status ?? '—')}',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    StatusPill(
                                      released
                                          ? HopeCopy.of(context).copy_completed_4ab501b
                                          : HopeCopy.of(context).copy_in_progress_ed61091,
                                      color: released ? AppColors.success : AppColors.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                PremiumLifecycle(
                                  steps: _stepsForStatus(status),
                                  title: Localizations.localeOf(context).languageCode == 'en' ? 'Project flow' : 'مسیر پروژه',
                                  subtitle: Localizations.localeOf(context).languageCode == 'en' ? 'Follow the latest project state at a glance.' : 'وضعیت کار را در یک نگاه دنبال کنید.',
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
                                          icon: const Icon(Icons.open_in_new_rounded),
                                          label: Text(HopeCopy.of(context).copy_view_transaction_a91f1e6),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                    }),
                  ],
                ),
              ));
        });
  }
}
