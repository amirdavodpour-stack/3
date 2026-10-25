import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/category.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/marketplace_repository.dart';
import 'package:hope_mobile/core/marketplace/saved_search_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/features/jobs/jobs_page.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repo implements MarketplaceRepository {
  final calls = <String>[];
  bool failCategories = false;
  /// All jobs this fake server "knows about", spread across a couple of
  /// cities plus one online job -- used so tests can tell apart "server
  /// filtered by city" from "server ignored the filter", the way a real
  /// backend with an exact-match `city` filter would.
  late final List<HopeJob> _allJobs = [
    job('m1', 'طراحی اپ', 'MISSION', 'تهران'),
    job('j1', 'استخدام Flutter', 'JOB', 'تهران'),
    job('online', 'کار آنلاین', 'MISSION', 'آنلاین'),
    job('d1', 'طراحی گرافیک', 'MISSION', 'تهران',
        categoryId: 'design', category: 'طراحی'),
    job('s1', 'همکاری تخصصی', 'MISSION', 'تهران', visibility: 'SPECIALIZED'),
    job('shiraz1', 'طراحی در شیراز', 'MISSION', 'شیراز'),
  ];

  HopeCategory get techCategory => const HopeCategory(
        id: 'tech',
        slug: 'tech',
        name: 'فناوری',
        nameEn: 'Technology',
        description: '',
        parentId: null,
        sortOrder: 0,
        isActive: true,
      );

  HopeCategory get designCategory => const HopeCategory(
        id: 'design',
        slug: 'design',
        name: 'طراحی',
        nameEn: 'Design',
        description: '',
        parentId: null,
        sortOrder: 1,
        isActive: true,
      );

  HopeJob job(
    String id,
    String title,
    String kind,
    String city, {
    String visibility = 'PUBLIC',
    String categoryId = 'tech',
    String category = 'فناوری',
  }) =>
      HopeJob.fromMap({
        'id': id,
        'title': title,
        'description': 'شرح $title',
        'categoryId': categoryId,
        'category': category,
        'kind': kind,
        'visibility': visibility,
        'city': city,
      });

  @override
  Future<HopeJob> getOpportunity(String id) async =>
      _allJobs.firstWhere((j) => j.id == id, orElse: () => _allJobs.first);

  @override
  Future<List<HopeCategory>> listCategories() async {
    calls.add('categories');
    if (failCategories) throw StateError('category taxonomy unavailable');
    return [techCategory, designCategory];
  }

  @override
  Future<List<HopeJob>> listOpportunities({
    required String? city,
    required bool personalizedRecommendations,
    double? latitude,
    double? longitude,
    String? search,
    String? kind,
    String? visibility,
    String? categoryId,
  }) async {
    calls.add('jobs:${city ?? 'ALL'}:$personalizedRecommendations');
    if (personalizedRecommendations || city == null) return _allJobs;
    return _allJobs.where((j) => (j.city ?? '') == city).toList();
  }

  @override
  Future<HopeJob> createOpportunity(Map<String, dynamic> body) =>
      throw UnimplementedError();

  @override
  Future<void> publishOpportunity(String id) async {}
}

class _LoadingExploreRepo extends _Repo {
  final Completer<List<HopeJob>> pendingJobs =
      Completer<List<HopeJob>>();

  @override
  Future<List<HopeJob>> listOpportunities({
    required String? city,
    required bool personalizedRecommendations,
    double? latitude,
    double? longitude,
    String? search,
    String? kind,
    String? visibility,
    String? categoryId,
  }) => pendingJobs.future;
}

class _RankedExploreRepo extends _Repo {
  @override
  Future<List<HopeJob>> listOpportunities({
    required String? city,
    required bool personalizedRecommendations,
    double? latitude,
    double? longitude,
    String? search,
    String? kind,
    String? visibility,
    String? categoryId,
  }) async {
    final jobs = await super.listOpportunities(
      city: city,
      personalizedRecommendations: personalizedRecommendations,
      latitude: latitude,
      longitude: longitude,
      search: search,
      kind: kind,
      visibility: visibility,
      categoryId: categoryId,
    );
    return jobs.map((job) {
      if (job.id != 'm1') return job;
      final raw = Map<String, dynamic>.from(job.toMap())
        ..['recommendationScore'] = 0.94;
      return HopeJob.fromMap(raw);
    }).toList(growable: false);
  }
}

