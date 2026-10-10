import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/category.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/marketplace_repository.dart';
import 'package:hope_mobile/core/opportunity/opportunity_agent_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/ui/copy.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/home/premium_home_feed.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

class _FakeOpportunityAgent implements OpportunityAgentRepository {
  @override
  Future<HopeOpportunityAgentState> getState() async =>
      const HopeOpportunityAgentState(
        profileCompleteness: HopeOpportunityAgentProfileCompleteness(score: 1),
        activity: HopeOpportunityAgentActivity(),
        actions: [
          HopeOpportunityAgentAction(
            type: 'FOLLOW_UP_APPLICATION',
            title: 'Review your next opportunity',
            reason: 'A recent match needs your attention.',
          ),
        ],
      );
}

class _AuthRepo implements AuthRepository {
  @override
  Future<AuthSession> loginWithGoogle(String _) => throw UnimplementedError();
  @override
  Future<AuthSession> login(String e, String p) => throw UnimplementedError();
  @override
  Future<AuthSession> register(String e, String p, String n) =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String e) async {}
}

class _SequencedMarketplaceRepository implements MarketplaceRepository {
  int calls = 0;
  final Completer<List<HopeJob>> staleRefresh =
      Completer<List<HopeJob>>();
  final initial = _job(
    'initial',
    'Initial opportunity',
    recommended: true,
  );
  final fresh = _job('fresh', 'Fresh opportunity');

  @override
  Future<List<HopeCategory>> listCategories() async => const [];

  @override
  Future<HopeJob> getOpportunity(String id) => Future.value(initial);

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
  }) {
    calls += 1;
    if (calls == 1) return Future.value([initial]);
    if (calls == 2) return staleRefresh.future;
    return Future.value([fresh]);
  }

  @override
  Future<HopeJob> createOpportunity(Map<String, dynamic> body) =>
      throw UnimplementedError();

  @override
  Future<void> publishOpportunity(String id) async {}
}

HopeJob _job(String id, String title, {bool recommended = false}) =>
    HopeJob.fromMap({
      'id': id,
      'title': title,
      'description': 'description',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'city': 'تهران',
      'status': 'PUBLISHED',
      'categoryId': 'tech',
      'category': 'فناوری',
      'isRecommended': recommended,
      'recommendationScore': recommended ? 92 : null,
      'recommendationReasons':
          recommended ? ['SKILL_MATCH'] : const <String>[],
    });

class _HomeHarness {
  const _HomeHarness(this.widget, this.settings);

  final Widget widget;
  final HopeSettingsController settings;
}

Future<_HomeHarness> _host(
  _SequencedMarketplaceRepository repository, {
  bool authenticated = false,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(_AuthRepo(), SecureStore());
  if (authenticated) {
    await auth.applyRefreshedUser({
      'id': 'u1',
      'displayName': 'Ali',
    });
  } else {
    auth.continueAsGuest();
  }
  return _HomeHarness(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          Provider<ApplicationRegistry>.value(
            value: ApplicationRegistry(
              marketplace: repository,
              opportunityAgent:
                  authenticated ? _FakeOpportunityAgent() : null,
            ),
          ),
        ],
        child: const PremiumHomeFeed(
          onOpenExplore: _noop,
          onOpenMenu: _noop,
          onOpenCreate: _noop,
        ),
      ),
    ),
    settings,
  );
}

void _noop() {}

