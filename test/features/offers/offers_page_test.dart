import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/offer_repository.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/offers/offers_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
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
  jobTitle: id,
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


class _FixedOfferRepository implements OfferRepository {
  _FixedOfferRepository(this.offers);

  final List<HopeOffer> offers;

  @override
  Future<List<HopeOffer>> listMine() async => offers;

  @override
  Future<List<HopeOffer>> listForJob(String jobId) async => offers;

  @override
  Future<HopeOffer> get(String offerId) async =>
      offers.firstWhere((offer) => offer.id == offerId);

  @override
  Future<HopeOffer> submit(
    String jobId, {
    required String price,
    String message = '',
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> accept(String offerId) =>
      throw UnimplementedError();
}

class _PendingOfferRepository extends _FixedOfferRepository {
  _PendingOfferRepository() : super(const []);

  final Completer<List<HopeOffer>> initialLoad = Completer<List<HopeOffer>>();

  @override
  Future<List<HopeOffer>> listMine() => initialLoad.future;

  @override
  Future<List<HopeOffer>> listForJob(String jobId) => initialLoad.future;
}

class _InitialFailureOfferRepository extends _FixedOfferRepository {
  _InitialFailureOfferRepository() : super(const []);

  @override
  Future<List<HopeOffer>> listMine() =>
      Future<List<HopeOffer>>.error(StateError('offers unavailable'));

  @override
  Future<List<HopeOffer>> listForJob(String jobId) =>
      Future<List<HopeOffer>>.error(StateError('offers unavailable'));
}

Widget _host(
  OfferRepository repository, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('fa'), Locale('en')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
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
  testWidgets(
    'Wave49 Offers card title and status fit FA-RTL/EN-LTR responsive matrix',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const title =
          'A very detailed collaboration opportunity title that must stay readable at narrow widths';
      final offer = HopeOffer(
        id: 'responsive-offer',
        jobId: 'job-1',
        providerId: 'provider-1',
        price: '2500000',
        message: 'A real test-fixture offer message.',
        status: 'PENDING',
        createdAt: null,
        updatedAt: null,
        jobTitle: title,
      );
      const widths = [320.0, 360.0, 390.0, 600.0, 900.0, 1200.0];
      const locales = [Locale('fa'), Locale('en')];

      for (final locale in locales) {
        for (final width in widths) {
          final scales = width <= 360 ? [1.0, 1.5] : [1.0];
          for (final scale in scales) {
            tester.view.physicalSize = Size(width, 800);
            await tester.pumpWidget(
              _host(
                _FixedOfferRepository([offer]),
                locale: locale,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
              24,
              reason: 'Offers must not reserve a second oversized tail outside the scroll view.',
            );
            final titleFinder = find.byKey(
              const ValueKey('offer-title-responsive-offer'),
            );
            final statusFinder = find.byKey(
              const ValueKey('offer-status-responsive-offer'),
            );
            expect(titleFinder, findsOneWidget);
            expect(statusFinder, findsOneWidget);
            final titleRect = tester.getRect(titleFinder);
            final statusRect = tester.getRect(statusFinder);
            expect(titleRect.left, greaterThanOrEqualTo(0));
            expect(titleRect.right, lessThanOrEqualTo(width));
            expect(statusRect.left, greaterThanOrEqualTo(0));
            expect(statusRect.right, lessThanOrEqualTo(width));
            if (width < 380 || scale > 1.2) {
              expect(
                statusRect.top,
                greaterThan(titleRect.bottom - 1),
                reason: 'Offer status should stack below title at ${locale.languageCode}, ${width}dp, ${scale}x.',
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: 'Unexpected layout exception at ${locale.languageCode}, ${width}dp, ${scale}x.',
            );
          }
        }
      }
    },
  );

testWidgets(
  'offer message avoids ellipsis at 1.5x on a compact viewport',
  (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final message = List.filled(
      10,
      'Every milestone includes a clear deliverable, review window, and acceptance criteria.',
    ).join(' ');
    final offer = HopeOffer(
      id: 'long-message-offer',
      jobId: 'job-1',
      providerId: 'provider-1',
      price: '2500000',
      message: message,
      status: 'PENDING',
      createdAt: null,
      updatedAt: null,
      jobTitle: 'Compact offer',
    );

    await tester.pumpWidget(
      _host(
        _FixedOfferRepository([offer]),
        locale: const Locale('en'),
        textScale: 1.5,
      ),
    );
    await tester.pumpAndSettle();

    final messageFinder = find.text(message);
    expect(messageFinder, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(messageFinder);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'The full offer message must stay readable when system text is enlarged on a compact viewport.',
    );
    expect(tester.takeException(), isNull);
  },
);

testWidgets(
  'Wave46 offers loading and empty states remain mutually exclusive',
  (tester) async {
    final repository = _PendingOfferRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pump();

    expect(find.text('Loading offers'), findsOneWidget);
    expect(find.text('No offers'), findsNothing);
    expect(find.byKey(const ValueKey('offers-status-filter-scroll')), findsNothing);

    repository.initialLoad.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('Loading offers'), findsNothing);
    expect(find.text('No offers'), findsOneWidget);
    expect(find.text('All (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  },
);

testWidgets(
  'Wave46 offers initial failure shows retry without false empty or zero-count filters',
  (tester) async {
    await tester.pumpWidget(_host(_InitialFailureOfferRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Offers unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No offers'), findsNothing);
    expect(find.text('All (0)'), findsNothing);
    expect(find.byKey(const ValueKey('offers-status-filter-scroll')), findsNothing);
    expect(tester.takeException(), isNull);
  },
);

testWidgets('accepting an offer disables the financial action until completion',
      (tester) async {
    final repository = _AcceptGuardOfferRepository();
    await tester.pumpWidget(_hostWithJob(repository));
    await tester.pumpAndSettle();

    final acceptButton = find.widgetWithText(FilledButton, 'Accept offer');
    expect(acceptButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(acceptButton).style?.backgroundColor?.resolve({}),
      HopeV2Colors.markedPrimaryActionDarkGreen,
    );

    await tester.tap(acceptButton);
    await tester.pump();
    final confirmation = find.byType(AlertDialog);
    expect(
      find.descendant(of: confirmation, matching: find.text('pending')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: confirmation, matching: find.text('Offer amount')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: confirmation, matching: find.text('2,500,000 TOMAN')),
      findsOneWidget,
    );
    final amount = tester.widget<Text>(
      find.descendant(of: confirmation, matching: find.text('2,500,000 TOMAN')),
    );
    expect(amount.style?.color, HopeV2Colors.moneyTextLight,
        reason: 'Readable offer amounts must use the neutral financial text role.');
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

    final refresh = find.byTooltip('Refresh');
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pump();
    expect(repository.calls, 2);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(repository.calls, 3);
    expect(find.text('fresh'), findsOneWidget);

    repository.staleRefresh.complete([repository.stale]);
    await tester.pumpAndSettle();

    expect(find.text('fresh'), findsOneWidget);
    expect(find.text('stale'), findsNothing);
  });

  testWidgets('offer refresh failure preserves existing rows and shows retry state', (tester) async {
    final repository = _RefreshFailureOfferRepository();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.text('existing'), findsOneWidget);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('existing'), findsOneWidget);
    expect(find.text('Offers unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'offer status rail keeps every filter fully reachable in RTL/LTR and enlarged text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const scenarios = [
        (locale: Locale('en'), width: 320.0, textScale: 1.0),
        (locale: Locale('fa'), width: 320.0, textScale: 1.0),
        (locale: Locale('en'), width: 360.0, textScale: 1.5),
        (locale: Locale('fa'), width: 360.0, textScale: 1.5),
      ];
      for (final scenario in scenarios) {
        tester.view.physicalSize = Size(scenario.width, 640);
        await tester.pumpWidget(
          _host(
            _SequencedOfferRepository(),
            locale: scenario.locale,
            textScale: scenario.textScale,
          ),
        );
        await tester.pumpAndSettle();

        final rail = find.byKey(
          const ValueKey('offers-status-filter-scroll'),
        );
        expect(rail, findsOneWidget);
        expect(
          tester.widget<SingleChildScrollView>(rail).scrollDirection,
          Axis.horizontal,
        );
        final scrollbar = find.ancestor(
          of: rail,
          matching: find.byType(Scrollbar),
        );
        expect(scrollbar, findsOneWidget);
        expect(tester.widget<Scrollbar>(scrollbar).thumbVisibility, isTrue);
        final railBounds = tester.getRect(rail);
        expect(
          railBounds.height,
          lessThan(64),
          reason: 'The status filters should stay in one compact horizontal rail.',
        );

        final prefixes = scenario.locale.languageCode == 'en'
            ? const ['All (', 'Pending (', 'Accepted (', 'Rejected (']
            : const ['همه (', 'در انتظار بررسی (', 'پذیرفته‌شده (', 'رد شده ('];

        final leadingChip = find.ancestor(
          of: find.textContaining(prefixes.first),
          matching: find.byType(PremiumFilterChip),
        );
        expect(leadingChip, findsOneWidget);
        expect(
          tester.widget<PremiumFilterChip>(leadingChip).selected,
          isTrue,
          reason: 'The logical leading All filter remains active in both directions.',
        );
        final leadingBounds = tester.getRect(leadingChip);
        final isRtl = scenario.locale.languageCode == 'fa';
        expect(leadingBounds.left, greaterThanOrEqualTo(railBounds.left));
        expect(leadingBounds.right, lessThanOrEqualTo(railBounds.right));
        if (isRtl) {
          expect(
            leadingBounds.right,
            lessThanOrEqualTo(railBounds.right - 12),
            reason: 'The RTL leading filter must have at least 12dp breathing room from the right viewport edge.',
          );
        } else {
          expect(
            leadingBounds.left,
            greaterThanOrEqualTo(railBounds.left + 12),
            reason: 'The LTR leading filter must have at least 12dp breathing room from the left viewport edge.',
          );
        }

        expect(
          Directionality.of(tester.element(rail)),
          isRtl ? TextDirection.rtl : TextDirection.ltr,
          reason: 'The status rail must inherit the requested locale direction.',
        );

        if (isRtl) {
          expect(
            find.byKey(const ValueKey('offers-status-filter-scroll-cue')),
            findsOneWidget,
            reason: 'The compact Persian status rail must disclose its horizontal scroll affordance.',
          );
          expect(
            find.text('برای دیدن فیلترهای دیگر، افقی بکشید'),
            findsOneWidget,
            reason: 'The Persian horizontal-scroll cue must be localized and visible.',
          );
        }

        for (final prefix in prefixes) {
          final filterLabel = find.textContaining(prefix);
          expect(filterLabel, findsOneWidget);
          final chip = find.ancestor(
            of: filterLabel,
            matching: find.byType(PremiumFilterChip),
          );
          expect(chip, findsOneWidget);
          expect(
            tester.getSize(chip).height,
            greaterThanOrEqualTo(48),
            reason: 'Every status chip needs a rendered 48dp touch target.',
          );
        }

        final railScrollable = find.descendant(
          of: rail,
          matching: find.byType(Scrollable),
        ).first;
        final scrollPosition =
            tester.state<ScrollableState>(railScrollable).position;
        expect(
          scrollPosition.maxScrollExtent,
          greaterThan(0),
          reason: 'The narrow status rail must retain genuine horizontal scroll extent.',
        );
        await tester.drag(rail, Offset(isRtl ? 400 : -400, 0));
        await tester.pumpAndSettle();
        expect(
          scrollPosition.pixels,
          greaterThan(0),
          reason: 'A real horizontal swipe must move the Offers rail in both RTL and LTR.',
        );

        final terminalChip = find.ancestor(
          of: find.textContaining(prefixes.last),
          matching: find.byType(PremiumFilterChip),
        );
        bool terminalFilterFullyVisible() {
          final chipBounds = tester.getRect(terminalChip);
          final viewportBounds = tester.getRect(rail);
          return chipBounds.left >= viewportBounds.left &&
              chipBounds.right <= viewportBounds.right;
        }

        for (var attempt = 0;
            attempt < 6 && !terminalFilterFullyVisible();
            attempt++) {
          await tester.drag(rail, Offset(isRtl ? 180 : -180, 0));
          await tester.pumpAndSettle();
        }
        expect(
          terminalFilterFullyVisible(),
          isTrue,
          reason: 'Repeated physical swipes must bring the final Offers filter fully into view.',
        );
        final terminalBounds = tester.getRect(terminalChip);
        final endRailBounds = tester.getRect(rail);
        expect(
          terminalBounds.left,
          greaterThanOrEqualTo(endRailBounds.left),
          reason: 'The final status chip must be fully reachable at the end of the rail.',
        );
        expect(
          terminalBounds.right,
          lessThanOrEqualTo(endRailBounds.right),
          reason: 'The final status chip must be fully reachable at the end of the rail.',
        );
        if (isRtl) {
          expect(
            terminalBounds.left,
            greaterThanOrEqualTo(endRailBounds.left + 12),
            reason: 'The RTL terminal filter must have at least 12dp breathing room from the left viewport edge.',
          );
        } else {
          expect(
            terminalBounds.right,
            lessThanOrEqualTo(endRailBounds.right - 12),
            reason: 'The LTR terminal filter must have at least 12dp breathing room from the right viewport edge.',
          );
        }
        await tester.tap(terminalChip);
        await tester.pumpAndSettle();
        expect(
          tester.widget<PremiumFilterChip>(terminalChip).selected,
          isTrue,
          reason: 'The final status filter must be tappable and reflect its selected state after a real swipe.',
        );
        bool leadingFilterFullyVisible() {
          final chipBounds = tester.getRect(leadingChip);
          final viewportBounds = tester.getRect(rail);
          return chipBounds.left >= viewportBounds.left &&
              chipBounds.right <= viewportBounds.right;
        }

        for (var attempt = 0;
            attempt < 6 && !leadingFilterFullyVisible();
            attempt++) {
          await tester.drag(rail, Offset(isRtl ? -180 : 180, 0));
          await tester.pumpAndSettle();
        }
        expect(
          leadingFilterFullyVisible(),
          isTrue,
          reason: 'A reverse physical swipe must restore the leading Offers filter fully into view.',
        );
        final restoredLeadingBounds = tester.getRect(leadingChip);
        final restoredRailBounds = tester.getRect(rail);
        expect(
          restoredLeadingBounds.left,
          greaterThanOrEqualTo(restoredRailBounds.left),
          reason: 'A reverse swipe must return the first filter fully into view.',
        );
        expect(
          restoredLeadingBounds.right,
          lessThanOrEqualTo(restoredRailBounds.right),
          reason: 'A reverse swipe must return the first filter fully into view.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'offer details use a localized date and never show the internal job id',
    (tester) async {
      const rawCreatedAt = '2020-01-02T03:04:05.000Z';
      const internalJobId = 'job-internal-uuid-should-not-render';
      const publicTitle = 'Senior Flutter Engineer';
      final offer = HopeOffer(
        id: 'offer-details-1',
        jobId: internalJobId,
        providerId: 'provider-1',
        price: '2500000',
        message: 'Offer message',
        status: 'PENDING',
        createdAt: rawCreatedAt,
        updatedAt: null,
        jobTitle: publicTitle,
      );
      final repository = _FixedOfferRepository([offer]);

      await tester.pumpWidget(_host(repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text(publicTitle).first);
      await tester.pumpAndSettle();

      expect(find.text('Offer details'), findsOneWidget);
      final bottomSheet = find.byType(BottomSheet);
      expect(bottomSheet, findsOneWidget);
      expect(
        find.descendant(of: bottomSheet, matching: find.text(publicTitle)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomSheet, matching: find.text('Jan 2, 2020')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bottomSheet, matching: find.text(rawCreatedAt)),
        findsNothing,
      );
      expect(
        find.descendant(of: bottomSheet, matching: find.text(internalJobId)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offer details remain scrollable without overflow at 1.5x on a compact viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final message = List.filled(
        16,
        'Each delivery includes a documented outcome, review window, acceptance conditions, and a clear handoff.',
      ).join(' ');
      final offer = HopeOffer(
        id: 'long-details-offer',
        jobId: 'job-1',
        providerId: 'provider-1',
        price: '2500000',
        message: message,
        status: 'PENDING',
        createdAt: '2020-01-02T03:04:05.000Z',
        updatedAt: null,
        jobTitle: 'A detailed collaboration offer',
      );

      await tester.pumpWidget(
        _host(
          _FixedOfferRepository([offer]),
          locale: const Locale('en'),
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('A detailed collaboration offer').first);
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final detailScroll = find.descendant(
        of: sheet,
        matching: find.byType(SingleChildScrollView),
      );
      expect(
        detailScroll,
        findsOneWidget,
        reason: 'Long offer details must scroll within the sheet on a short viewport.',
      );

      final messageFinder = find.descendant(
        of: sheet,
        matching: find.text(message),
      );
      expect(messageFinder, findsOneWidget);
      await tester.scrollUntilVisible(
        messageFinder,
        120,
        scrollable: find.descendant(
          of: sheet,
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offers empty state is explicit when repository returns zero rows',
      (tester) async {
    final repository = _FixedOfferRepository(const []);
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.text('No offers'), findsOneWidget);
    expect(find.text('All (0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers filter isolates each status within a multi-row result',
      (tester) async {
    final repository = _FixedOfferRepository([
      _offer(id: 'pending-offer', status: 'PENDING'),
      _offer(id: 'accepted-offer', status: 'ACCEPTED'),
      _offer(id: 'rejected-offer', status: 'REJECTED'),
    ]);
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    // The page uses a lazily built ListView. Do not require off-screen cards
    // to exist in the widget tree before scrolling; the total and status
    // counts are derived from the complete repository result.
    expect(find.text('3 offers'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Pending (1)'), findsOneWidget);
    expect(find.text('Accepted (1)'), findsOneWidget);
    expect(find.text('Rejected (1)'), findsOneWidget);

    await tester.tap(find.text('Accepted (1)'));
    await tester.pumpAndSettle();
    expect(find.text('accepted-offer'), findsOneWidget);
    expect(find.text('pending-offer'), findsNothing);
    expect(find.text('rejected-offer'), findsNothing);
    // This header intentionally reports the total loaded records, not the
    // currently filtered subset.
    expect(find.text('3 offers'), findsOneWidget);

    await tester.tap(find.text('Rejected (1)'));
    await tester.pumpAndSettle();
    expect(find.text('rejected-offer'), findsOneWidget);
    expect(find.text('pending-offer'), findsNothing);
    expect(find.text('accepted-offer'), findsNothing);

    await tester.tap(find.text('Pending (1)'));
    await tester.pumpAndSettle();
    expect(find.text('pending-offer'), findsOneWidget);
    expect(find.text('accepted-offer'), findsNothing);
    expect(find.text('rejected-offer'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Offers horizontal scrollbar ignores the system bottom inset',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(
        _host(
          _FixedOfferRepository([
            _offer(id: 'pending-offer', status: 'PENDING'),
            _offer(id: 'accepted-offer', status: 'ACCEPTED'),
            _offer(id: 'rejected-offer', status: 'REJECTED'),
          ]),
          locale: const Locale('fa'),
        ),
      );
      await tester.pumpAndSettle();

      final rail = find.byKey(
        const ValueKey('offers-status-filter-scroll'),
      );
      expect(rail, findsOneWidget);
      final scrollbar = find.ancestor(
        of: rail,
        matching: find.byType(Scrollbar),
      );
      expect(scrollbar, findsOneWidget);
      expect(
        MediaQuery.paddingOf(tester.element(scrollbar)).bottom,
        0,
        reason: 'System bottom padding must not offset the horizontal thumb into the chip rail.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offers status filters remain a single horizontal rail on compact viewports',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          _FixedOfferRepository([
            _offer(id: 'pending-offer', status: 'PENDING'),
            _offer(id: 'accepted-offer', status: 'ACCEPTED'),
            _offer(id: 'rejected-offer', status: 'REJECTED'),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      final rail = find.byKey(
        const ValueKey('offers-status-filter-scroll'),
      );
      expect(rail, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(rail).scrollDirection,
        Axis.horizontal,
      );
      expect(
        tester.getSize(rail).height,
        lessThan(64),
        reason: 'Status filters must not consume a second wrapping row above offers.',
      );

      for (final label in [
        'All (3)',
        'Pending (1)',
        'Accepted (1)',
        'Rejected (1)',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.ensureVisible(find.text('Rejected (1)'));
      await tester.pumpAndSettle();
      final rejectedBounds = tester.getRect(find.text('Rejected (1)'));
      expect(rejectedBounds.left, greaterThanOrEqualTo(0));
      expect(rejectedBounds.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    },
  );

}
