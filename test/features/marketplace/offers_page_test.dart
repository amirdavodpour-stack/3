import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/offer_repository.dart';
import 'package:hope_mobile/features/offers/offers_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class _FakeOffers implements OfferRepository {
  _FakeOffers({this.status = 'PENDING'})
      : offers = <HopeOffer>[
          HopeOffer(
            id: 'o1',
            jobId: 'j1',
            providerId: 'u1',
            price: '1234567',
            message: 'مبلغ پیشنهادی',
            status: status,
            createdAt: '2026-09-21T00:00:00Z',
          ),
        ];

  final String status;
  final List<HopeOffer> offers;

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

    expect(texts, contains('۱٬۲۳۴٬۵۶۷ تومان'));
    expect(find.byKey(const ValueKey('offer-card-o1')), findsOneWidget);
  });

  testWidgets('offer cards expose grouped financial semantics',
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

    final semantics = tester.ensureSemantics();
    try {
      final row = find.ancestor(
        of: find.text('۱٬۲۳۴٬۵۶۷ تومان'),
        matching: find.byType(Semantics),
      ).first;
      final node = tester.getSemantics(row);
      expect(node.label, 'پیشنهاد همکاری، ۱٬۲۳۴٬۵۶۷ تومان، در انتظار بررسی');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('compact offers filters disclose horizontal scrolling and keep the final filter reachable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
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

    expect(
      find.byKey(const ValueKey('offers-status-filter-scroll-cue')),
      findsOneWidget,
    );
    expect(find.text('Swipe to see more filters'), findsOneWidget);

    final finalStatus = find.text('Rejected (0)');
    await tester.ensureVisible(finalStatus);
    await tester.pumpAndSettle();
    expect(finalStatus, findsOneWidget);
    expect(tester.getRect(finalStatus).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(finalStatus).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'fa RTL offers filters keep both logical rail endpoints fully visible',
    (tester) async {
      for (final width in [320.0, 360.0]) {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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

        final rail = find.byKey(const ValueKey('offers-status-filter-scroll'));
        expect(rail, findsOneWidget);
        expect(
          Directionality.of(tester.element(rail)),
          TextDirection.rtl,
          reason: 'The Persian filter rail must use RTL scroll direction.',
        );
        expect(
          find.byKey(const ValueKey('offers-status-filter-scroll-cue')),
          findsOneWidget,
        );

        final railRect = tester.getRect(rail);
        final firstLabel = find.textContaining('همه');
        expect(firstLabel, findsOneWidget);
        final firstChip = find.ancestor(
          of: firstLabel,
          matching: find.byType(InkWell),
        ).first;
        final firstRect = tester.getRect(firstChip);
        expect(
          firstRect.left,
          greaterThanOrEqualTo(railRect.left),
          reason: 'The first RTL filter must not be clipped at the left viewport edge.',
        );
        expect(
          firstRect.right,
          lessThanOrEqualTo(railRect.right),
          reason: 'The first RTL filter must not be clipped at the right viewport edge.',
        );

        final finalLabel = find.textContaining('رد شده');
        expect(finalLabel, findsOneWidget);
        await tester.ensureVisible(finalLabel);
        await tester.pumpAndSettle();
        final finalChip = find.ancestor(
          of: finalLabel,
          matching: find.byType(InkWell),
        ).first;
        final finalRect = tester.getRect(finalChip);
        final currentRailRect = tester.getRect(rail);
        expect(finalRect.left, greaterThanOrEqualTo(currentRailRect.left));
        expect(finalRect.right, lessThanOrEqualTo(currentRailRect.right));

        await tester.tap(finalLabel);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('offers do not expose unknown backend statuses',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Provider<OfferRepository>.value(
          value: _FakeOffers(status: 'UNKNOWN_OFFER_STATE'),
          child: const OffersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('UNKNOWN_OFFER_STATE'), findsNothing);
  });

}