import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/offer_repository.dart';
import 'package:hope_mobile/features/offers/offers_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

HopeOffer _offer({required String id, required String status}) => HopeOffer(
  id: id,
  jobId: 'job-1',
  providerId: 'provider-1',
  price: '2500000',
  message: 'Offer message',
  status: status,
  createdAt: null,
  updatedAt: null,
);

class _SequencedOfferRepository implements OfferRepository {
  final Completer<List<HopeOffer>> staleRefresh =
      Completer<List<HopeOffer>>();
  int calls = 0;
  final stale = _offer(id: 'stale', status: 'PENDING');
  final fresh = _offer(id: 'fresh', status: 'ACCEPTED');

  @override
  Future<List<HopeOffer>> listMine() {
    calls += 1;
    if (calls == 1) return Future<List<HopeOffer>>.value([stale]);
    if (calls == 2) return staleRefresh.future;
    return Future<List<HopeOffer>>.value([fresh]);
  }
  @override
  Future<List<HopeOffer>> listForJob(String jobId) => listMine();
  @override
  Future<HopeOffer> get(String offerId) => throw UnimplementedError();
  @override
  Future<HopeOffer> submit(String jobId, {required String price, String message = ''}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> accept(String offerId) => throw UnimplementedError();
}

class _AcceptGuardOfferRepository implements OfferRepository {
  final Completer<Map<String, dynamic>> acceptResult =
      Completer<Map<String, dynamic>>();
  int acceptCalls = 0;
  final pending = _offer(id: 'pending', status: 'PENDING');

  @override
  Future<List<HopeOffer>> listMine() async => [pending];

  @override
  Future<List<HopeOffer>> listForJob(String jobId) async => [pending];

  @override
  Future<HopeOffer> get(String offerId) => Future.value(pending);

  @override
  Future<HopeOffer> submit(
    String jobId, {
    required String price,
    String message = '',
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> accept(String offerId) {
    acceptCalls += 1;
    return acceptResult.future;
  }
}

class _RefreshFailureOfferRepository implements OfferRepository {
  int calls = 0;
  final existing = _offer(id: 'existing', status: 'PENDING');

  @override
  Future<List<HopeOffer>> listMine() {
    calls += 1;
    if (calls == 1) return Future.value([existing]);
    return Future<List<HopeOffer>>.error(StateError('offers unavailable'));
  }
  @override
  Future<List<HopeOffer>> listForJob(String jobId) => listMine();
  @override
  Future<HopeOffer> get(String offerId) => throw UnimplementedError();
  @override
  Future<HopeOffer> submit(String jobId, {required String price, String message = ''}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> accept(String offerId) => throw UnimplementedError();
}

Widget _host(OfferRepository repository) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('fa'), Locale('en')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Provider<OfferRepository>.value(
    value: repository,
    child: const OffersPage(),
  ),
);

Widget _hostWithJob(OfferRepository repository) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: const [Locale('fa'), Locale('en')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Provider<OfferRepository>.value(
    value: repository,
    child: const OffersPage(jobId: 'job-1'),
  ),
);

void main() {
testWidgets('accepting an offer disables the financial action until completion',
      (tester) async {
    final repository = _AcceptGuardOfferRepository();
    await tester.pumpWidget(_hostWithJob(repository));
    await tester.pumpAndSettle();

    final acceptButton = find.widgetWithText(FilledButton, 'Accept offer');
    expect(acceptButton, findsOneWidget);

    await tester.tap(acceptButton);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();

    expect(repository.acceptCalls, 1);
    final disabledButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Accepting...'),
    );
    expect(disabledButton.onPressed, isNull);

    repository.acceptResult.complete(const {});
    await tester.pumpAndSettle();
    expect(repository.acceptCalls, 1);
  });

  testWidgets('latest offer refresh wins over an older in-flight load', (tester) async {
    final repository = _SequencedOfferRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(repository.calls, 2);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(repository.calls, 3);
    expect(find.bySemanticsLabel(RegExp('Offer fresh')), findsOneWidget);

    repository.staleRefresh.complete([repository.stale]);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Offer fresh')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Offer stale')), findsNothing);
  });

  testWidgets('offer refresh failure preserves existing rows and shows retry state', (tester) async {
    final repository = _RefreshFailureOfferRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Offer existing')), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Offer existing')), findsOneWidget);
    expect(find.text('Offers unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
