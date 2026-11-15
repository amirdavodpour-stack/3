import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin/admin_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/hope_v2_design.dart';

/// Operational surface for backend capabilities that are intentionally
/// separate from the general admin CRUD screen.
class AdminOperationsPage extends StatefulWidget {
  const AdminOperationsPage({super.key});

  @override
  State<AdminOperationsPage> createState() => _AdminOperationsPageState();
}

class _AdminOperationsPageState extends State<AdminOperationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _days = 30;
  // Wave 1: admin control data starts from safe empty futures before access resolves.
  late Future<Map<String, dynamic>> _finance;
  late Future<List<Map<String, dynamic>>> _reports;
  late Future<List<Map<String, dynamic>>> _unknownPayouts;
  late Future<Map<String, dynamic>> _outboxEventReconciliationCases;
  final List<Map<String, dynamic>> _additionalOutboxEventCases = [];
  final Set<String> _outboxEventCaseIds = <String>{};
  String? _outboxEventNextCursor;
  bool _outboxEventHasMore = false;
  bool _outboxEventLoadMoreBusy = false;
  int _outboxEventRequestGeneration = 0;
  final Map<String,String> _outboxEventCaseStatusOverrides = <String,String>{};
  late Future<Map<String, dynamic>> _analytics;
  late Future<Map<String, dynamic>> _funnel;
  late Future<Map<String, dynamic>> _crashes;
  bool _operationBusy = false;
  bool _initialLoadPending = true;
  Set<String> _permissions = <String>{};
  bool _hasPermission(String permission) => _permissions.contains(permission);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _finance = Future.value(const <String, dynamic>{});
    _reports = Future.value(const <Map<String, dynamic>>[]);
    _unknownPayouts = Future.value(const <Map<String, dynamic>>[]);
    _outboxEventReconciliationCases = Future.value(const {
      'cases': <Map<String, dynamic>>[],
      'hasMore': false,
      'nextCursor': null,
    });
    _analytics = Future.value(const <String, dynamic>{});
    _funnel = Future.value(const <String, dynamic>{});
    _crashes = Future.value(const <String, dynamic>{});
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final r = context.read<AdminRepository>();
    final outboxEventGeneration = ++_outboxEventRequestGeneration;
    try {
      final access = await r.getPanelAccess();
      if (!mounted ||
          outboxEventGeneration != _outboxEventRequestGeneration) {
        return;
      }
      _permissions = access['permissions'] is List
          ? (access['permissions'] as List).whereType<String>().toSet()
          : <String>{};
    } catch (_) {
      if (!mounted ||
          outboxEventGeneration != _outboxEventRequestGeneration) {
        return;
      }
      _permissions = <String>{};
    }

    _finance = r.getFinanceSummary();
    _reports = r.listTrustReports();
    _unknownPayouts = _hasPermission('admin.view_payouts')
        ? r.listUnknownPayouts()
        : Future.value(const <Map<String, dynamic>>[]);

    _additionalOutboxEventCases.clear();
    _outboxEventCaseIds.clear();
    _outboxEventCaseStatusOverrides.clear();
    _outboxEventNextCursor = null;
    _outboxEventHasMore = false;
    _outboxEventLoadMoreBusy = false;
    _outboxEventReconciliationCases = _hasPermission('admin.view_payouts')
        ? r.listActiveOutboxEventReconciliationCases().then((page) {
            if (mounted &&
                outboxEventGeneration == _outboxEventRequestGeneration) {
              setState(() {
                final rawCases = page['cases'];
                if (rawCases is List) {
                  _outboxEventCaseIds.addAll(
                    rawCases.whereType<Map>()
                        .map((item) => '${item['id'] ?? ''}')
                        .where((id) => id.isNotEmpty),
                  );
                }
                _outboxEventNextCursor = page['nextCursor']?.toString();
                _outboxEventHasMore = page['hasMore'] == true &&
                    _outboxEventNextCursor != null &&
                    _outboxEventNextCursor!.isNotEmpty;
              });
            }
            return page;
          })
        : Future.value(const {
            'cases': <Map<String, dynamic>>[],
            'hasMore': false,
            'nextCursor': null,
          });

    _analytics = r.getAnalyticsSummary(days: _days);
    _funnel = r.getFunnel(days: _days);
    _crashes = r.getCrashSummary(days: _days);
    if (mounted) setState(() => _initialLoadPending = false);
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _reportStatusLabel(Object? value) =>
      switch (value?.toString().trim().toUpperCase()) {
        'OPEN' => _t('باز', 'Open'),
        'REVIEWING' => _t('در حال بررسی', 'Reviewing'),
        'RESOLVED' => _t('حل‌شده', 'Resolved'),
        'DISMISSED' => _t('ردشده', 'Dismissed'),
        _ => _t('نیازمند بررسی', 'Needs review'),
      };

  String _reportEntityTypeLabel(Object? value) =>
      switch (value?.toString().trim().toUpperCase()) {
        'USER' => _t('کاربر', 'User'),
        'JOB' => _t('فرصت', 'Opportunity'),
        _ => _t('سایر', 'Other'),
      };

  String _payoutStatusLabel(Object? value) =>
      switch (value?.toString().trim().toUpperCase()) {
        'SUCCEEDED' => _t('موفق', 'Succeeded'),
        'FAILED' => _t('ناموفق', 'Failed'),
        'PENDING' => _t('در انتظار', 'Pending'),
        'UNKNOWN' => _t('نیازمند بررسی', 'Needs review'),
        _ => _t('نیازمند بررسی', 'Needs review'),
      };

  String _reportNextLabel(String value) => switch (value) {
        'REVIEWING' => _t('در حال بررسی', 'Reviewing'),
        'RESOLVED' => _t('حل‌شده', 'Resolved'),
        'DISMISSED' => _t('ردشده', 'Dismissed'),
        _ => _t('تغییر وضعیت', 'Change status'),
      };

  String _value(dynamic v) {
    if (v == null) return '—';
    if (v is num) return v.toString();
    if (v is List) return '${v.length}';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: Scaffold(
        body: PremiumPageFrame(
          maxWidth: 1280,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            children: [
              PremiumHeader(
                page: HopePageId.adminOperations,
                domain: HopeProductDomain.control,
                eyebrow: _t('کنترل عملیات', 'OPERATIONS CONTROL'),
                title: _t('مرکز عملیات HOPE', 'HOPE Operations Center'),
                subtitle: _t(
                  'مالی، اعتماد، تسویه‌های ناشناخته، تحلیل و خطاهای عملیاتی را از هم جدا بررسی کنید.',
                  'Review finance, trust, unknown payouts, analytics, and operational errors as separate workstreams.',
                ),
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 112,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _days,
                          isExpanded: true,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _days = v);
                            _reload();
                          },
                          items: const [7, 30, 90, 365]
                              .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                              .toList(),
                        ),
                      ),
                    ),
                    PremiumIconButton(
                      icon: HopeV2Icons.refresh,
                      tooltip: _t('بازخوانی', 'Refresh'),
                      onPressed: _reload,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: HopeV2Spacing.lg),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  Tab(text: _t('مالی', 'Finance')),
                  Tab(text: _t('امنیت و اعتماد', 'Trust & Safety')),
                  Tab(text: _t('تسویه‌های ناشناخته', 'Unknown payouts')),
                  Tab(text: _t('تحلیل', 'Analytics')),
                  Tab(text: _t('Crash', 'Crashes')),
                ],
              ),
              const SizedBox(height: HopeV2Spacing.md),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _financeTab(),
                    _reportsTab(),
                    _payoutsTab(),
                    _analyticsTab(),
                    _crashTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingOrError<T>(AsyncSnapshot<T> s, Widget Function(T data) child) {
    if (_initialLoadPending || s.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (s.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: HopeV2Icons.pending,
            title: _t('دریافت اطلاعات ناموفق بود', 'Could not load data'),
            message: apiErrorMessage(s.error ?? Object()),
            action: FilledButton(
              onPressed: _reload,
              child: Text(_t('تلاش دوباره', 'Retry')),
            ),
          ),
        ),
      );
    }
    return child(s.data as T);
  }

  Widget _financeTab() => FutureBuilder<Map<String, dynamic>>(
        future: _finance,
        builder: (_, s) => _loadingOrError(s, (data) {
          final entries = data.entries
              .where((e) => e.value is num || e.value is String)
              .toList(growable: false);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _header(
                  HopeV2Icons.wallet,
                  _t('نمای مالی پلتفرم', 'Platform financial overview'),
                  _t('اعداد مستقیماً از کنترل مالی Backend خوانده می‌شوند.',
                      'Values are read directly from the backend financial control.'),
                  domain: HopeProductDomain.finance,
                ),
                const SizedBox(height: 14),
                _metricGrid(entries),
              ],
            ),
          );
        }),
      );

  Widget _reportsTab() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _reports,
        builder: (_, s) => _loadingOrError(s, (rows) => RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _header(
                    HopeV2Icons.secure,
                    _t('Trust & Safety', 'Trust & Safety'),
                    _t('گزارش‌های واقعی کاربران و وضعیت رسیدگی.', 'Real user reports and their review state.'),
                    domain: HopeProductDomain.trust,
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    _empty(HopeV2Icons.secure, _t('گزارشی وجود ندارد', 'No reports'))
                  else
                    ...rows.map(_reportCard),
                ],
              ),
            )),
      );

  Widget _reportCard(Map<String, dynamic> row) {
    final id = '${row['id'] ?? ''}';
    final status = '${row['status'] ?? 'OPEN'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPanel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const HopeIconTile(HopeV2Icons.notifications, size: 36, filled: true),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${row['reason'] ?? _t('گزارش', 'Report')}',
              style: Theme.of(context).textTheme.titleMedium,
            )),
            StatusPill(_reportStatusLabel(status), icon: HopeV2Icons.pending, color: secondaryAccent(context)),
          ]),
          if ('${row['details'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${row['details']}'),
          ],
          const SizedBox(height: 8),
          Text('${_reportEntityTypeLabel(row['entityType'])} • ${row['entityId'] ?? '—'} • ${row['createdAt'] ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final next in const ['REVIEWING', 'RESOLVED', 'DISMISSED'])
              if (next != status)
                OutlinedButton(
                  onPressed: id.isEmpty || _operationBusy ? null : () => _setReportStatus(id, next),
                  child: Text(_reportNextLabel(next)),
                ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _setReportStatus(String id, String status) async {
    if (_operationBusy || !mounted) return;
    setState(() => _operationBusy = true);
    try {
      await context.read<AdminRepository>().updateTrustReportStatus(id, status);
      if (mounted) _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _operationBusy = false);
    }
  }

  Future<void> _loadMoreOutboxEventCases() async {
    final cursor = _outboxEventNextCursor;
    if (_outboxEventLoadMoreBusy ||
        !_outboxEventHasMore ||
        cursor == null ||
        cursor.isEmpty) {
      return;
    }
    final generation = _outboxEventRequestGeneration;
    setState(() => _outboxEventLoadMoreBusy = true);
    try {
      final page = await context
          .read<AdminRepository>()
          .listActiveOutboxEventReconciliationCases(cursor: cursor);
      if (!mounted || generation != _outboxEventRequestGeneration) return;
      final rawCases = page['cases'];
      final rows = rawCases is List
          ? rawCases
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where((item) {
                final id = '${item['id'] ?? ''}';
                return id.isNotEmpty && _outboxEventCaseIds.add(id);
              })
              .toList(growable: false)
          : const <Map<String, dynamic>>[];
      setState(() {
        _additionalOutboxEventCases.addAll(rows);
        final nextCursor = page['nextCursor']?.toString();
        _outboxEventNextCursor =
            nextCursor == null || nextCursor.isEmpty ? null : nextCursor;
        _outboxEventHasMore =
            page['hasMore'] == true && _outboxEventNextCursor != null;
      });
    } catch (error) {
      if (mounted && generation == _outboxEventRequestGeneration) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted && generation == _outboxEventRequestGeneration) {
        setState(() => _outboxEventLoadMoreBusy = false);
      }
    }
  }

  Widget _outboxEventCasesSection(Map<String, dynamic> page) {
    final rawCases = page['cases'];
    final initialRows = rawCases is List
        ? rawCases
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final rows = [...initialRows, ..._additionalOutboxEventCases];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          HopeV2Icons.secure,
          _t('پرونده‌های یکپارچگی رویداد Outbox', 'Outbox event integrity cases'),
          _t(
            'رویدادهای ناسازگار در قرنطینه باقی می‌مانند؛ این فهرست فقط برای مشاهده و پیگیری است و وضعیت مالی را تغییر نمی‌دهد.',
            'Quarantined event mismatches remain visible here. Inspection is read-only and never releases funds or changes payout state.',
          ),
          domain: HopeProductDomain.finance,
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          _empty(
            HopeV2Icons.completed,
            _t('پروندهٔ فعالی برای رویدادهای Outbox وجود ندارد', 'No active Outbox event integrity cases'),
          )
        else
          ...rows.map((item) {
            final caseId = '${item['id'] ?? ''}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _reconciliationCaseCard(item, showResourceLocator: true),
                if (caseId.isNotEmpty)
                  _OutboxEventInvestigationPanel(
                    key: ValueKey('outbox-investigation-$caseId'),
                    repository: context.read<AdminRepository>(),
                    caseId: caseId,
                    canWrite: _hasPermission('admin.manage_reconciliation_cases'),
                    translate: _t,
                    onCaseStatusChanged: (status) {
                      if (!mounted) return;
                      setState(() => _outboxEventCaseStatusOverrides[caseId] = status);
                    },
                  ),
              ],
            );
          }),
        if (_outboxEventHasMore) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _outboxEventLoadMoreBusy ? null : _loadMoreOutboxEventCases,
              icon: _outboxEventLoadMoreBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(
                _outboxEventLoadMoreBusy
                    ? _t('در حال دریافت...', 'Loading...')
                    : _t('نمایش پرونده‌های بیشتر', 'Load more cases'),
              ),
            ),
          ),
        ],
      ],
    );
  }
  Widget _payoutsTab() => RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          key: const ValueKey('admin-payouts-scroll'),
          padding: const EdgeInsets.all(18),
          children: [
            _header(
              HopeV2Icons.payments,
              _t('کنترل تسویه', 'Payout operations'),
              _t(
                'تسویه‌های ناشناخته و پرونده‌های یکپارچگی رویداد را در دو صف مستقل بررسی کنید.',
                'Review unknown payouts and event-integrity quarantines in separate queues.',
              ),
              domain: HopeProductDomain.finance,
            ),
            const SizedBox(height: 12),
            if (!_hasPermission('admin.view_payouts'))
              EmptyState(
                icon: HopeV2Icons.secure,
                title: _t('دسترسی محدود است', 'Access restricted'),
                message: _t(
                  'برای مشاهده پرونده‌های مالی، مجوز مشاهده تسویه لازم است.',
                  'The payout visibility permission is required to inspect financial cases.',
                ),
              )
            else ...[
              Text(
                _t('تسویه‌های ناشناخته', 'Unknown payouts'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _unknownPayouts,
                builder: (_, snapshot) => _loadingOrError(
                  snapshot,
                  (rows) => rows.isEmpty
                      ? _empty(
                          HopeV2Icons.completed,
                          _t('تسویه ناشناخته‌ای نیست', 'No unknown payouts'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rows.map(_payoutCard).toList(growable: false),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, dynamic>>(
                future: _outboxEventReconciliationCases,
                builder: (_, snapshot) => _loadingOrError(
                  snapshot,
                  _outboxEventCasesSection,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _payoutCard(Map<String, dynamic> row) {
    final id = '${row['id'] ?? row['payoutId'] ?? ''}';
    final rawCases = row['reconciliationCases'];
    final reconciliationCases = rawCases is List
        ? rawCases
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPanel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const HopeIconTile(HopeV2Icons.pending, size: 36, filled: true),
            const SizedBox(width: 8),
            Expanded(child: Text('${_t('تسویه', 'Payout')} ${id.isEmpty ? '—' : id}',
                style: Theme.of(context).textTheme.titleMedium)),
            StatusPill(_payoutStatusLabel(row['status']), color: AppColors.warning),
          ]),
          const SizedBox(height: 8),
          Text(
            row.entries
                .where(
                  (e) =>
                      !{'id', 'payoutId', 'status', 'currency', 'reconciliationCases'}.contains(e.key) &&
                      (e.value is String || e.value is num),
                )
                .take(6)
                .map((e) => '${e.key}: ${e.value}')
                .join(' • '),
          ),
          if (reconciliationCases.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _t('پرونده‌های تطبیق', 'Reconciliation cases'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...reconciliationCases.map(_reconciliationCaseCard),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: id.isEmpty || _operationBusy || !_hasPermission('admin.resolve_payouts') ? null : () => _resolvePayout(id, 'FAILED'),
              child: Text(_t('ثبت ناموفق', 'Mark failed')),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(
              onPressed: id.isEmpty || _operationBusy || !_hasPermission('admin.resolve_payouts') ? null : () => _resolvePayout(id, 'SUCCEEDED'),
              child: Text(_t('ثبت موفق', 'Mark succeeded')),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _reconciliationCaseCard(
    Map<String, dynamic> item, {
    bool showResourceLocator = false,
  }) {
    final caseId = '${item['id'] ?? ''}';
    final caseType = '${item['caseType'] ?? _t('پرونده تطبیق', 'Reconciliation case')}';
    final resourceType = '${item['resourceType'] ?? ''}';
    final resourceId = '${item['resourceId'] ?? ''}';
    final eventType = '${item['eventType'] ?? ''}';
    final eventStatus = '${item['eventStatus'] ?? ''}';
    final aggregateType = '${item['aggregateType'] ?? ''}';
    final aggregateId = '${item['aggregateId'] ?? ''}';
    final severity = '${item['severity'] ?? '—'}'.trim().toUpperCase();
    final status = (_outboxEventCaseStatusOverrides[caseId] ?? '${item['status'] ?? '—'}').trim().toUpperCase();
    final expected = item['expected'] is Map
        ? Map<String, dynamic>.from(item['expected'] as Map)
        : const <String, dynamic>{};
    final observed = item['observed'] is Map
        ? Map<String, dynamic>.from(item['observed'] as Map)
        : const <String, dynamic>{};
    final theme = Theme.of(context);
    final severityColor = switch (severity) {
      'CRITICAL' || 'HIGH' => theme.colorScheme.error,
      'MEDIUM' => theme.colorScheme.tertiary,
      _ => theme.colorScheme.outline,
    };

    String evidenceText(Map<String, dynamic> evidence) {
      if (evidence.isEmpty) return _t('اطلاعات ثبت نشده', 'No evidence recorded');
      return evidence.entries
          .take(5)
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(' • ');
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: Border.all(color: severityColor.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  caseType.replaceAll('_', ' '),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatusPill(
                _reconciliationSeverityLabel(severity),
                color: severityColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${_t('وضعیت پرونده', 'Case status')}: ${_reconciliationStatusLabel(status)}'),
          if (showResourceLocator) ...[
            const SizedBox(height: 6),
            Text(
              '${_t('منبع', 'Resource')}: ${resourceType == 'outbox_event' ? _t('رویداد Outbox', 'Outbox event') : resourceType}',
            ),
            Text(
              '${_t('شناسه رویداد Outbox', 'Outbox event ID')}:',
              style: theme.textTheme.bodySmall,
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                resourceId.isEmpty ? '—' : resourceId,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
            if (eventType.isNotEmpty)
              Text('${_t('نوع رویداد', 'Event type')}: $eventType'),
            if (eventStatus.isNotEmpty)
              Text('${_t('وضعیت رویداد', 'Event status')}: $eventStatus'),
            if (aggregateType.isNotEmpty || aggregateId.isNotEmpty)
              Text(
                '${_t('منبع تجمیع', 'Aggregate')}: ${aggregateType.isEmpty ? '—' : aggregateType} / ${aggregateId.isEmpty ? '—' : aggregateId}',
              ),
          ],
          const SizedBox(height: 4),
          Text('${_t('مورد انتظار', 'Expected')}: ${evidenceText(expected)}'),
          const SizedBox(height: 4),
          Text('${_t('مشاهده‌شده', 'Observed')}: ${evidenceText(observed)}'),
          if (caseId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${_t('شناسه پرونده', 'Case ID')}: $caseId',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String _reconciliationSeverityLabel(String value) => switch (value) {
        'CRITICAL' => _t('بحرانی', 'Critical'),
        'HIGH' => _t('زیاد', 'High'),
        'MEDIUM' => _t('متوسط', 'Medium'),
        'LOW' => _t('کم', 'Low'),
        _ => value.isEmpty ? '—' : value,
      };

  String _reconciliationStatusLabel(String value) => switch (value) {
        'OPEN' => _t('باز', 'Open'),
        'INVESTIGATING' => _t('در حال بررسی', 'Investigating'),
        'RESOLVED' => _t('حل‌شده', 'Resolved'),
        'DISMISSED' => _t('مختومه', 'Dismissed'),
        _ => value.isEmpty ? '—' : value,
      };

  Future<void> _resolvePayout(String id, String decision) async {
    if (_operationBusy || !mounted) return;
    setState(() => _operationBusy = true);
    final repository = context.read<AdminRepository>();
    String providerRef = '';
    String reason = '';
    try {
      if (decision == 'SUCCEEDED') {
      final ref = TextEditingController();
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('تأیید تسویه موفق', 'Confirm successful payout')),
          content: TextField(
            controller: ref,
            decoration: InputDecoration(labelText: _t('مرجع PSP', 'Provider reference')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('لغو', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, ref.text.trim().isNotEmpty), child: Text(_t('تأیید', 'Confirm'))),
          ],
        ),
      );
      providerRef = ref.text.trim();
      ref.dispose();
      if (result != true) return;
    }
      await repository.resolveUnknownPayout(
        id,
        decision: decision,
        providerRef: providerRef.isEmpty ? null : providerRef,
        reason: reason.isEmpty ? null : reason,
      );
      if (mounted) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _operationBusy = false);
    }
  }

  Widget _analyticsTab() => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _analytics,
            builder: (_, s) => _loadingOrError(s, (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(
                  HopeV2Icons.insights,
                  _t('تحلیل محصول', 'Product analytics'),
                  _t(
                    'خلاصه رویدادهای ثبت‌شده در بازه انتخابی.',
                    'Recorded product analytics for the selected period.',
                  ),
                  domain: HopeProductDomain.intelligence,
                ),
                const SizedBox(height: 12),
                _metricGrid(data.entries.where((e) => e.value is num || e.value is String).toList()),
              ],
            )),
          ),
          const SizedBox(height: 18),
          FutureBuilder<Map<String, dynamic>>(
            future: _funnel,
            builder: (_, s) => _loadingOrError(s, (data) => _mapPanel(
              HopeV2Icons.filter,
              _t('قیف محصول', 'Product funnel'),
              data,
            )),
          ),
        ],
      );

  Widget _crashTab() => FutureBuilder<Map<String, dynamic>>(
        future: _crashes,
        builder: (_, s) => _loadingOrError(s, (data) {
          final rows = data.entries.toList();
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _header(
                  HopeV2Icons.error,
                  _t('Crash Center', 'Crash Center'),
                  _t(
                    'خلاصه خطاهای گزارش‌شده از کلاینت‌ها.',
                    'Reported client crash summary.',
                  ),
                  domain: HopeProductDomain.control,
                ),
                const SizedBox(height: 12),
                _metricGrid(rows),
                const SizedBox(height: 14),
                _mapPanel(HopeV2Icons.insights, _t('جزئیات', 'Details'), data),
              ],
            ),
          );
        }),
      );

  Widget _header(
    Object icon,
    String title,
    String subtitle, {
    HopeProductDomain domain = HopeProductDomain.control,
  }) =>
      PremiumPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PremiumDomainMarker(domain: domain, compact: true),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _metricGrid(List<MapEntry<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return _empty(
        HopeV2Icons.insights,
        _t('داده‌ای نیست', 'No metrics'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 700
                ? 3
                : constraints.maxWidth >= 420
                    ? 2
                    : 1;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final enlargedText = textScale > 1.2;
        const gap = 8.0;
        final metricWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        // Metrics are data cards, not fixed-height dashboard tiles: long backend
        // values and larger system text must expand instead of being clipped.
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final entry in entries.take(20))
              SizedBox(
                width: metricWidth,
                child: PremiumPanel(
                  padding: EdgeInsets.all(enlargedText ? 10 : 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _value(entry.value),
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key,
                        softWrap: true,
                        maxLines: enlargedText ? null : 2,
                        overflow: enlargedText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _mapPanel(Object icon, String title, Map<String, dynamic> data) => PremiumPanel(
    padding: const EdgeInsets.all(14),
    child: ExpansionTile(
      leading: HopeIconTile(icon, size: 36),
      title: Text(title),
      children: data.entries.map((e) => ListTile(
        dense: true,
        title: Text(e.key),
        trailing: Text(_value(e.value)),
      )).toList(),
    ),
  );

  Widget _empty(Object icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: EmptyState(icon: icon, title: text, message: ''),
  );
}



class _OutboxEventInvestigationPanel extends StatefulWidget {
  const _OutboxEventInvestigationPanel({
    super.key,
    required this.repository,
    required this.caseId,
    required this.canWrite,
    required this.translate,
    required this.onCaseStatusChanged,
  });

  final AdminRepository repository;
  final String caseId;
  final bool canWrite;
  final String Function(String fa, String en) translate;
  final ValueChanged<String> onCaseStatusChanged;

  @override
  State<_OutboxEventInvestigationPanel> createState() =>
      _OutboxEventInvestigationPanelState();
}

class _OutboxEventInvestigationPanelState extends State<_OutboxEventInvestigationPanel> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _evidenceController = TextEditingController();
  final _random = Random.secure();
  final List<Map<String, dynamic>> _notes = [];
  String _eventIdentity = 'UNRESOLVED';
  String _canonicalPayout = 'NOT_VERIFIED';
  String _providerOutcome = 'NOT_CHECKED';
  String? _nextCursor;
  String? _pendingIdempotencyKey;
  String? _historyError;
  bool _hasMore = false;
  bool _historyBusy = false;
  bool _historyLoaded = false;
  bool _saving = false;

  String _t(String fa, String en) => widget.translate(fa, en);

  @override
  void dispose() {
    _reasonController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  String _newIdempotencyKey() =>
      'event-note-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  Future<void> _loadHistory({bool nextPage = false}) async {
    if (_historyBusy || (nextPage && (!_hasMore || _nextCursor == null))) return;
    setState(() {
      _historyBusy = true;
      _historyError = null;
    });
    try {
      final page = await widget.repository.listOutboxEventReconciliationNotes(
        widget.caseId,
        limit: 25,
        cursor: nextPage ? _nextCursor : null,
      );
      if (!mounted) return;
      final raw = page['notes'];
      final rows = raw is List
          ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList(growable: false)
          : const <Map<String, dynamic>>[];
      setState(() {
        if (!nextPage) _notes.clear();
        _notes.addAll(rows);
        final cursor = page['nextCursor']?.toString();
        _nextCursor = cursor == null || cursor.isEmpty ? null : cursor;
        _hasMore = page['hasMore'] == true && _nextCursor != null;
        _historyLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _historyError = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _historyBusy = false);
    }
  }

  Future<void> _submitNote() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final idempotencyKey = _pendingIdempotencyKey ??= _newIdempotencyKey();
    setState(() => _saving = true);
    try {
      final result = await widget.repository.appendOutboxEventReconciliationNote(
        widget.caseId,
        reason: _reasonController.text.trim(),
        evidenceReference: _evidenceController.text.trim(),
        verification: {
          'eventIdentity': _eventIdentity,
          'canonicalPayout': _canonicalPayout,
          'providerOutcome': _providerOutcome,
        },
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;
      final status = result['caseStatus']?.toString();
      if (status != null && status.isNotEmpty) widget.onCaseStatusChanged(status);
      _reasonController.clear();
      _evidenceController.clear();
      _pendingIdempotencyKey = null;
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('یادداشت بررسی ثبت شد', 'Investigation note saved'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final verification = note['verification'] is Map
        ? Map<String, dynamic>.from(note['verification'] as Map)
        : const <String, dynamic>{};
    final actor = '${note['actorDisplayName'] ?? _t('مدیر سامانه', 'Administrator')}';
    final createdAt = '${note['createdAt'] ?? ''}';
    final evidence = '${note['evidenceReference'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              actor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (createdAt.isNotEmpty)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  createdAt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              '${_t('شرح', 'Reason')}: ${note['reason'] ?? '—'}',
              key: ValueKey('outbox-note-reason-${note['id']}'),
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: SelectableText(
                '${_t('ارجاع مدرک', 'Evidence reference')}: ${evidence.isEmpty ? '—' : evidence}',
                key: ValueKey('outbox-note-evidence-${note['id']}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (verification.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${_t('نتیجه بررسی', 'Verification')}: ${verification.entries.map((entry) => '${entry.key}=${entry.value}').join(' • ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verificationDropdown({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    required String keyName,
  }) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$keyName-${widget.caseId}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: values.map((item) => DropdownMenuItem<String>(
        value: item,
        child: Text(item.replaceAll('_', ' ')),
      )).toList(growable: false),
      onChanged: _saving ? null : (next) {
        _pendingIdempotencyKey = null;
        onChanged(next);
      },
    );
  }

  Widget _composer() {
    if (!widget.canWrite) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 24),
          Text(_t('ثبت یادداشت مستند', 'Add an evidence-backed note'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            _t(
              'این عملیات فقط سابقه بررسی را ثبت می‌کند؛ موجودی، تسویه و وجه قفل‌شده تغییر نمی‌کند. ثبت نیازمند تأیید WRITE همین نشست است.',
              'This appends investigation evidence only. It does not move funds, resolve payouts or release holds. The server requires current-session WRITE step-up.',
            ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextFormField(
            key: ValueKey('outbox-investigation-reason-${widget.caseId}'),
            controller: _reasonController,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(labelText: _t('دلیل بررسی', 'Investigation reason'), alignLabelWithHint: true),
            onChanged: (_) => _pendingIdempotencyKey = null,
            validator: (value) {
              final length = value?.trim().length ?? 0;
              if (length < 10 || length > 1000) return _t('دلیل باید بین ۱۰ تا ۱۰۰۰ نویسه باشد', 'Enter 10 to 1000 characters');
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('outbox-investigation-evidence-${widget.caseId}'),
            controller: _evidenceController,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: _t('ارجاع مدرک', 'Evidence reference'),
              hintText: _t('شناسه تیکت یا مسیر مدرک', 'Incident ID or evidence location'),
            ),
            onChanged: (_) => _pendingIdempotencyKey = null,
            validator: (value) {
              final length = value?.trim().length ?? 0;
              if (length < 8 || length > 500) return _t('ارجاع مدرک باید بین ۸ تا ۵۰۰ نویسه باشد', 'Enter 8 to 500 characters');
              return null;
            },
          ),
          const SizedBox(height: 8),
          _verificationDropdown(
            label: _t('هویت رویداد', 'Event identity'),
            value: _eventIdentity,
            values: const ['MISMATCH_CONFIRMED','UNRESOLVED'],
            keyName: 'outbox-event-identity',
            onChanged: (value) { if (value != null) setState(() => _eventIdentity = value); },
          ),
          const SizedBox(height: 8),
          _verificationDropdown(
            label: _t('تطبیق تسویه مرجع', 'Canonical payout'),
            value: _canonicalPayout,
            values: const ['MATCHED','MISMATCHED','NOT_FOUND','NOT_VERIFIED'],
            keyName: 'outbox-canonical-payout',
            onChanged: (value) { if (value != null) setState(() => _canonicalPayout = value); },
          ),
          const SizedBox(height: 8),
          _verificationDropdown(
            label: _t('نتیجه ارائه‌دهنده', 'Provider outcome'),
            value: _providerOutcome,
            values: const ['SUCCEEDED_CONFIRMED','FAILED_CONFIRMED','UNKNOWN','NOT_CHECKED'],
            keyName: 'outbox-provider-outcome',
            onChanged: (value) { if (value != null) setState(() => _providerOutcome = value); },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _submitNote,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.note_add_outlined),
            label: Text(_saving ? _t('در حال ثبت...', 'Saving...') : _t('ثبت یادداشت بررسی', 'Add investigation note')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        key: PageStorageKey<String>('outbox-investigation-${widget.caseId}'),
        title: Text(_t('یادداشت‌های بررسی', 'Investigation notes')),
        subtitle: Text(_t(
          'مشاهده سابقه مستند؛ بدون تغییر وضعیت مالی',
          'Evidence history only; no financial state changes',
        )),
        onExpansionChanged: (expanded) {
          if (expanded && !_historyLoaded && !_historyBusy) _loadHistory();
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_historyBusy && !_historyLoaded)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else if (_historyError != null)
                  Text(_historyError!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                else if (_notes.isEmpty)
                  Text(_t('یادداشتی ثبت نشده است', 'No investigation notes recorded'))
                else
                  ..._notes.map(_noteCard),
                if (_hasMore)
                  OutlinedButton(
                    onPressed: _historyBusy ? null : () => _loadHistory(nextPage: true),
                    child: Text(_historyBusy ? _t('در حال دریافت...', 'Loading...') : _t('یادداشت‌های بیشتر', 'Load more notes')),
                  ),
                if (_historyError != null)
                  TextButton(
                    onPressed: _historyBusy ? null : () => _loadHistory(),
                    child: Text(_t('تلاش دوباره', 'Retry')),
                  ),
                _composer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
