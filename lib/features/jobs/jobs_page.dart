import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import 'package:provider/provider.dart';
import '../../core/application/application_registry.dart';
import '../../core/application/application_registry_context.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/marketplace/category.dart';
import '../../core/marketplace/job.dart';
import '../../core/marketplace/saved_search_repository.dart';
import '../../core/ui/components.dart';
import '../../core/ui/opportunity_card.dart';
import '../../core/ui/premium_components.dart';
import '../../core/theme/hope_v2_design.dart';
import 'jobs_query_logic.dart';

part 'jobs_widgets.part.dart';
part 'jobs_filter_bar.part.dart';

// OpportunityCard rendering is delegated to _JobsResultsSliver in jobs_widgets.part.dart.

ApplicationRegistry _applicationRegistry(BuildContext context) => applicationRegistryOf(context);

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});
  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  late Future<List<HopeJob>> _future;
  String _query = '';
  String _kind = 'ALL';
  String _visibility = 'ALL';
  String _city = 'AUTO';
  String _category = 'ALL';
  List<HopeCategory> _categories = const [];
  List<HopeSavedSearch> _savedSearches = const [];
  String? _categoryError;
  bool _savedSearchMutationBusy = false;
  Timer? _searchDebounce;
  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categoriesFutureInitialized) return;
    _categoriesFutureInitialized = true;
    _loadCategories();
    _loadSavedSearches();
  }

  bool _categoriesFutureInitialized = false;
  Future<List<HopeCategory>> _loadCategories() async {
    try {
      final parsed =
          await _applicationRegistry(context).listCategories();
      if (mounted) {
        setState(() => _categories = parsed);
      }
      return parsed;
    } catch (error) {
      if (mounted) {
        setState(() => _categoryError =
            apiErrorMessage(error, fallback: 'دسته‌بندی‌ها بارگذاری نشدند.'));
      }
      return const [];
    }
  }

  @override
  void initState() {
    super.initState();
    _future = _loadOpportunities();
  }


  Future<void> _loadSavedSearches() async {
    try {
      final items = await _applicationRegistry(context).savedSearches.list();
      if (mounted) setState(() => _savedSearches = items);
    } catch (_) {
      if (mounted) setState(() => _savedSearches = const []);
    }
  }

  String _savedSearchName() {
    final parts = <String>[];
    if (_query.trim().isNotEmpty) parts.add(_query.trim());
    if (_kind != 'ALL') parts.add(_kind);
    if (_visibility != 'ALL') parts.add(_visibility);
    if (_category != 'ALL') parts.add(_category);
    if (_city != 'AUTO') parts.add(_city);
    return parts.isEmpty ? (Localizations.localeOf(context).languageCode == 'en' ? 'All opportunities' : 'همه فرصت‌ها') : parts.join(' • ');
  }

  void _setQuery(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _reloadForCurrentFilters();
    });
  }

  Future<void> _reloadForCurrentFilters() async {
    if (!mounted) return;
    final next = _loadOpportunities();
    setState(() => _future = next);
    await next.catchError((_) => const <HopeJob>[]);
  }

  Future<void> _saveCurrentSearch() async {
    if (_savedSearchMutationBusy) return;
    setState(() => _savedSearchMutationBusy = true);
    final locale = Localizations.localeOf(context).languageCode;
    final controller = TextEditingController(text: _savedSearchName());
    try {
      final name = await showDialog<String>(
        context: context,
      builder: (context) => AlertDialog(
        title: Text(locale == 'en' ? 'Save search' : 'ذخیره جست‌وجو'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(hintText: locale == 'en' ? 'Search name' : 'نام جست‌وجو'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(locale == 'en' ? 'Cancel' : 'لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: Text(locale == 'en' ? 'Save' : 'ذخیره')),
        ],
      ),
      );
      if (!mounted || name == null || name.isEmpty) return;
      final now = DateTime.now().toUtc().toIso8601String();
      final saved = HopeSavedSearch(
        id: 'search-${now.hashCode.abs()}',
        name: name,
        query: _query,
        kind: _kind,
        visibility: _visibility,
        city: _city,
        category: _category,
        updatedAt: now,
      );
      await _applicationRegistry(context).savedSearches.upsert(saved);
      await _loadSavedSearches();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(
                error,
                fallback: locale == 'en'
                    ? 'Could not save the search.'
                    : 'ذخیره جست‌وجو ناموفق بود.',
              ),
            ),
          ),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _savedSearchMutationBusy = false);
    }
  }

  Future<void> _openSavedSearches() async {
    if (_savedSearches.isEmpty) return;
    final selected = await showModalBottomSheet<HopeSavedSearch>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        String? deleteBusyId;
        return StatefulBuilder(
          builder: (context, setSheetState) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            shrinkWrap: true,
            itemCount: _savedSearches.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _savedSearches[index];
              final deleting = deleteBusyId == item.id;
              return ListTile(
                title: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    item.query,
                    item.kind == 'ALL' ? '' : item.kind,
                    item.visibility == 'ALL' ? '' : item.visibility,
                  ].where((value) => value.isNotEmpty).join(' • '),
                ),
                onTap: deleting ? null : () => Navigator.pop(context, item),
                trailing: IconButton(
                  tooltip: Localizations.localeOf(context).languageCode == 'en'
                      ? 'Delete'
                      : 'حذف',
                  onPressed: deleting
                      ? null
                      : () async {
                          setSheetState(() => deleteBusyId = item.id);
                          try {
                            await _applicationRegistry(context)
                                .savedSearches
                                .delete(item.id);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _loadSavedSearches();
                          } catch (error) {
                            if (!context.mounted) return;
                            setSheetState(() => deleteBusyId = null);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  apiErrorMessage(
                                    error,
                                    fallback:
                                        Localizations.localeOf(context)
                                                    .languageCode ==
                                                'en'
                                            ? 'Could not delete the saved search.'
                                            : 'حذف جست‌وجو ناموفق بود.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                  icon: deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              );
            },
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() {
      _query = selected.query;
      _kind = selected.kind;
      _visibility = selected.visibility;
      _city = selected.city;
      _category = selected.category;
      _future = _loadOpportunities();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final next = _loadOpportunities();
    setState(() => _future = next);
    await next.catchError((_) => const <HopeJob>[]);
  }

  Future<List<HopeJob>> _loadOpportunities() =>
      _loadOpportunitiesForCity(_city, context.read<HopeSettingsController>());

  Future<List<HopeJob>> _loadOpportunitiesForCity(
      String city, HopeSettingsController settings) {
    // 'AUTO' resolves to the user's own city; 'همه' means "no specific
    // city" (used below for both request paths).
    final String? selectedCity =
        city == 'AUTO' ? settings.city : (city == 'همه' ? null : city);
    // `_filter` remains the final display-level filter so online jobs can
    // stay visible under a selected city. The recommended endpoint now also
    // receives search/kind/visibility/category constraints server-side, so
    // filtering happens before its top-50 ranking slice and search cannot
    // accidentally miss a matching job ranked below that slice.
    // City remains a recommendation context (distance/location scoring), not
    // a hard exclusion, while plain `/jobs` keeps its exact-match semantics.
    return _applicationRegistry(context).listOpportunities(
          city: settings.personalizedRecommendations ? selectedCity : null,
          personalizedRecommendations: settings.personalizedRecommendations,
          latitude: settings.locationEnabled ? settings.latitude : null,
          longitude: settings.locationEnabled ? settings.longitude : null,
          search: _query,
          kind: _kind,
          visibility: _visibility,
          categoryId: _category,
        );
  }

  /// Resolves the currently selected category slug (`_category`) back to a
  /// localized display label. `_category` has to stay a plain slug because
  /// that's what `filterJobs` matches against the job data, but showing the
  /// raw slug (e.g. "software-development") to the user was itself a bug --
  /// this looks the slug up in the loaded category list instead.
  String _categoryLabel(BuildContext context) {
    if (_category == 'ALL') {
      return HopeCopy.of(context).copy_all_fields_4f77401;
    }
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    for (final c in _categories) {
      if (c.slug == _category) return c.label(isEn);
    }
    return _category;
  }

  List<HopeJob> _filter(List<HopeJob> jobs) {
    final settings = context.read<HopeSettingsController>();
    final activeCity = _city == 'AUTO' ? settings.city : _city;
    return filterJobs(
      jobs: jobs,
      query: _query,
      kind: _kind,
      visibility: _visibility,
      activeCity: activeCity,
      category: _category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<HopeSettingsController>();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<HopeJob>>(
        future: _future,
        builder: (context, snapshot) {
          final jobs = _filter(snapshot.data ?? const <HopeJob>[]);
          return PremiumPageFrame(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _JobsFilterHeader(
                    kind: _kind,
                    visibility: _visibility,
                    categoryError: _categoryError,
                    cityLabel: _city == 'AUTO'
                        ? '${HopeCopy.of(context).copy_near_1df6db0} ${settings.city}'
                        : _city,
                    categoryLabel: _categoryLabel(context),
                    resultCount: jobs.length,
                    onQueryChanged: _setQuery,
                    onKindChanged: (v) {
                      setState(() => _kind = v);
                      _reloadForCurrentFilters();
                    },
                    onVisibilityChanged: (v) {
                      setState(() => _visibility = v);
                      _reloadForCurrentFilters();
                    },
                    onRetryCategories: () {
                      setState(() {
                        _categoryError = null;
                        _loadCategories();
                      });
                    },
                    onPickCity: () => _pickCity(context, settings),
                    onPickCategory: () => _pickCategory(context),
                    savedSearchCount: _savedSearches.length,
                    onSaveSearch:
                        _savedSearchMutationBusy ? null : _saveCurrentSearch,
                    onOpenSavedSearches: _openSavedSearches,
                  ),
                ),
                _JobsResultsSliver(
                  jobs: jobs,
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                  hasError: snapshot.hasError,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickCity(
      BuildContext context, HopeSettingsController settings) async {
    final c = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(20),
        shrinkWrap: true,
        children: [
          Text(HopeCopy.of(context).copy_choose_a_city_a93b334,
              style: Theme.of(context).textTheme.headlineSmall),
          ...[...HopeSettingsController.cities, 'همه'].map((city) => ListTile(
                title: Text(city),
                trailing: (_city == city ||
                        (_city == 'AUTO' && city == settings.city))
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, city),
              )),
        ],
      ),
    );
    if (c == null || !mounted) return;
    final nextCity = c == settings.city ? 'AUTO' : c;
    final nextFuture = _loadOpportunitiesForCity(nextCity, settings);
    setState(() {
      _city = nextCity;
      _future = nextFuture;
    });
    await nextFuture.catchError((_) => const <HopeJob>[]);
  }

  Future<void> _pickCategory(BuildContext context) async {
    final categories = _categories;
    final c = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (_) => ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(HopeCopy.of(context).copy_professional_field_4c6b94e,
                      style: Theme.of(context).textTheme.headlineSmall),
                  ListTile(
                      title: Text(HopeCopy.of(context).copy_all_fields_4f77401),
                      onTap: () => Navigator.pop(context, 'ALL')),
                  ...categories.map((x) => ListTile(
                      title: Text(x.label(
                          Localizations.localeOf(context).languageCode ==
                              'en')),
                      subtitle:
                          x.description.isEmpty ? null : Text(x.description),
                      onTap: () => Navigator.pop(context, x.slug)))
                ]));
    if (c != null && mounted) {
      setState(() => _category = c);
      await _reloadForCurrentFilters();
    }
  }
}
