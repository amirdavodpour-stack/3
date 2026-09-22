import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/marketplace/saved_search_repository.dart';
import 'package:hope_mobile/features/jobs/saved_searches_page.dart';
import 'package:provider/provider.dart';

HopeSavedSearch _search(
  String id,
  String name, {
  String kind = 'ALL',
  String visibility = 'ALL',
}) => HopeSavedSearch(
  id: id,
  name: name,
  query: 'query for $name',
  kind: kind,
  visibility: visibility,
  city: 'AUTO',
  category: 'ALL',
  updatedAt: '2026-09-22T00:00:00Z',
);

class _SequencedSavedSearchRepository implements SavedSearchRepository {
  int calls = 0;
  List<HopeSavedSearch>? itemsOverride;
  final Completer<List<HopeSavedSearch>> firstRefresh =
      Completer<List<HopeSavedSearch>>();

  @override
  Future<List<HopeSavedSearch>> list() {
    calls += 1;
    if (calls == 1) {
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
  Future<void> delete(String id) async {}
}

Widget _host(_SequencedSavedSearchRepository repository) {
  return MaterialApp(
    locale: const Locale('en'),
    home: Provider<ApplicationRegistry>.value(
      value: ApplicationRegistry(savedSearches: repository),
      child: const SavedSearchesPage(),
    ),
  );
}

void main() {
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
    expect(find.textContaining('Missions'), findsOneWidget);
    expect(find.textContaining('Specialized'), findsOneWidget);
    expect(find.text('MISSION'), findsNothing);
    expect(find.text('SPECIALIZED'), findsNothing);
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
}
