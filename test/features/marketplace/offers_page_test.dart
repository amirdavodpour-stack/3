import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/offer_repository.dart';
import 'package:hope_mobile/features/offers/offers_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeOffers implements OfferRepository {
  final offers = <HopeOffer>[
    HopeOffer(
      id: 'o1',
      jobId: 'j1',
      providerId: 'u1',
      price: '1234567',
      message: 'مبلغ پیشنهادی',
      status: 'PENDING',
      createdAt: '2026-09-21T00:00:00Z',
    ),
  ];

  @override
  Future<List<HopeOffer>> listForJob(String jobId) async => offers;

  @override
  Future<List<HopeOffer>> listMine() async => offers;

  @override
  Future<HopeOffer> get(String offerId) async => offers.first;

  @override
  Future<HopeOffer> submit(
    String jobId, {
    required String price,
    String message = '',
  }) async => offers.first;

  @override
  Future<Map<String, dynamic>> accept(String offerId) async => const {};
}

void main() {
  testWidgets('offers display grouped localized Toman amounts',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Provider<OfferRepository>.value(
          value: _FakeOffers(),
          child: const OffersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final texts = find
        .byWidgetPredicate(
          (widget) => widget is Text && (widget.data?.contains('تومان') ?? false),
        )
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .toList();

    expect(texts, contains('مبلغ: 1,234,567 تومان'));
  });
}
