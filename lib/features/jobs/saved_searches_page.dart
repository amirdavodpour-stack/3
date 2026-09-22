import '../../core/ui/components.dart';
import 'package:flutter/material.dart';

import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/marketplace/saved_search_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/premium_components.dart';

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

  String _scope(HopeSavedSearch item) {
    final parts = <String>[];
    if (item.query.isNotEmpty) parts.add(item.query);
    if (item.city.isNotEmpty && item.city != 'AUTO') parts.add(item.city);
    if (item.kind != 'ALL') parts.add(item.kind);
    if (item.visibility != 'ALL') parts.add(item.visibility);
    if (item.category != 'ALL') parts.add(item.category);
    return parts.isEmpty
        ? _t('بدون فیلتر اضافی', 'No additional filters')
        : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('جست‌وجوهای ذخیره‌شده', 'Saved searches')),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: _t('بازخوانی', 'Refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add_rounded),
        label: Text(_t('جست‌وجوی جدید', 'New search')),
      ),
      body: PremiumPageFrame(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: EdgeInsets.zero,
          children: [
            PremiumHeader(
              eyebrow: _t('جست‌وجو', 'SEARCH'),
              title: _t('جست‌وجوهای ذخیره‌شده', 'Saved searches'),
              subtitle: _t(
                'فیلترهای ذخیره‌شده حساب را ویرایش یا حذف کنید.',
                'Edit or delete the real saved-search filters stored on your account.',
              ),
              trailing: const HopeIconTile(Icons.bookmark_rounded, size: 50, filled: true),
            ),
            const SizedBox(height: 18),
            if (!_loading && _error == null && _items.isNotEmpty)
              PremiumStatCard(
                label: _t('جست‌وجوهای فعال', 'Saved searches'),
                value: _items.length.toString(),
                icon: Icons.bookmark_rounded,
                accent: Theme.of(context).colorScheme.primary,
                caption: _t(
                  'فیلترهای ذخیره‌شده حساب شما',
                  'Saved filters on your account',
                ),
              ),
            if (!_loading && _error == null && _items.isNotEmpty)
              const SizedBox(height: 12),
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
                    const Icon(Icons.cloud_off_rounded, size: 36),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_t('تلاش دوباره', 'Retry')),
                    ),
                  ],
                ),
              )
            else if (_items.isEmpty)
              PremiumPanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.bookmark_border_rounded, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _t('هنوز جست‌وجوی ذخیره‌شده‌ای ندارید.',
                          'You have no saved searches yet.'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t('از بخش Explore یک جست‌وجو را ذخیره کنید یا یک جست‌وجوی جدید بسازید.',
                          'Save a search from Explore or start with the button below.'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              PremiumPanel(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: _items.map((item) {
                    final busy = _busyId == item.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: const HopeIconTile(Icons.bookmark_rounded, filled: true),
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
                            icon: const Icon(Icons.edit_outlined),
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
                                : Icon(Icons.delete_outline_rounded,
                                    color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
