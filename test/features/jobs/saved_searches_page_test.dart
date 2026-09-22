import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/marketplace/saved_search_repository.dart';
import 'package:hope_mobile/features/jobs/saved_searches_page.dart';
import 'package:provider/provider.dart';

HopeSavedSearch _search(String id, String name) => HopeSavedSearch(
  id: id,
  name: name,
  query: 'query for $name',
  kind: 'ALL',
  visibility: 'ALL',
  city: 'AUTO',
  category: 'ALL',
  updatedAt: '2026-09-22T00:00:00Z',
);

class _SequencedSavedSearchRepository implements SavedSearchRepository {
  int calls = 0;
  final Completer<List<HopeSavedSearch>> firstRefresh =
      Completer<List<HopeSavedSearch>>();

  @override
  Future<List<HopeSavedSearch>> list() {
    calls += 1;
    if (calls == 1) return Future.value([_search('initial', 'Initial search')]);
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
    expect(find.text('Fresh search'), findsOneWidget);
    expect(find.text('Initial search'), findsNothing);

    repository.firstRefresh.complete([_search('stale', 'Stale search')]);
    await tester.pumpAndSettle();

    expect(find.text('Fresh search'), findsOneWidget);
    expect(find.text('Stale search'), findsNothing);
  });
}
