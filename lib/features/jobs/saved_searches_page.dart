import '../../core/ui/components.dart';
import 'package:flutter/material.dart';

import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/marketplace/saved_search_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/hope_l10n.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';

ApplicationRegistry _registry(BuildContext context) => applicationRegistryOf(context);

class SavedSearchesPage extends StatefulWidget {
  const SavedSearchesPage({super.key});

  @override
  State<SavedSearchesPage> createState() => _SavedSearchesPageState();
}

class _SavedSearchesPageState extends State<SavedSearchesPage> {
  List<HopeSavedSearch> _items = const [];
  bool _loading = true;
  String? _error;
  int _loadRequestId = 0;
  String? _busyId;

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  SavedSearchRepository get _repo => _registry(context).savedSearches;

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
      _error = null;
      if (!hasExistingItems) _loading = true;
    });
    try {
      final items = await _repo.list();
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _items = items.where((e) => e.isUsable).toList(growable: false);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _loading = false;
        _error = apiErrorMessage(e,
            fallback: _t('جست‌وجوهای ذخیره‌شده قابل دریافت نیستند.',
                'Saved searches could not be loaded.'));
      });
    }
  }

  Future<void> _edit([HopeSavedSearch? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final query = TextEditingController(text: existing?.query ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? _t('جست‌وجوی جدید', 'New saved search')
            : _t('ویرایش جست‌وجو', 'Edit saved search')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 100,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _t('نام', 'Name'),
                  hintText: _t('مثلاً توسعه‌دهنده Flutter', 'e.g. Flutter developer'),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: query,
                maxLength: 240,
                decoration: InputDecoration(
                  labelText: _t('عبارت جست‌وجو', 'Search query'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('انصراف', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = name.text.trim();
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            child: Text(_t('ذخیره', 'Save')),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final q = query.text.trim();
    name.dispose();
    query.dispose();
    if (result == null || n.isEmpty || !mounted) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final item = HopeSavedSearch(
        id: existing?.id.isNotEmpty == true
            ? existing!.id
            : 'search-${DateTime.now().microsecondsSinceEpoch}',
        name: n,
        query: q,
        kind: existing?.kind ?? 'ALL',
        visibility: existing?.visibility ?? 'ALL',
        city: existing?.city ?? 'AUTO',
        category: existing?.category ?? 'ALL',
        updatedAt: now,
      );
      await _repo.upsert(item);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e,
            fallback: _t('ذخیره جست‌وجو ناموفق بود.',
                'Could not save the search.')))),
      );
    }
  }

  Future<void> _delete(HopeSavedSearch item) async {
    if (_busyId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('حذف جست‌وجو', 'Delete saved search')),
        content: Text(_t(
          '«${item.name}» از جست‌وجوهای ذخیره‌شده حذف شود؟',
          'Delete “${item.name}” from your saved searches?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('انصراف', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('حذف', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = item.id);
    try {
      await _repo.delete(item.id);
      if (mounted) {
        setState(() => _items = _items.where((e) => e.id != item.id).toList());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e,
            fallback: _t('حذف جست‌وجو ناموفق بود.',
                'Could not delete the saved search.')))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _kindLabel(HopeSavedSearch item) {
    switch (item.kind.trim().toUpperCase()) {
      case 'MISSION':
        return HopeCopy.of(context).copy_missions_a833d13;
      case 'JOB':
        return HopeCopy.of(context).copy_jobs_ebf9a80;
      default:
        return _t('سایر', 'Other');
    }
  }

  String _visibilityLabel(HopeSavedSearch item) {
    switch (item.visibility.trim().toUpperCase()) {
      case 'PUBLIC':
        return HopeCopy.of(context).copy_public_21e97be;
      case 'SPECIALIZED':
        return HopeCopy.of(context).copy_specialized_5d1ca04;
      default:
        return _t('سایر', 'Other');
    }
  }

  String _categoryLabel(HopeSavedSearch item) {
    final slug = item.category.trim().toLowerCase().replaceAll('_', '-');
    final l10n = AppLocalizations.of(context);
    switch (slug) {
      case 'software':
      case 'software-development':
      case 'development':
        return l10n.categorySoftware;
      case 'design':
      case 'graphic-design':
        return l10n.categoryDesign;
      case 'marketing':
        return l10n.categoryMarketing;
      case 'content':
      case 'translation':
      case 'content-translation':
        return l10n.categoryContentTranslation;
      case 'finance':
      case 'accounting':
      case 'finance-accounting':
        return l10n.categoryFinanceAccounting;
      case 'education':
        return l10n.categoryEducation;
      case 'support':
        return l10n.categorySupport;
      case 'construction':
      case 'technical':
      case 'construction-technical':
        return l10n.categoryConstructionTechnical;
      case 'video':
      case 'audio':
      case 'video-audio':
      case 'video-production':
        return l10n.categoryVideoAudio;
      case 'data':
      case 'ai':
      case 'data-ai':
      case 'artificial-intelligence':
        return l10n.categoryDataAI;
      case 'sales':
        return l10n.categorySales;
      default:
        return l10n.categoryOther;
    }
  }
  String _scope(HopeSavedSearch item) {
    final parts = <String>[];
    if (item.query.isNotEmpty) parts.add(item.query);
    if (item.city.isNotEmpty && item.city != 'AUTO') parts.add(item.city);
    if (item.kind != 'ALL') parts.add(_kindLabel(item));
    if (item.visibility != 'ALL') parts.add(_visibilityLabel(item));
    if (item.category != 'ALL') parts.add(_categoryLabel(item));
    return parts.isEmpty
        ? _t('بدون فیلتر اضافی', 'No additional filters')
        : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
          children: [
            PremiumHeader(
              page: HopePageId.savedSearches,
              domain: HopeProductDomain.discovery,
              eyebrow: _t('جست‌وجو', 'SEARCH'),
              title: _t('جست‌وجوهای ذخیره‌شده', 'Saved searches'),
              subtitle: _t(
                'فیلترهای ذخیره‌شده حساب را ویرایش یا حذف کنید.',
                'Edit or delete the real saved-search filters stored on your account.',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumIconButton(
                    icon: Localizations.localeOf(context).languageCode == 'en'
                        ? HopeV2Icons.arrowLeft
                        : HopeV2Icons.arrowRight,
                    tooltip: _t('بازگشت', 'Back'),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 8),
                  PremiumIconButton(
                    icon: HopeV2Icons.refresh,
                    tooltip: _t('بازخوانی', 'Refresh'),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!_loading && _error == null && _items.isNotEmpty)
              PremiumStatCard(
                label: _t('جست‌وجوهای فعال', 'Saved searches'),
                value: _items.length.toString(),
                icon: HopeV2Icons.savedSearches,
                accent: Theme.of(context).colorScheme.primary,
                compact: true,
                caption: _t(
                  'فیلترهای ذخیره‌شده حساب شما',
                  'Saved filters on your account',
                ),
              ),
            if (!_loading && _error == null && _items.isNotEmpty)
              const SizedBox(height: 8),
            if (_loading)
              const PremiumPanel(
                child: SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              PremiumPanel(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const HopeIcon(HopeV2Icons.pending, size: 36),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const HopeIcon(HopeV2Icons.refresh, size: 19),
                      label: Text(_t('تلاش دوباره', 'Retry')),
                    ),
                  ],
                ),
              )
            else if (_items.isEmpty)
              PremiumEmptyState(
                icon: HopeV2Icons.savedSearches,
                title: _t('هنوز جست‌وجوی ذخیره‌شده‌ای ندارید.',
                    'You have no saved searches yet.'),
                message: _t(
                  'از بخش کاوش یک جست‌وجو را ذخیره کنید یا با دکمهٔ پایین اولین جست‌وجو را بسازید.',
                  'Save a search from Explore or create your first one with the button below.',
                ),
              )
            else
              PremiumPanel(
                key: const ValueKey('saved-search-list'),
                quiet: true,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  children: _items.map((item) {
                    final busy = _busyId == item.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: const HopeIconTile(HopeV2Icons.savedSearches, filled: true),
                      title: Text(item.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_scope(item)),
                      ),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: _t('ویرایش', 'Edit'),
                            onPressed: busy ? null : () => _edit(item),
                            icon: const HopeIcon(HopeV2Icons.insights, size: 19),
                          ),
                          IconButton(
                            tooltip: _t('حذف', 'Delete'),
                            onPressed: busy ? null : () => _delete(item),
                            icon: busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                               : HopeIcon(HopeV2Icons.close, size: 19, color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (!_loading && _error == null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('saved-search-create-cta'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _edit(),
                  icon: const HopeIcon(HopeV2Icons.add, size: 20),
                  label: Text(_t('جست‌وجوی جدید', 'New search')),
                ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
