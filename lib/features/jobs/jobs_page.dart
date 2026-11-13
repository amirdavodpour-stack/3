import '../../core/router/app_routes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/copy.dart';
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
import '../../core/ui/hope_display_formatters.dart';
import '../../core/ui/premium_components.dart';
import '../../core/ui/hope_feedback.dart';
import '../../core/theme/hope_v2_design.dart';
import 'jobs_query_logic.dart';

part 'jobs_widgets.part.dart';
part 'jobs_filter_bar.part.dart';
part 'jobs_saved_searches.part.dart';

// OpportunityCard rendering is delegated to _JobsResultsSliver in jobs_widgets.part.dart.

ApplicationRegistry _applicationRegistry(BuildContext context) => applicationRegistryOf(context);

class JobsPage extends StatefulWidget {
  const JobsPage({
    super.key,
    this.showPrimaryNavigation = true,
  });

  final bool showPrimaryNavigation;

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
  bool _savedSearchesLoadError = false;
  String? _categoryError;
  bool _savedSearchMutationBusy = false;
  int _savedSearchesLoadRequestId = 0;
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
        setState(() => _categoryError = apiErrorMessage(
              error,
              fallback: HopeCopy.of(context).copy_categories_load_failed,
            ));
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
    final requestId = ++_savedSearchesLoadRequestId;
    try {
      final items = await _applicationRegistry(context).savedSearches.list();
      if (mounted && requestId == _savedSearchesLoadRequestId) {
        setState(() {
          _savedSearches = items;
          _savedSearchesLoadError = false;
        });
      }
    } catch (_) {
      if (mounted && requestId == _savedSearchesLoadRequestId) {
        setState(() {
          _savedSearches = const [];
          _savedSearchesLoadError = true;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final next = _loadOpportunities();
    setState(() { _future = next; });
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
    // Saved searches may outlive a category-list failure or refer to a slug
    // unknown to the server. Reuse the canonical local taxonomy labels and
    // never expose raw transport slugs in the visible filter summary.
    return hopeCategoryLabel(context, _category, unknownAsOther: true);
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
    final content = _buildContent(context);
    if (!widget.showPrimaryNavigation) return content;
    return PremiumPrimaryNavigationScaffold(
      selectedIndex: 1,
      onDestinationSelected: (index) => _navigatePrimary(context, index),
      child: content,
    );
  }

  void _navigatePrimary(BuildContext context, int index) {
    if (index == 1) return;
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

  Widget _buildContent(BuildContext context) {
    final settings = context.watch<HopeSettingsController>();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<HopeJob>>(
        future: _future,
        builder: (context, snapshot) {
          final jobs = _filter(snapshot.data ?? const <HopeJob>[]);
          final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
          return PremiumPageFrame(
            page: HopePageId.explore,
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 18,
              compact ? 4 : 10,
              compact ? 14 : 18,
              20,
            ),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: PremiumHeader(
                    dense: true,
                    page: HopePageId.explore,
                    domain: HopeProductDomain.discovery,
                    eyebrow: _t(context, 'کاوش', 'EXPLORE'),
                    title: _t(context,
                      'فرصت بعدی خود را پیدا کنید',
                      'Find your next opportunity',
                    ),
                    subtitle: _t(context,
                      'کار و مأموریت‌های متناسب با مسیر کاری شما.',
                      'Jobs and missions matched to your professional path.',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 6),
                ),
                SliverToBoxAdapter(
                  child: _JobsFilterHeader(
                    domain: HopeProductDomain.discovery,
                    kind: _kind,
                    visibility: _visibility,
                    categoryError: _categoryError,
                    cityLabel: _city == 'AUTO'
                        ? '${HopeCopy.of(context).copy_near_1df6db0} ${settings.city}'
                        : _city,
                    cityIsExplicit: _city != 'AUTO',
                    categoryLabel: _categoryLabel(context),
                    resultCount: jobs.length,
                    onQueryChanged: this._setQuery,
                    onKindChanged: (v) {
                      setState(() => _kind = v);
                      this._reloadForCurrentFilters();
                    },
                    onVisibilityChanged: (v) {
                      setState(() => _visibility = v);
                      this._reloadForCurrentFilters();
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
                    savedSearchesLoadError: _savedSearchesLoadError,
                    onRetrySavedSearches: _loadSavedSearches,
                    onSaveSearch:
                        _savedSearchMutationBusy ? null : this._saveCurrentSearch,
                    onOpenSavedSearches: this._openSavedSearches,
                  ),
                ),
                _JobsResultsSliver(
                  jobs: jobs,
                  isLoading:
                      snapshot.connectionState == ConnectionState.waiting,
                  hasError: snapshot.hasError,
                  onRetry: _refresh,
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: HopeV2Navigation.scrollEndPadding(context).bottom,
                  ),
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
        padding: const EdgeInsets.all(14),
        shrinkWrap: true,
        children: [
          Text(HopeCopy.of(context).copy_choose_a_city_a93b334,
              style: HopeV2Type.section(context)),
          ...[...HopeSettingsController.cities, 'همه'].map((city) => ListTile(
                title: Text(
                  city == 'همه' ? HopeCopy.of(context).copy_all_cities : city,
                ),
                trailing: (_city == city ||
                        (_city == 'AUTO' && city == settings.city))
                    ? const HopeIcon(HopeV2Icons.completed, size: 18)
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
                padding: const EdgeInsets.all(14),
                children: [
                  Text(HopeCopy.of(context).copy_professional_field_4c6b94e,
                      style: HopeV2Type.section(context)),
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
      await this._reloadForCurrentFilters();
    }
  }
}