class _FailOnceExploreRepo extends _Repo {
  int opportunityCalls = 0;

  @override
  Future<List<HopeJob>> listOpportunities({
    required String? city,
    required bool personalizedRecommendations,
    double? latitude,
    double? longitude,
    String? search,
    String? kind,
    String? visibility,
    String? categoryId,
  }) async {
    opportunityCalls += 1;
    if (opportunityCalls == 1) {
      throw StateError('temporary explore network failure');
    }
    return super.listOpportunities(
      city: city,
      personalizedRecommendations: personalizedRecommendations,
      latitude: latitude,
      longitude: longitude,
      search: search,
      kind: kind,
      visibility: visibility,
      categoryId: categoryId,
    );
  }
}

class _LongRangeExploreRepo extends _Repo {
  @override
  Future<List<HopeJob>> listOpportunities({
    required String? city,
    required bool personalizedRecommendations,
    double? latitude,
    double? longitude,
    String? search,
    String? kind,
    String? visibility,
    String? categoryId,
  }) async =>
      [
        job('featured-budget-test', 'فرصت منتخب', 'MISSION', 'تهران'),
        HopeJob.fromMap({
          'id': 'long-range-budget-test',
          'title': 'فرصت با بازه مالی بلند',
          'description': 'Long financial range must remain fully readable.',
          'kind': 'MISSION',
          'visibility': 'PUBLIC',
          'status': 'OPEN',
          'city': 'تهران',
          'budgetMin': '123456789012345',
          'budgetMax': '987654321098765',
        }),
      ];
}

class _SavedSearchFixture implements SavedSearchRepository {
  _SavedSearchFixture(this.items);

  final List<HopeSavedSearch> items;

  @override
  Future<List<HopeSavedSearch>> list() async => List.unmodifiable(items);

  @override
  Future<HopeSavedSearch> upsert(HopeSavedSearch search) async {
    items.removeWhere((item) => item.id == search.id || item.name == search.name);
    items.insert(0, search);
    return search;
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }
}

class _FailOnceSavedSearchFixture extends _SavedSearchFixture {
  _FailOnceSavedSearchFixture(List<HopeSavedSearch> items) : super(items);

  int listCalls = 0;

  @override
  Future<List<HopeSavedSearch>> list() async {
    listCalls += 1;
    if (listCalls == 1) {
      throw StateError('temporary saved-search service failure');
    }
    return super.list();
  }
}

class _SequencedSavedSearchFixture extends _SavedSearchFixture {
  _SequencedSavedSearchFixture() : super([]);

  final Completer<List<HopeSavedSearch>> staleInitialLoad =
      Completer<List<HopeSavedSearch>>();
  int listCalls = 0;

