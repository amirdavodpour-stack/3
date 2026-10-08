import '../../core/ui/components.dart';
import 'package:flutter/material.dart';

import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/marketplace/application.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_feedback.dart';
import '../../core/theme/hope_v2_design.dart';

class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  List<HopeApplication> _items = const [];
  bool _loading = true;
  String? _loadError;
  int _loadRequestId = 0;
  String _filter = 'ALL';
  String? _busyId;

  ApplicationRegistry get _registry => applicationRegistryOf(context);

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  bool get _isEnglish =>
      Localizations.localeOf(context).languageCode == 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final requestId = ++_loadRequestId;
    final hasExistingItems = _items.isNotEmpty;
    setState(() {
      _loadError = null;
      if (!hasExistingItems) _loading = true;
    });
    try {
      final items = await _registry.listApplications();
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _items = items;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _loading = false;
        _loadError = apiErrorMessage(
          error,
          fallback: _t(
            'درخواست‌ها قابل دریافت نیستند.',
            'Could not load applications.',
          ),
        );
      });
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
      HopeFeedback.show(context, apiErrorMessage(error, fallback: _t('پس گرفتن درخواست ناموفق بود.', 'Could not withdraw application.')), tone: HopeFeedbackTone.error);
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

  List<HopeApplication> _activeApplicationList(
    List<HopeApplication> items,
  ) =>
      items
          .where(
            (item) => const {
              'PENDING',
              'SHORTLISTED',
              'FORWARDED',
              'INTERVIEW',
              'ACCEPTED',
            }.contains(item.status.toUpperCase()),
          )
          .toList(growable: false);

  List<HopeApplication> _decisionApplicationList(
    List<HopeApplication> items,
  ) =>
      items
          .where((item) => item.status.toUpperCase() == 'OFFERED')
          .toList(growable: false);

  List<HopeApplication> _closedApplicationList(
    List<HopeApplication> items,
  ) =>
      items
          .where(
            (item) => const {
              'REJECTED',
              'WITHDRAWN',
            }.contains(item.status.toUpperCase()),
          )
          .toList(growable: false);

  List<Widget> _applicationSections(
    BuildContext context,
    List<HopeApplication> items,
  ) {
    final activeApplications = _activeApplicationList(items);
    final decisionApplications = _decisionApplicationList(items);
    final closedApplications = _closedApplicationList(items);
    final sections = <Widget>[];

    void addSection(
      String title,
      String subtitle,
      List<HopeApplication> rows,
      HopeProductDomain domain,
    ) {
      if (rows.isEmpty) return;
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 10));
      }
      sections.add(
        PremiumSectionHeader(
          page: HopePageId.myApplications,
          domain: domain,
          title: title,
          subtitle: subtitle,
        ),
      );
      sections.add(const SizedBox(height: 10));
      sections.addAll(rows.map(_applicationCard));
    }

    addSection(
      _t('در حال پیگیری', 'In progress'),
      _t(
        'درخواست‌هایی که هنوز در چرخه انتخاب و همکاری هستند.',
        'Applications still moving through selection and collaboration.',
      ),
      activeApplications,
      HopeProductDomain.work,
    );
    addSection(
      _t('نیازمند تصمیم', 'Needs decision'),
      _t(
        'پیشنهادهایی که به اقدام مستقیم شما نیاز دارند.',
        'Offers that require a direct decision from you.',
      ),
      decisionApplications,
      HopeProductDomain.work,
    );
    addSection(
      _t('بسته‌شده', 'Closed'),
      _t(
        'درخواست‌هایی که دیگر اقدام کاری روی آن‌ها باز نیست.',
        'Applications that no longer have an active work action.',
      ),
      closedApplications,
      HopeProductDomain.work,
    );

    final known = {
      ...activeApplications.map((item) => item.id),
      ...decisionApplications.map((item) => item.id),
      ...closedApplications.map((item) => item.id),
    };
    final uncategorized = items
        .where((item) => !known.contains(item.id))
        .toList(growable: false);
    if (uncategorized.isNotEmpty) {
      addSection(
        _t('سایر وضعیت‌ها', 'Other statuses'),
        _t(
          'وضعیتی که در چرخهٔ استاندارد درخواست تعریف نشده است.',
          'A status outside the standard application lifecycle.',
        ),
        uncategorized,
        HopeProductDomain.work,
      );
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final counts = <String, int>{};
    for (final item in _items) {
      counts[item.status] = (counts[item.status] ?? 0) + 1;
    }

    return Scaffold(
      body: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 72),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
          children: [
            PremiumHeader(
              page: HopePageId.myApplications,
              domain: HopeProductDomain.work,
              dense: true,
              eyebrow: _t('درخواست‌ها', 'APPLICATIONS'),
              title: _t('درخواست‌های من', 'My applications'),
              subtitle: _t(
                'وضعیت هر درخواست را بررسی کنید و فقط در وضعیت‌های مجاز آن را پس بگیرید.',
                'Track every application and withdraw only while its workflow still allows it.',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  PremiumIconButton(
                    icon: Localizations.localeOf(context).languageCode == 'en'
                        ? HopeV2Icons.arrowLeft
                        : HopeV2Icons.arrowRight,
                    tooltip: _t('بازگشت', 'Back'),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  PremiumIconButton(
                    icon: HopeV2Icons.refresh,
                    tooltip: _t('بازخوانی', 'Refresh'),
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
                            ).statusLabelFor(english: _isEnglish), counts[s]!)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (_loading)
              HopeAsyncState(
                kind: HopeStateKind.loading,
                title: _t(
                  'در حال بارگذاری درخواست‌ها',
                  'Loading applications',
                ),
                message: _t(
                  'آخرین وضعیت درخواست‌ها و چرخه همکاری در حال دریافت است.',
                  'The latest application and collaboration state is loading.',
                ),
              )
            else if (_loadError != null)
              ...[
                HopeAsyncState(
                  kind: HopeStateKind.error,
                  title: _t(
                    'درخواست‌ها قابل دریافت نیستند.',
                    'Could not load applications.',
                  ),
                  message: _loadError!,
                  action: FilledButton(
                    onPressed: _load,
                    child: Text(_t('تلاش دوباره', 'Retry')),
                  ),
                ),
                ..._applicationSections(context, visible),
              ]
            else if (visible.isEmpty)
              PremiumPanel(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: [
                    const HopeIcon(HopeV2Icons.mission, size: 40),
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
              ..._applicationSections(context, visible),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPanel(
        quiet: true,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HopeIconTile(
                  item.status == 'ACCEPTED'
                      ? HopeV2Icons.completed
                      : HopeV2Icons.mission,
                  filled: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.jobTitle.isEmpty ? _t('فرصت', 'Opportunity') : item.jobTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          PremiumTag(icon: HopeV2Icons.activity, label: item.statusLabelFor(english: _isEnglish), color: color),
                          if (item.jobCity?.isNotEmpty == true)
                            PremiumTag(icon: HopeV2Icons.location, label: item.jobCity!, color: Theme.of(context).colorScheme.outline),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _timeline(item),
            if (item.status.toUpperCase() == 'ACCEPTED' &&
                item.jobId.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    HopeRoutes.jobChat(item.jobId),
                  ),
                  icon: const HopeIcon(HopeV2Icons.message, size: 19),
                  label: Text(_t('گفتگوی همکاری', 'Collaboration chat')),
                ),
              ),
            ],
            const SizedBox(height: 8),
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
                              HopeFeedback.show(context, apiErrorMessage(error, fallback: _t('فرصت در دسترس نیست.', 'Opportunity is unavailable.')), tone: HopeFeedbackTone.error);
                            }
                          },
                    icon: const HopeIcon(HopeV2Icons.arrowRight, size: 19),
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
                        : const HopeIcon(HopeV2Icons.transferOut, size: 19),
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
