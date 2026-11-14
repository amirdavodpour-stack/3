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
          ...rows.map(
            (item) => _reconciliationCaseCard(
              item,
              showResourceLocator: true,
            ),
          ),
        if (_outboxEventHasMore) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _outboxEventLoadMoreBusy
                  ? null
                  : _loadMoreOutboxEventCases,
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
    final status = '${item['status'] ?? '—'}'.trim().toUpperCase();
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
