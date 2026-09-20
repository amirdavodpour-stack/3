import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin/admin_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/app_theme.dart';

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
  late Future<Map<String, dynamic>> _finance;
  late Future<List<Map<String, dynamic>>> _reports;
  late Future<List<Map<String, dynamic>>> _unknownPayouts;
  late Future<Map<String, dynamic>> _analytics;
  late Future<Map<String, dynamic>> _funnel;
  late Future<Map<String, dynamic>> _crashes;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    final r = context.read<AdminRepository>();
    _finance = r.getFinanceSummary();
    _reports = r.listTrustReports();
    _unknownPayouts = r.listUnknownPayouts();
    _analytics = r.getAnalyticsSummary(days: _days);
    _funnel = r.getFunnel(days: _days);
    _crashes = r.getCrashSummary(days: _days);
    if (mounted) setState(() {});
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

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
        appBar: AppBar(
          title: Text(_t('مرکز عملیات', 'Operations center')),
          actions: [
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _days,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _days = v);
                  _reload();
                },
                items: const [7, 30, 90, 365]
                    .map((d) => DropdownMenuItem(value: d, child: Text('$d ${_t('روز', 'days')}')))
                    .toList(),
              ),
            ),
            IconButton(
              tooltip: _t('بازخوانی', 'Refresh'),
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
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
        ),
        body: TabBarView(
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
    );
  }

  Widget _loadingOrError<T>(AsyncSnapshot<T> s, Widget Function(T data) child) {
    if (s.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (s.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
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
              padding: const EdgeInsets.all(18),
              children: [
                _header(
                  Icons.account_balance_rounded,
                  _t('نمای مالی پلتفرم', 'Platform financial overview'),
                  _t('اعداد مستقیماً از کنترل مالی Backend خوانده می‌شوند.',
                      'Values are read directly from the backend financial control.'),
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
                  _header(Icons.shield_outlined, _t('Trust & Safety', 'Trust & Safety'),
                      _t('گزارش‌های واقعی کاربران و وضعیت رسیدگی.', 'Real user reports and their review state.')),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    _empty(Icons.verified_user_outlined, _t('گزارشی وجود ندارد', 'No reports'))
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
      child: HopeSurface(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const HopeIconTile(Icons.flag_outlined, filled: true),
            const SizedBox(width: 10),
            Expanded(child: Text(
              '${row['reason'] ?? _t('گزارش', 'Report')}',
              style: Theme.of(context).textTheme.titleMedium,
            )),
            StatusPill(status, icon: Icons.circle_outlined, color: secondaryAccent(context)),
          ]),
          if ('${row['details'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${row['details']}'),
          ],
          const SizedBox(height: 8),
          Text('${row['entityType'] ?? '—'} • ${row['entityId'] ?? '—'} • ${row['createdAt'] ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final next in const ['REVIEWING', 'RESOLVED', 'DISMISSED'])
              if (next != status)
                OutlinedButton(
                  onPressed: id.isEmpty ? null : () => _setReportStatus(id, next),
                  child: Text(next),
                ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _setReportStatus(String id, String status) async {
    try {
      await context.read<AdminRepository>().updateTrustReportStatus(id, status);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Widget _payoutsTab() => FutureBuilder<List<Map<String, dynamic>>>(
        future: _unknownPayouts,
        builder: (_, s) => _loadingOrError(s, (rows) => RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _header(Icons.payments_outlined, _t('کنترل تسویه', 'Payout operations'),
                      _t('مواردی که Backend برای تصمیم عملیاتی علامت‌گذاری کرده است.',
                          'Cases explicitly awaiting backend operational resolution.')),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    _empty(Icons.task_alt_rounded, _t('تسویه ناشناخته‌ای نیست', 'No unknown payouts'))
                  else
                    ...rows.map(_payoutCard),
                ],
              ),
            )),
      );

  Widget _payoutCard(Map<String, dynamic> row) {
    final id = '${row['id'] ?? row['payoutId'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HopeSurface(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const HopeIconTile(Icons.warning_amber_rounded, filled: true),
            const SizedBox(width: 10),
            Expanded(child: Text('${_t('تسویه', 'Payout')} ${id.isEmpty ? '—' : id}',
                style: Theme.of(context).textTheme.titleMedium)),
            StatusPill('${row['status'] ?? 'UNKNOWN'}', color: AppColors.warning),
          ]),
          const SizedBox(height: 8),
          Text(row.entries
              .where((e) => !{'id', 'payoutId'}.contains(e.key) && (e.value is String || e.value is num))
              .take(6)
              .map((e) => '${e.key}: ${e.value}')
              .join(' • ')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: id.isEmpty ? null : () => _resolvePayout(id, 'FAILED'),
              child: Text(_t('ثبت ناموفق', 'Mark failed')),
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(
              onPressed: id.isEmpty ? null : () => _resolvePayout(id, 'SUCCEEDED'),
              child: Text(_t('ثبت موفق', 'Mark succeeded')),
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _resolvePayout(String id, String decision) async {
    final repository = context.read<AdminRepository>();
    String providerRef = '';
    String reason = '';
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
    try {
      await repository.resolveUnknownPayout(
        id,
        decision: decision,
        providerRef: providerRef.isEmpty ? null : providerRef,
        reason: reason.isEmpty ? null : reason,
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
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
                _header(Icons.insights_rounded, _t('تحلیل محصول', 'Product analytics'),
                    _t('خلاصه رویدادهای ثبت‌شده در بازه انتخابی.', 'Recorded product analytics for the selected period.')),
                const SizedBox(height: 12),
                _metricGrid(data.entries.where((e) => e.value is num || e.value is String).toList()),
              ],
            )),
          ),
          const SizedBox(height: 18),
          FutureBuilder<Map<String, dynamic>>(
            future: _funnel,
            builder: (_, s) => _loadingOrError(s, (data) => _mapPanel(
              Icons.filter_alt_outlined,
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
                _header(Icons.bug_report_outlined, _t('Crash Center', 'Crash Center'),
                    _t('خلاصه خطاهای گزارش‌شده از کلاینت‌ها.', 'Reported client crash summary.')),
                const SizedBox(height: 12),
                _metricGrid(rows),
                const SizedBox(height: 14),
                _mapPanel(Icons.data_object_rounded, _t('جزئیات', 'Details'), data),
              ],
            ),
          );
        }),
      );

  Widget _header(IconData icon, String title, String subtitle) => PremiumPanel(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          HopeIconTile(icon, filled: true, size: 46),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle),
          ])),
        ]),
      );

  Widget _metricGrid(List<MapEntry<String, dynamic>> entries) {
    if (entries.isEmpty) return _empty(Icons.info_outline, _t('داده‌ای نیست', 'No metrics'));
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: entries.take(20).map((e) => PremiumPanel(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_value(e.value), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(e.key, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      )).toList(),
    );
  }

  Widget _mapPanel(IconData icon, String title, Map<String, dynamic> data) => PremiumPanel(
    padding: const EdgeInsets.all(14),
    child: ExpansionTile(
      leading: HopeIconTile(icon),
      title: Text(title),
      children: data.entries.map((e) => ListTile(
        dense: true,
        title: Text(e.key),
        trailing: Text(_value(e.value)),
      )).toList(),
    ),
  );

  Widget _empty(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50),
    child: EmptyState(icon: icon, title: text, message: ''),
  );
}