void main() {
  testWidgets('home identity header is neutral rather than time-based',
      (tester) async {
    final harness = await _host(_SequencedMarketplaceRepository(), authenticated: true);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('Ali'), findsOneWidget);
    expect(find.text('Good evening, Ali'), findsNothing);
  });

  testWidgets('single recommendation does not reserve an empty matches section',
      (tester) async {
    final repository = _SequencedMarketplaceRepository();
    final harness = await _host(repository);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('Best match for you'), findsOneWidget);
    expect(find.text('Matches'), findsNothing);
  });

  testWidgets('settings changes reload home opportunities',
      (tester) async {
    final repository = _SequencedMarketplaceRepository();
    final harness = await _host(repository);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(repository.calls, 1);

    await harness.settings.setCity('مشهد');
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.calls, 2);
  });

  testWidgets(
      'home pulse uses a single horizontal scanline at wide widths',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 1.0;

    try {
      final repository = _SequencedMarketplaceRepository();
      final harness = await _host(repository);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final stats = [
        find.text('matches'),
        find.text('new'),
        find.text('active'),
        find.text('Held in escrow'),
      ];
      for (final stat in stats) {
        expect(stat, findsOneWidget);
      }

      final tops = stats
          .map((finder) => tester.getTopLeft(finder).dy)
          .toList(growable: false);
      expect(
        tops.every((top) => (top - tops.first).abs() < 1.0),
        isTrue,
      );
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'home pulse stays a quiet rail below the primary match on responsive widths',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1.0;

    try {
      final repository = _SequencedMarketplaceRepository();
      final harness = await _host(repository);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final pulse = find.ancestor(
        of: find.text('matches'),
        matching: find.byType(PremiumPanel),
      ).first;
      expect(tester.getSize(pulse).height, lessThanOrEqualTo(70));

      final bestMatch = find.text('Best match for you');
      expect(bestMatch, findsOneWidget);
      expect(
        tester.getTopLeft(bestMatch).dy,
        lessThan(tester.getTopLeft(find.text('matches')).dy),
      );
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'home pulse stays in one visual row at the 720x1280 responsive viewport',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1.0;

    try {
      final repository = _SequencedMarketplaceRepository();
      final harness = await _host(repository);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final stats = [
        find.text('matches'),
        find.text('new'),
        find.text('active'),
        find.text('Held in escrow'),
      ];
      final tops = stats
          .map((finder) => tester.getTopLeft(finder).dy)
          .toList(growable: false);

      expect(
        tops.every((top) => (top - tops.first).abs() < 1.0),
        isTrue,
      );
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });


  testWidgets(
    'Wave30 Home Pulse reflows into two readable rows at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _host(
        _SequencedMarketplaceRepository(),
        textScale: 1.5,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final keys = [
        'home-pulse-stat-matches',
        'home-pulse-stat-new',
        'home-pulse-stat-active',
        'home-pulse-stat-Held in escrow',
      ].map((key) => find.byKey(ValueKey(key))).toList(growable: false);
      for (final stat in keys) {
        expect(stat, findsOneWidget);
      }
      final rects = keys.map((finder) => tester.getRect(finder)).toList(growable: false);
      expect((rects[0].top - rects[1].top).abs(), lessThan(1.0));
      expect((rects[2].top - rects[3].top).abs(), lessThan(1.0));
      expect(rects[2].top, greaterThan(rects[0].top));
      expect(
        tester.getSize(find.byKey(const ValueKey('home-pulse-panel'))).height,
        greaterThan(70),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home money labels use the canonical Toman copy helper',
      (tester) async {
    final harness = await _host(_SequencedMarketplaceRepository());
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      moneyLabel(tester.element(find.byType(PremiumHomeFeed)), 125000),
      contains('125,000 TOMAN'),
    );
  });

  testWidgets(
    'home prioritizes matched work before intelligence follow-up',
    (tester) async {
      final repository = _SequencedMarketplaceRepository();
      final harness = await _host(repository, authenticated: true);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final bestMatch = find.text('Best match for you');
      final intelligence = find.byKey(
        const ValueKey('opportunity-agent-panel'),
      );

      expect(bestMatch, findsOneWidget);
      await tester.scrollUntilVisible(
        intelligence,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(intelligence, findsOneWidget);
      expect(
        tester.getTopLeft(bestMatch).dy,
        lessThan(tester.getTopLeft(intelligence).dy),
      );
    },
  );

  testWidgets('latest home refresh wins over an older failed refresh',
      (tester) async {
    final repository = _SequencedMarketplaceRepository();
    final harness = await _host(repository);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Initial opportunity'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Initial opportunity'), findsOneWidget);

    final refreshIndicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    unawaited(refreshIndicator.onRefresh());
    await tester.pump();
    expect(repository.calls, 2);

    final newerRefresh = refreshIndicator.onRefresh();
    await newerRefresh;
    await tester.pumpAndSettle();

    expect(repository.calls, 3);
    expect(find.text('Fresh opportunity'), findsOneWidget);

    repository.staleRefresh.completeError(StateError('stale refresh failed'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh opportunity'), findsOneWidget);
    expect(find.text('Opportunities are unavailable'), findsNothing);
  });
}
