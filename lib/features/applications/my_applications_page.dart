import '../../core/ui/components.dart';
import 'package:flutter/material.dart';

import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/marketplace/application.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  List<HopeApplication> _items = const [];
  bool _loading = true;
  String _filter = 'ALL';
  String? _busyId;

  ApplicationRegistry get _registry => applicationRegistryOf(context);

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _registry.listApplications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error,
            fallback: _t('درخواست‌ها قابل دریافت نیستند.', 'Could not load applications.')))),
      );
    }
  }

  List<HopeApplication> get _visible {
    if (_filter == 'ALL') return _items;
    return _items.where((item) => item.status == _filter).toList();
  }

  Future<void> _withdraw(HopeApplication item) async {
    if (_busyId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('پس گرفتن درخواست؟', 'Withdraw application?')),
        content: Text(_t(
          'درخواست «${item.jobTitle}» از وضعیت فعلی خارج می‌شود.',
          'Your application for “${item.jobTitle}” will be withdrawn from its current workflow.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('پس گرفتن', 'Withdraw')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyId = item.id);
    try {
      await _registry.withdrawApplication(item.id);
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error,
            fallback: _t('پس گرفتن درخواست ناموفق بود.', 'Could not withdraw application.')))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Color _statusColor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'ACCEPTED':
        return scheme.tertiary;
      case 'REJECTED':
        return scheme.error;
      case 'WITHDRAWN':
        return scheme.outline;
      case 'OFFERED':
        return scheme.primary;
      default:
        return scheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final counts = <String, int>{};
    for (final item in _items) {
      counts[item.status] = (counts[item.status] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(title: Text(_t('درخواست‌های من', 'My applications'))),
      body: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
          children: [
            PremiumHeader(
              eyebrow: _t('درخواست‌ها', 'APPLICATIONS'),
              title: _t('درخواست‌های من', 'My applications'),
              subtitle: _t(
                'وضعیت هر درخواست را بررسی کنید و فقط در وضعیت‌های مجاز آن را پس بگیرید.',
                'Track every application and withdraw only while its workflow still allows it.',
              ),
              trailing: PremiumTag(icon: Icons.assignment_rounded, label: _items.length.toString()),
            ),
            const SizedBox(height: 16),
            if (!_loading)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('ALL', _t('همه', 'All'), _items.length),
                    ...['PENDING', 'SHORTLISTED', 'FORWARDED', 'INTERVIEW', 'OFFERED', 'ACCEPTED', 'REJECTED']
                        .where((s) => (counts[s] ?? 0) > 0)
                        .map((s) => _filterChip(s, HopeApplication(
                              id: '', jobId: '', jobTitle: '', jobCity: null,
                              jobKind: '', resumeText: '', skills: '',
                              status: s, createdAt: null, updatedAt: null,
                            ).statusLabel, counts[s]!)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_loading)
              const PremiumPanel(
                child: SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
              )
            else if (visible.isEmpty)
              PremiumPanel(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: [
                    const Icon(Icons.inbox_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _filter == 'ALL'
                          ? _t('هنوز درخواستی ثبت نکرده‌اید.', 'You have not submitted any applications yet.')
                          : _t('در این وضعیت درخواستی وجود ندارد.', 'No applications match this status.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            else
              ...visible.map(_applicationCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label, int count) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: PremiumFilterChip(
        label: '$label  $count',
        selected: _filter == value,
        onTap: () => setState(() => _filter = value),
        color: _statusColor(context, value),
      ),
    );
  }

  Widget _applicationCard(HopeApplication item) {
    final color = _statusColor(context, item.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumPanel(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HopeIconTile(
                  item.status == 'ACCEPTED'
                      ? Icons.check_circle_rounded
                      : Icons.assignment_outlined,
                  filled: true,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.jobTitle.isEmpty ? _t('فرصت', 'Opportunity') : item.jobTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          StatusPill(item.statusLabel, color: color, icon: Icons.circle),
                          if (item.jobCity?.isNotEmpty == true)
                            StatusPill(item.jobCity!, color: Theme.of(context).colorScheme.outline,
                                icon: Icons.location_on_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _timeline(item),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: item.jobId.isEmpty
                        ? null
                        : () async {
                            try {
                              final job = await _registry.getOpportunity(item.jobId);
                              if (!mounted) return;
                              Navigator.push(context, HopeRoutes.jobDetail(job));
                            } catch (error) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(apiErrorMessage(error,
                                    fallback: _t('فرصت در دسترس نیست.', 'Opportunity is unavailable.')))),
                              );
                            }
                          },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(_t('مشاهده فرصت', 'View opportunity')),
                  ),
                ),
                if (item.canWithdraw) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _t('پس گرفتن', 'Withdraw'),
                    onPressed: _busyId == item.id ? null : () => _withdraw(item),
                    icon: _busyId == item.id
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.undo_rounded),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(HopeApplication item) {
    const stages = ['PENDING', 'SHORTLISTED', 'FORWARDED', 'INTERVIEW', 'OFFERED', 'ACCEPTED'];
    final current = stages.indexOf(item.status);
    return Row(
      children: List.generate(stages.length, (index) {
        final reached = current >= 0 && index <= current;
        final active = index == current;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: active ? 12 : 9,
                height: active ? 12 : 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached
                      ? _statusColor(context, item.status)
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              if (index < stages.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: reached && index < current
                        ? _statusColor(context, item.status)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
