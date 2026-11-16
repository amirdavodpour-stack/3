import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/marketplace/saved_search_repository.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/features/jobs/saved_searches_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

HopeSavedSearch _search(
  String id,
  String name, {
  String kind = 'ALL',
  String visibility = 'ALL',
  String category = 'ALL',
}) => HopeSavedSearch(
  id: id,
  name: name,
  query: 'query for $name',
  kind: kind,
  visibility: visibility,
  city: 'AUTO',
  category: category,
  updatedAt: '2026-09-22T00:00:00Z',
);

class _SequencedSavedSearchRepository implements SavedSearchRepository {
  int calls = 0;
  bool holdInitialLoad = false;
  final Completer<List<HopeSavedSearch>> initialLoad = Completer<List<HopeSavedSearch>>();
  List<HopeSavedSearch>? itemsOverride;
  final List<String> deletedIds = [];
  final Completer<List<HopeSavedSearch>> firstRefresh =
      Completer<List<HopeSavedSearch>>();

  @override
  Future<List<HopeSavedSearch>> list() {
    calls += 1;
    if (calls == 1) {
      if (holdInitialLoad) return initialLoad.future;
      return Future.value(
        itemsOverride ?? [_search('initial', 'Initial search')],
      );
    }
    if (calls == 2) return firstRefresh.future;
    return Future.value([_search('fresh', 'Fresh search')]);
  }

  @override
  Future<HopeSavedSearch> upsert(HopeSavedSearch search) =>
      Future.value(search);

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
  }
}

Widget _host(_SequencedSavedSearchRepository repository) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('fa')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Provider<ApplicationRegistry>.value(
      value: ApplicationRegistry(savedSearches: repository),
      child: const SavedSearchesPage(),
    ),
  );
}

void main() {
  testWidgets(
    'saved-search initial loading previews compact row skeletons instead of a tall spinner',
    (tester) async {
      final repository = _SequencedSavedSearchRepository()
        ..holdInitialLoad = true;
      await tester.pumpWidget(_host(repository));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('saved-search-loading-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(SkeletonBox), findsNWidgets(5));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      repository.initialLoad.complete([
        _search('initial', 'Initial search'),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('saved-search-loading-skeleton')),
        findsNothing,
      );
      expect(find.text('Initial search'), findsWidgets);
    },
  );

  testWidgets(
    'Saved Search create action stays beside page content instead of floating below it',
    (tester) async {
      final repository = _SequencedSavedSearchRepository();
      repository.itemsOverride = [
        _search('adjacent', 'Adjacent search', category: 'SOFTWARE'),
      ];
      await tester.pumpWidget(_host(repository));
      await tester.pumpAndSettle();

      expect(
        tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
        24,
        reason: 'Saved Search relies on the scroll view for its navigation-aware tail.',
      );
      expect(
        find.byKey(const ValueKey('saved-search-create-cta')),
        findsOneWidget,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const ValueKey('saved-search-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved-search enum filters use localized labels', (tester) async {
    final repository = _SequencedSavedSearchRepository();
    repository.itemsOverride = [
      _search(
        'localized',
        'Localized search',
        kind: 'MISSION',
        visibility: 'SPECIALIZED',
      ),
    ];

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Localized search'), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-search-list')), findsOneWidget);
    expect(find.textContaining('Missions'), findsOneWidget);
    expect(find.textContaining('Specialized'), findsOneWidget);
    expect(find.text('MISSION'), findsNothing);
    expect(find.text('SPECIALIZED'), findsNothing);
  });
  testWidgets('saved-search categories use localized labels, not raw slugs', (tester) async {
    final repository = _SequencedSavedSearchRepository();
    repository.itemsOverride = [
      _search('software', 'Software search', category: 'SOFTWARE'),
    ];
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    expect(find.textContaining('SOFTWARE'), findsNothing);
    expect(find.textContaining(' • Software'), findsOneWidget);
  });
  testWidgets('unknown saved-search enums use safe localized fallback', (tester) async {
    final repository = _SequencedSavedSearchRepository();
    repository.itemsOverride = [
      _search(
        'unknown',
        'Unknown search',
        kind: 'FUTURE_KIND',
        visibility: 'FUTURE_VISIBILITY',
      ),
    ];

    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Unknown search'), findsOneWidget);
    expect(find.textContaining('Other'), findsOneWidget);
    expect(find.text('FUTURE_KIND'), findsNothing);
    expect(find.text('FUTURE_VISIBILITY'), findsNothing);
  });

  testWidgets('latest saved-search refresh wins over an older in-flight load',
      (tester) async {
    final repository = _SequencedSavedSearchRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Initial search').first, findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(repository.calls, 2);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(repository.calls, 3);
    // The contract is latest-wins: the fresh result must be present and
    // the stale result must be absent. Do not make this assertion depend on
    // the number of matching Text widgets created by the rendered surface.
    expect(find.text('Fresh search'), findsWidgets);
    expect(find.text('Initial search'), findsNothing);

    repository.firstRefresh.complete([_search('stale', 'Stale search')]);
    await tester.pumpAndSettle();

    expect(find.text('Fresh search'), findsOneWidget);
    expect(find.text('Stale search'), findsNothing);
  });

  testWidgets(
    'saved-search zero state gives a truthful next action instead of a blank list',
    (tester) async {
      final repository = _SequencedSavedSearchRepository()
        ..itemsOverride = const [];
      await tester.pumpWidget(_host(repository));
      await tester.pumpAndSettle();

      expect(find.text('You have no saved searches yet.'), findsOneWidget);
      expect(
        find.text(
          'Save a search from Explore or create your first one with the button below.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('saved-search-create-cta')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('saved-search-list')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'saved-search multi-row state retains other records after confirming one deletion',
    (tester) async {
      final repository = _SequencedSavedSearchRepository()
        ..itemsOverride = [
          _search('one', 'One search'),
          _search('two', 'Two search'),
          _search('three', 'Three search'),
        ];
      await tester.pumpWidget(_host(repository));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('saved-search-list')), findsOneWidget);
      expect(find.text('One search'), findsOneWidget);
      expect(find.text('Two search'), findsOneWidget);
      expect(find.text('Three search'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsNWidgets(3));
      expect(find.byTooltip('Delete'), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey('saved-search-create-cta')),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Delete').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete saved search'), findsOneWidget);
      expect(
        find.text('Delete “One search” from your saved searches?'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deletedIds, ['one']);
      expect(find.text('One search'), findsNothing);
      expect(find.text('Two search'), findsOneWidget);
      expect(find.text('Three search'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

}