  @override
  Future<List<HopeSavedSearch>> list() {
    listCalls += 1;
    if (listCalls == 1) return staleInitialLoad.future;
    return Future.value(List.unmodifiable(items));
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Repo repo, {
  HopeSettingsController? settings,
  double textScale = 1,
  Locale locale = const Locale('fa'),
  SavedSearchRepository? savedSearches,
}) async {
  HopeSettingsController resolvedSettings;
  if (settings != null) {
    resolvedSettings = settings;
  } else {
    SharedPreferences.setMockInitialValues({});
    resolvedSettings = HopeSettingsController();
    await resolvedSettings.load();
  }
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    locale: locale,
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: resolvedSettings),
          Provider<MarketplaceRepository>.value(value: repo),
          if (savedSearches != null)
            Provider<SavedSearchRepository>.value(value: savedSearches),
        ],
        child: const JobsPage(),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapFilter(
  WidgetTester tester,
  String label,
) async {
  var target = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.text(label),
  );
  if (target.evaluate().isEmpty) {
    final launcher = find.byKey(
      const ValueKey('hope-opportunity-refinement-launcher'),
    );
    expect(launcher, findsOneWidget);
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    target = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.tap(target);
}
void main() {
  testWidgets(
    'Explore exposes retry after the opportunities request fails',
    (tester) async {
      final repo = _FailOnceExploreRepo();
      await _pump(tester, repo);
      await tester.pumpAndSettle();

      expect(repo.opportunityCalls, 1);
      final retry = find.byKey(const ValueKey('explore-retry-opportunities'));
      expect(retry, findsOneWidget);

      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(repo.opportunityCalls, 2);
      expect(find.byKey(const ValueKey('explore-retry-opportunities')), findsNothing);
      expect(find.text('طراحی اپ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide Explore opportunity cards size to content instead of square grid cells',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _Repo());
      await tester.pumpAndSettle();

      final cards = find.byType(OpportunityCard);
      expect(cards, findsWidgets);
      expect(
        tester.getSize(cards.first).height,
        lessThanOrEqualTo(320),
        reason: 'Wide Explore opportunity cards should not reserve a fixed-aspect grid cell when their content is short.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Explore loading placeholders match horizontal compact cards on phones',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _LoadingExploreRepo());
      await tester.pump();

      final skeletons = find.byType(OpportunitySkeletonCard);
      expect(skeletons, findsNWidgets(2));
      for (var index = 0; index < 2; index++) {
        expect(
          tester.getSize(skeletons.at(index)).height,
          lessThanOrEqualTo(132),
          reason: 'Phone Explore loading should reserve a horizontal compact summary, not a tall image-first card.',
        );
        expect(
          tester.getSize(skeletons.at(index)).width,
          greaterThan(300),
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Explore loading follows the padded content width at the 420dp breakpoint',
    (tester) async {
      tester.view.physicalSize = const Size(440, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _LoadingExploreRepo());
      await tester.pump();

      final skeletons = find.byType(OpportunitySkeletonCard);
      expect(skeletons, findsNWidgets(2));
      for (var index = 0; index < 2; index++) {
        expect(
          tester.getSize(skeletons.at(index)).height,
          lessThanOrEqualTo(132),
          reason: 'A 440dp window loses 28dp to the compact page frame, so its 412dp content uses the horizontal phone card layout.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('jobs page requests categories and opportunities',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.byType(JobsPage), findsOneWidget);
    expect(find.text('طراحی اپ'), findsOneWidget);
    expect(repo.calls, contains('categories'));
    expect(repo.calls.any((e) => e.startsWith('jobs:تهران:')), isTrue);
  });

  testWidgets(
      'Explore does not fabricate a recommended opportunity without a real score',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('فرصت بعدی خود را پیدا کنید'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('hope-explore-result-count')),
      findsOneWidget,
    );
    final resultCountText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('hope-explore-result-count')),
        matching: find.byType(Text),
      ),
    );
    expect(
      resultCountText.style?.color,
      HopeV2Colors.ink,
      reason: 'The Explore result count is readable text and must use a neutral foreground.',
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey('hope-opportunity-refinement-launcher'),
        ),
      ),
      const Size(50, 50),
    );
    expect(
      find.byKey(const ValueKey('hope-opportunity-refinement-active-count')),
      findsNothing,
    );

    final searchRect = tester.getRect(find.byType(PremiumSearchBar));
    final filterRect = tester.getRect(
      find.byKey(
        const ValueKey('hope-opportunity-refinement-launcher'),
      ),
    );
    expect(find.text('فرصت‌های موجود'), findsOneWidget);
    expect(find.text('پیشنهادشده برای شما'), findsNothing);
    final featuredFinder = find.byWidgetPredicate(
      (widget) =>
          widget is OpportunityCard &&
          widget.variant == OpportunityCardVariant.featuredScan,
    );
    expect(featuredFinder, findsNothing);
    final firstOpportunityFinder = find.byWidgetPredicate(
      (widget) =>
          widget is OpportunityCard &&
          widget.variant == OpportunityCardVariant.compact,
    ).first;
    expect(firstOpportunityFinder, findsOneWidget);
    final firstOpportunityRect = tester.getRect(firstOpportunityFinder);

    expect(
      (filterRect.top - searchRect.top).abs(),
      lessThan(5),
      reason: 'Compact search and refinement should share a row to recover first-fold height.',
    );
    // The kind selector follows the refinement row, then the featured card.
    final kindFilter = find.byKey(
      const ValueKey('hope-explore-kind-filters'),
    );
    expect(kindFilter, findsOneWidget);
    final kindRect = tester.getRect(kindFilter);
    expect(kindRect.top - filterRect.bottom, lessThan(20));
    expect(firstOpportunityRect.top - kindRect.bottom, lessThan(40));
    expect(tester.takeException(), isNull);
  });


  testWidgets(
    'Explore promotes a featured card only when a real recommendation score exists',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _RankedExploreRepo());
      await tester.pumpAndSettle();

      expect(find.text('پیشنهادشده برای شما'), findsOneWidget);
      expect(find.text('فرصت‌های موجود'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is OpportunityCard &&
              widget.variant == OpportunityCardVariant.featuredScan,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact explore consolidates controls and keeps the first opportunity in the 360x640 viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _Repo());
      await tester.pumpAndSettle();

      final search = tester.getRect(find.byType(PremiumSearchBar));
      final filter = tester.getRect(
        find.byKey(const ValueKey('hope-opportunity-refinement-launcher')),
      );
      final resultCount = tester.getRect(
        find.byKey(const ValueKey('hope-explore-result-count')),
      );
      final kindFilter = tester.getRect(
        find.byKey(const ValueKey('hope-explore-kind-filters')),
      );
      expect(find.text('فرصت‌های موجود'), findsOneWidget);
      expect(find.text('پیشنهادشده برای شما'), findsNothing);
      final firstOpportunity = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is OpportunityCard &&
              widget.variant == OpportunityCardVariant.compact,
        ).first,
      );
      final dock = tester.getRect(
        find.byKey(const ValueKey('hope-navigation-dock')),
      );

      expect((filter.top - search.top).abs(), lessThan(5));
      expect((resultCount.top - search.top).abs(), lessThan(10));
      expect(filter.size, const Size(50, 50));
      expect(kindFilter.height, greaterThanOrEqualTo(48));
      expect(kindFilter.top - filter.bottom, lessThan(20));
      expect(
        firstOpportunity.top,
        lessThan(dock.top - 80),
        reason: 'The first real opportunity must occupy a useful part of the compact first fold.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 35 phone Explore uses full-width editorial opportunity cards',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _Repo());
      await tester.pumpAndSettle();

      final cards = tester.widgetList<OpportunityCard>(
        find.byType(OpportunityCard),
      );
      expect(cards, isNotEmpty);
      expect(
        cards.any((card) => card.variant == OpportunityCardVariant.compactGrid),
        isFalse,
        reason: 'Phone-width Explore should not compress Persian opportunity metadata into tall two-column tiles.',
      );
      expect(
        cards.any((card) => card.variant == OpportunityCardVariant.compact),
        isTrue,
        reason: 'Compact phones should use readable horizontal opportunity summaries.',
      );
      final firstCard = tester.getRect(
        find.byWidgetPredicate(
          (widget) =>
              widget is OpportunityCard &&
              widget.variant == OpportunityCardVariant.compact,
        ).first,
      );
      expect(firstCard.width, greaterThan(280));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact explore uses a short search hint so the control band stays overflow-free',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('جستجو'), findsOneWidget);
    expect(find.bySemanticsLabel('عنوان، شهر یا مهارت...'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'automatic city context does not count as an active filter, but an explicit city does',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hope-opportunity-refinement-active-count')),
      findsNothing,
    );

    await _tapFilter(tester, 'اطراف تهران');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'شیراز'));
    await tester.pumpAndSettle();

    final activeCount = find.byKey(
      const ValueKey('hope-opportunity-refinement-active-count'),
    );
    expect(activeCount, findsOneWidget);
    final activeCountText = find.descendant(
      of: activeCount,
      matching: find.byType(Text),
    );
    expect(activeCountText, findsOneWidget);
    expect(
      tester.widget<Text>(activeCountText).style?.fontSize,
      greaterThanOrEqualTo(12),
      reason: 'The active-filter count is a meaningful numeric status label and must stay readable.',
    );
    expect(find.text('۱', skipOffstage: false), findsWidgets);
  });

  testWidgets('search narrows the rendered opportunity list', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Flutter');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.calls.where((call) => call.startsWith('jobs:')).length,
        greaterThanOrEqualTo(2));
    expect(find.text('استخدام Flutter'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
  });

  testWidgets('online jobs remain visible for a selected city', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('کار آنلاین'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('کار آنلاین'), findsOneWidget);
  });

  testWidgets('kind chip narrows the list to missions only', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'ماموریت‌ها');
    await tester.pumpAndSettle();
    expect(find.text('طراحی اپ'), findsOneWidget);
    expect(find.text('استخدام Flutter'), findsNothing);
  });

  testWidgets('kind chip narrows the list to jobs only', (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'شغل‌ها');
    await tester.pumpAndSettle();
    expect(find.text('استخدام Flutter'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
  });

  testWidgets('visibility chip narrows the list to specialized only',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'تخصصی');
    await tester.pumpAndSettle();
    expect(find.text('همکاری تخصصی'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
  });

  testWidgets('visibility chip toggles from specialized back to public',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'تخصصی');
    await tester.pumpAndSettle();
    expect(find.text('طراحی اپ'), findsNothing);
    await _tapFilter(tester, 'عمومی');
    await tester.pumpAndSettle();
    expect(find.text('طراحی اپ'), findsOneWidget);
    expect(find.text('همکاری تخصصی'), findsNothing);
  });

  testWidgets(
      'selecting a category filters the list and shows its localized label '
      '(regression: picker used to leak the raw slug and never match any job)',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'همه حوزه‌ها');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'طراحی'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'طراحی'));
    await tester.pumpAndSettle();

    expect(find.text('طراحی'), findsOneWidget);
    expect(find.text('design'), findsNothing);
    expect(find.text('طراحی گرافیک'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
    expect(find.text('استخدام Flutter'), findsNothing);
    expect(find.text('کار آنلاین'), findsNothing);
  });

  testWidgets(
    'Explore exposes recovery when saved searches fail to load',
    (tester) async {
      final repo = _Repo();
      final savedSearches = _FailOnceSavedSearchFixture([
        HopeSavedSearch(
          id: 'saved-after-recovery',
          name: 'Design roles',
          query: '',
          kind: 'ALL',
          visibility: 'ALL',
          city: 'AUTO',
          category: 'ALL',
          updatedAt: '2026-10-13T00:00:00Z',
        ),
      ]);
      await _pump(
        tester,
        repo,
        locale: const Locale('en'),
        savedSearches: savedSearches,
      );
      await tester.pumpAndSettle();

      expect(savedSearches.listCalls, 1);
      final launcher = find.byKey(
        const ValueKey('hope-opportunity-refinement-launcher'),
      );
      await tester.tap(launcher);
      await tester.pumpAndSettle();

      final retry = find.byKey(const ValueKey('saved-searches-retry'));
      expect(retry, findsOneWidget);
      expect(find.text('Saved searches · 1'), findsNothing);

      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(savedSearches.listCalls, 2);

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(launcher);
      await tester.pumpAndSettle();

      expect(find.text('Saved searches · 1'), findsOneWidget);
      await tester.tap(find.text('Saved searches · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Design roles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved-search category slug localizes when taxonomy is unavailable',
    (tester) async {
      final repo = _Repo()..failCategories = true;
      final savedSearches = _SavedSearchFixture([
        HopeSavedSearch(
          id: 'saved-unknown-category',
          name: 'Engineering roles',
          query: '',
          kind: 'ALL',
          visibility: 'ALL',
          city: 'AUTO',
          category: 'software-development',
          updatedAt: '2026-10-12T00:00:00Z',
        ),
      ]);
      await _pump(
        tester,
        repo,
        locale: const Locale('en'),
        savedSearches: savedSearches,
      );
      await tester.pumpAndSettle();

      final launcher = find.byKey(
        const ValueKey('hope-opportunity-refinement-launcher'),
      );
      await tester.tap(launcher);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved searches · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Engineering roles'));
      await tester.pumpAndSettle();

      // Saved-search selection closes only the saved-search sheet. Close the
      // underlying refinement sheet, then reopen it to inspect the current label.
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(launcher);
      await tester.pumpAndSettle();

      expect(find.text('software-development'), findsNothing);
      expect(find.text('Software'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown saved-search category uses localized Other fallback when taxonomy is unavailable',
    (tester) async {
      final repo = _Repo()..failCategories = true;
      final savedSearches = _SavedSearchFixture([
        HopeSavedSearch(
          id: 'saved-custom-category',
          name: 'Specialized roles',
          query: '',
          kind: 'ALL',
          visibility: 'ALL',
          city: 'AUTO',
          category: 'custom-finance-area-77',
          updatedAt: '2026-10-12T00:00:00Z',
        ),
      ]);
      await _pump(
        tester,
        repo,
        locale: const Locale('en'),
        savedSearches: savedSearches,
      );
      await tester.pumpAndSettle();

      final launcher = find.byKey(
        const ValueKey('hope-opportunity-refinement-launcher'),
      );
      await tester.tap(launcher);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved searches · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Specialized roles'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      await tester.tap(launcher);
      await tester.pumpAndSettle();

      expect(find.text('custom-finance-area-77'), findsNothing);
      expect(find.text('Other'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late initial saved-search load cannot erase a just-saved search',
    (tester) async {
      final repo = _Repo();
      final savedSearches = _SequencedSavedSearchFixture();
      await _pump(
        tester,
        repo,
        locale: const Locale('en'),
        savedSearches: savedSearches,
      );
      await tester.pumpAndSettle();
      expect(savedSearches.listCalls, 1);

      final launcher = find.byKey(
        const ValueKey('hope-opportunity-refinement-launcher'),
      );
      await tester.tap(launcher);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save this search'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      await tester.tap(
        find.descendant(of: dialog, matching: find.byType(FilledButton)),
      );
      await tester.pumpAndSettle();

      expect(savedSearches.items, hasLength(1));
      expect(savedSearches.listCalls, 2);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      // Complete the old initial request after the save refresh has committed.
      savedSearches.staleInitialLoad.complete(const <HopeSavedSearch>[]);
      await tester.pumpAndSettle();

      await tester.tap(launcher);
      await tester.pumpAndSettle();
      expect(find.text('Saved searches · 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved-search default name uses localized labels instead of transport tokens',
    (tester) async {
      final repo = _Repo();
      final savedSearches = _SavedSearchFixture([]);
      await _pump(
        tester,
        repo,
        savedSearches: savedSearches,
      );
      await tester.pumpAndSettle();

      final launcher = find.byKey(
        const ValueKey('hope-opportunity-refinement-launcher'),
      );
      await tester.tap(launcher);
      await tester.pumpAndSettle();
      await _tapFilter(tester, 'ماموریت‌ها');
      await tester.pumpAndSettle();
      await _tapFilter(tester, 'تخصصی');
      await tester.pumpAndSettle();
      await _tapFilter(tester, 'همه حوزه‌ها');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'طراحی'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ذخیره این جستجو'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final nameField = find.descendant(
        of: dialog,
        matching: find.byType(TextField),
      );
      expect(nameField, findsOneWidget);
      final suggestedName = tester.widget<TextField>(nameField).controller!.text;
      expect(suggestedName, contains('ماموریت'));
      expect(suggestedName, contains('تخصصی'));
      expect(suggestedName, contains('طراحی'));
      expect(suggestedName, isNot(contains('MISSION')));
      expect(suggestedName, isNot(contains('SPECIALIZED')));
      expect(suggestedName, isNot(contains('design')));

      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(savedSearches.items, hasLength(1));
      final saved = savedSearches.items.single;
      expect(saved.name, suggestedName.trim());
      expect(saved.kind, 'MISSION');
      expect(saved.visibility, 'SPECIALIZED');
      expect(saved.category, 'design');
      expect(saved.city, 'AUTO');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('choosing "همه حوزه‌ها" again clears the category filter',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await _tapFilter(tester, 'همه حوزه‌ها');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'طراحی'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('اعمال فیلترها'));
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'طراحی');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'همه حوزه‌ها'));
    await tester.pumpAndSettle();

    expect(find.text('طراحی اپ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('طراحی گرافیک'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('طراحی گرافیک'), findsOneWidget);
  });

  testWidgets(
      'selecting "همه" (all cities) surfaces jobs from every city '
      '(regression: the literal word used to be sent to the server as the '
      'city filter, and since no job\'s city equals that string the '
      'server returned zero jobs)', (tester) async {
    final repo = _Repo();
    SharedPreferences.setMockInitialValues({});
    final settings = HopeSettingsController();
    await settings.load();
    await settings.setPersonalizedRecommendations(false);
    await _pump(tester, repo, settings: settings);
    await tester.pumpAndSettle();

    expect(find.text('طراحی در شیراز'), findsNothing);
    await _tapFilter(tester, 'اطراف تهران');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.widgetWithText(ListTile, 'همه شهرها'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.widgetWithText(ListTile, 'همه شهرها'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'همه شهرها'));
    await tester.pumpAndSettle();

    expect(find.text('طراحی اپ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('طراحی در شیراز'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('طراحی در شیراز'), findsOneWidget);
  });

  testWidgets(
      'picking a specific city still shows online jobs '
      '(regression: forwarding the city filter to the server used to drop '
      'every online job, since the server has no carve-out for them)',
      (tester) async {
    final repo = _Repo();
    SharedPreferences.setMockInitialValues({});
    final settings = HopeSettingsController();
    await settings.load();
    await settings.setPersonalizedRecommendations(false);
    await _pump(tester, repo, settings: settings);
    await tester.pumpAndSettle();

    await _tapFilter(tester, 'اطراف تهران');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'شیراز'));
    await tester.pumpAndSettle();

    expect(find.text('کار آنلاین'), findsOneWidget);
    expect(find.text('طراحی اپ'), findsNothing);
    await tester.scrollUntilVisible(find.text('طراحی در شیراز'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('طراحی در شیراز'), findsOneWidget);
  });
  testWidgets(
    'Wave 24 compact Explore kind filter is visible, 48dp high and stateful',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      final filter = find.byKey(const ValueKey('hope-explore-kind-filters'));
      expect(filter, findsOneWidget);
      expect(tester.getSize(filter).height, greaterThanOrEqualTo(48));
      expect(
        tester.widget<SegmentedButton<String>>(filter).selected,
        contains('ALL'),
      );
      final rect = tester.getRect(filter);
      await tester.tapAt(Offset(rect.left + rect.width / 6, rect.center.dy));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SegmentedButton<String>>(filter).selected,
        isNot(contains('ALL')),
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'Wave53 Explore kind filter labels stay on one line at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        _Repo(),
        textScale: 1.5,
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();

      final filter = find.byKey(
        const ValueKey('hope-explore-kind-filters'),
      );
      final missionLabel = find.descendant(
        of: filter,
        matching: find.text('Missions'),
      );
      expect(filter, findsOneWidget);
      expect(missionLabel, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(missionLabel)
            .computeLineMetrics(),
        hasLength(1),
        reason: 'The MISSION label must not split the word at an enlarged text scale.',
      );
      expect(tester.getSize(filter).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 29 final Explore opportunity stays reachable above the fixed dock at 360x640',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _Repo());
      await tester.pumpAndSettle();

      final lastOpportunity = find.text('طراحی گرافیک');
      final exploreScrollView = find.byType(CustomScrollView);
      expect(exploreScrollView, findsOneWidget);
      for (var attempt = 0;
          attempt < 8 && lastOpportunity.evaluate().isEmpty;
          attempt += 1) {
        await tester.drag(exploreScrollView, const Offset(0, -220));
        await tester.pumpAndSettle();
      }
      expect(
        lastOpportunity,
        findsOneWidget,
        reason: 'The final server-provided opportunity must remain in the scrollable Explore results.',
      );
      await tester.ensureVisible(lastOpportunity);
      await tester.pumpAndSettle();

      final dock = find.byKey(const ValueKey('hope-navigation-dock'));
      expect(lastOpportunity, findsOneWidget);
      expect(dock, findsOneWidget);
      final opportunityRect = tester.getRect(lastOpportunity);
      final dockRect = tester.getRect(dock);
      expect(
        opportunityRect.bottom,
        lessThanOrEqualTo(dockRect.top - 12),
        reason: 'Final Explore opportunity must clear the dock after scrolling.',
      );
      expect(lastOpportunity.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'Wave30 Explore renders English LTR single-column cards with 1.5x system text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        _Repo(),
        textScale: 1.5,
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Find your next opportunity'), findsOneWidget);
      expect(find.text('Available opportunities'), findsOneWidget);
      expect(find.text('Recommended for you'), findsNothing);
      final cards = tester.widgetList<OpportunityCard>(
        find.byType(OpportunityCard),
      );
      expect(cards, isNotEmpty);
      expect(
        cards.any((card) => card.variant == OpportunityCardVariant.compactGrid),
        isFalse,
        reason: 'Enlarged English text must not use two-column compact-grid cards.',
      );
      expect(
        cards.any((card) => card.variant == OpportunityCardVariant.compact),
        isFalse,
        reason: 'Enlarged English text must use readable opportunity summaries.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 26 Explore falls back to a single column at enlarged text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester, _Repo(), textScale: 1.5);
      await tester.pumpAndSettle();

      final cards = tester.widgetList<OpportunityCard>(
        find.byType(OpportunityCard),
      );
      expect(cards, isNotEmpty);
      expect(
        cards.any((card) => card.variant == OpportunityCardVariant.compactGrid),
        isFalse,
        reason: 'Enlarged text must prioritize readable single-column opportunity summaries.',
      );
      expect(
        cards.any((card) => card.variant == OpportunityCardVariant.compact),
        isFalse,
        reason: 'Compressed summaries are not used when system text is enlarged.',
      );
      expect(find.text('طراحی اپ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact Explore does not clip long financial ranges at 1.2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        _LongRangeExploreRepo(),
        textScale: 1.2,
      );
      await tester.pumpAndSettle();

      final budget = find.byKey(
        const ValueKey('opportunity-card-compact-budget'),
      );
      await tester.scrollUntilVisible(
        budget,
        120,
        scrollable: find.byType(Scrollable).first,
      );

      final paragraph = tester.renderObject<RenderParagraph>(budget);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'The compact card must not clip the lower bound, upper bound, or Toman unit.',
      );
      expect(
        paragraph.text.toPlainText(),
        '۱۲۳٬۴۵۶٬۷۸۹٬۰۱۲٬۳۴۵ تا ۹۸۷٬۶۵۴٬۳۲۱٬۰۹۸٬۷۶۵ تومان',
      );
      expect(
        paragraph.text.toPlainText().split('تومان').length - 1,
        1,
        reason: 'A compact Persian amount range should show its currency unit once, after both exact bounds.',
      );
      expect(tester.takeException(), isNull);
    },
  );

}
