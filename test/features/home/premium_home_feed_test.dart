import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/category.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/marketplace_repository.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/core/ui/hope_display_formatters.dart';
import 'package:hope_mobile/core/opportunity/opportunity_agent_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/ui/copy.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
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

class _FailOnceOpportunityAgent implements OpportunityAgentRepository {
  int calls = 0;
  final firstResponse = Completer<HopeOpportunityAgentState>();

  @override
  Future<HopeOpportunityAgentState> getState() {
    calls += 1;
    if (calls == 1) return firstResponse.future;
    return Future.value(const HopeOpportunityAgentState(
      profileCompleteness: HopeOpportunityAgentProfileCompleteness(score: 1),
      activity: HopeOpportunityAgentActivity(),
      actions: [
        HopeOpportunityAgentAction(
          type: 'REVIEW_OPPORTUNITY',
          title: 'Review the matched opportunity',
          reasons: ['SKILL_MATCH'],
        ),
      ],
    ));
  }

  void failInitialRequest() {
    firstResponse.completeError(
      StateError('opportunity agent temporarily unavailable'),
    );
  }
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
  _SequencedMarketplaceRepository({HopeJob? initial, HopeJob? fresh})
      : initial = initial ??
            _job(
              'initial',
              'Initial opportunity',
              recommended: true,
            ),
        fresh = fresh ?? _job('fresh', 'Fresh opportunity');

  int calls = 0;
  final Completer<List<HopeJob>> staleRefresh =
      Completer<List<HopeJob>>();
  final HopeJob initial;
  final HopeJob fresh;

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

class _FailingHomeOpportunitiesRepository extends _SequencedMarketplaceRepository {
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
    throw StateError('opportunities unavailable');
  }
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

class _LoadingMarketplaceRepository extends _SequencedMarketplaceRepository {
  final Completer<List<HopeJob>> pendingOpportunities =
      Completer<List<HopeJob>>();

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
  }) => pendingOpportunities.future;
}

const _wideGridLongTitle =
    'Senior product design lead responsible for editorial systems, accessible financial workflows, multilingual experience strategy, component governance, and cross-functional delivery';

class _WideGridMarketplaceRepository extends _SequencedMarketplaceRepository {
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
        HopeJob.fromMap({
          'id': 'wide-grid-a',
          'title': _wideGridLongTitle,
          'description': 'A short description.',
          'kind': 'MISSION',
          'visibility': 'PUBLIC',
          'city': 'تهران',
          'distanceKm': 1.0,
          'status': 'PUBLISHED',
          'categoryId': 'tech',
          'category': 'فناوری',
          'budgetMin': 1200000,
          'budgetMax': 2400000,
        }),
        HopeJob.fromMap({
          'id': 'wide-grid-b',
          'title': 'Product interface review',
          'description': 'A short description.',
          'kind': 'MISSION',
          'visibility': 'PUBLIC',
          'city': 'تهران',
          'distanceKm': 2.0,
          'status': 'PUBLISHED',
          'categoryId': 'tech',
          'category': 'فناوری',
          'budgetMin': 1500000,
          'budgetMax': 2600000,
        }),
        HopeJob.fromMap({
          'id': 'wide-grid-c',
          'title': 'Editorial visual design',
          'description': 'A short description.',
          'kind': 'MISSION',
          'visibility': 'PUBLIC',
          'city': 'تهران',
          'distanceKm': 3.0,
          'status': 'PUBLISHED',
          'categoryId': 'design',
          'category': 'طراحی',
          'budgetMin': 1800000,
          'budgetMax': 3000000,
        }),
      ];
}

class _ImmediateTransactions implements TransactionRepository {
  @override
  Future<List<HopeJob>> listMyJobs() async => const <HopeJob>[];

  @override
  Future<HopePayment> getPayment(String jobId) async => throw UnimplementedError();
  @override
  Future<HopePayment> fundPayment(String jobId, {String? idempotencyKey}) async => throw UnimplementedError();
  @override
  Future<HopePayment> refundPayment(String jobId) async => throw UnimplementedError();
  @override
  Future<HopePayment> releasePayment(String jobId) async => throw UnimplementedError();
  @override
  Future<HopeJob> startJob(String jobId) async => throw UnimplementedError();
  @override
  Future<HopeJob> deliverJob(String jobId) async => throw UnimplementedError();
  @override
  Future<HopeJob> acceptJob(String jobId) async => throw UnimplementedError();
  @override
  Future<void> submitEvidence(String jobId, {required String uri, required String notes, required String type}) async => throw UnimplementedError();
}

class _FailOnceActiveJobsTransactions extends _ImmediateTransactions {
  int listCalls = 0;

  @override
  Future<List<HopeJob>> listMyJobs() async {
    listCalls += 1;
    if (listCalls == 1) {
      throw StateError('active work unavailable');
    }
    return const <HopeJob>[];
  }
}

class _DelayedWalletRepository implements WalletRepository {
  final requests = <Completer<HopeWallet>>[];

  @override
  Future<HopeWallet> getWallet() {
    final gate = Completer<HopeWallet>();
    requests.add(gate);
    return gate.future;
  }

  @override
  Future<WalletTransactionsPage> listTransactions({int limit = 30, String? cursor}) async => throw UnimplementedError();
  @override
  Future<List<HopePayout>> listPayouts() async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> transfer({required String destinationWalletId, required int amount, required String idempotencyKey}) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> requestPayout({required int amount, required String idempotencyKey}) async => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> topUp({required int amount, required String idempotencyKey}) async => throw UnimplementedError();
}
class _HomeHarness {
  const _HomeHarness(this.widget, this.settings);

  final Widget widget;
  final HopeSettingsController settings;
}

Future<_HomeHarness> _host(
  _SequencedMarketplaceRepository repository, {
  bool authenticated = false,
  double textScale = 1,
  String locale = 'en',
  TransactionRepository? transactions,
  WalletRepository? wallets,
  OpportunityAgentRepository? agentRepository,
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
      locale: Locale(locale),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (textScale <= 1) return child!;
        final media = MediaQueryData.fromView(View.of(context));
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
              transactions: transactions,
              wallets: wallets,
              opportunityAgent: authenticated
                  ? (agentRepository ?? _FakeOpportunityAgent())
                  : null,
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

  testWidgets(
    'Home exposes retry when Opportunity Agent fails to load',
    (tester) async {
      final agent = _FailOnceOpportunityAgent();
      final harness = await _host(
        _SequencedMarketplaceRepository(),
        authenticated: true,
        agentRepository: agent,
      );

      await tester.pumpWidget(harness.widget);
      await tester.pump();
      // Complete the rejected Future only after FutureBuilder has subscribed.
      agent.failInitialRequest();
      await tester.pumpAndSettle();

      expect(agent.calls, 1);
      expect(find.text('Smart suggestions are temporarily unavailable'), findsOneWidget);
      final retry = find.byKey(const ValueKey('home-opportunity-agent-retry'));
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();

      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(agent.calls, 2);
      expect(find.text('Smart suggestions are temporarily unavailable'), findsNothing);
      expect(find.text('Review the matched opportunity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home distinguishes active-work load failure and retries it',
    (tester) async {
      final transactions = _FailOnceActiveJobsTransactions();
      final wallets = _DelayedWalletRepository();
      final harness = await _host(
        _SequencedMarketplaceRepository(),
        authenticated: true,
        transactions: transactions,
        wallets: wallets,
      );

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(transactions.listCalls, 1);
      expect(find.text('Active work is temporarily unavailable'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-active-work-retry')), findsOneWidget);

      final retry = find.byKey(const ValueKey('home-active-work-retry'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      // The Home feed contains animated loading surfaces during refresh.
      // Advance finite frames rather than requiring every animation to settle.
      expect(transactions.listCalls, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('Active work is temporarily unavailable'), findsNothing);
      expect(find.byKey(const ValueKey('home-active-work-retry')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home Pulse does not report zero matches when opportunities fail to load',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _host(
        _FailingHomeOpportunitiesRepository(),
        locale: 'en',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Opportunities are unavailable'), findsOneWidget);
      final matches = find.byKey(
        const ValueKey('home-pulse-stat-matches'),
      );
      expect(matches, findsOneWidget);
      final texts = tester
          .widgetList<Text>(find.descendant(of: matches, matching: find.byType(Text)))
          .map((widget) => widget.data ?? '')
          .toList();
      expect(texts, contains('—'));
      expect(texts, isNot(contains('0')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home overview heading does not duplicate the featured match section',
    (tester) async {
      final harness = await _host(_SequencedMarketplaceRepository());
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(find.text('Your HOPE overview'), findsOneWidget);
      expect(find.text('Opportunities matched to your path'), findsNothing);
      expect(find.text('Best match for you'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('single recommendation does not reserve an empty matches section',
      (tester) async {
    final repository = _SequencedMarketplaceRepository();
    final harness = await _host(repository);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(find.text('Best match for you'), findsOneWidget);
    expect(find.text('Matches'), findsNothing);
  });

  testWidgets(
    'compact home loading follows width-based density on a tall phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _LoadingMarketplaceRepository();
      final harness = await _host(repository);
      await tester.pumpWidget(harness.widget);
      await tester.pump();

      final skeleton = find.byType(OpportunitySkeletonCard);
      expect(
        skeleton,
        findsOneWidget,
        reason: 'A compact phone should reserve one primary opportunity skeleton, not two full cards.',
      );
      expect(
        tester.getSize(skeleton).height,
        lessThanOrEqualTo(200),
        reason: 'The loading placeholder must respect the compact featured-card height budget.',
      );

      final cardRect = tester.getRect(skeleton);
      final viewportRect = tester.getRect(find.byType(ListView).first);
      expect(cardRect.top, greaterThanOrEqualTo(viewportRect.top));
      expect(
        cardRect.bottom,
        lessThanOrEqualTo(viewportRect.bottom),
        reason: 'The compact loading card should not overflow the initial viewport.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide Home opportunity titles remain complete at 1.5x system text',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _host(
        _WideGridMarketplaceRepository(),
        textScale: 1.5,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final title = find.text(_wideGridLongTitle);
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Wide Home compact-grid cards must wrap long titles instead of truncating them when system text is enlarged.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact Home opportunity titles remain complete at 1.5x system text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _host(
        _WideGridMarketplaceRepository(),
        textScale: 1.5,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final title = find.text(_wideGridLongTitle);
      await tester.scrollUntilVisible(
        title,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Compact Home summaries must wrap the full opportunity title at enlarged text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide Home opportunity cards size to content instead of square grid cells',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _host(_WideGridMarketplaceRepository());
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final cards = find.byType(OpportunityCard);
      expect(cards, findsNWidgets(3));
      for (var index = 0; index < 3; index++) {
        expect(
          tester.getSize(cards.at(index)).height,
          lessThanOrEqualTo(320),
          reason: 'Wide Home opportunity cards should not reserve a square fixed-height cell when their content is short.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact home fold prioritizes the featured opportunity before the pulse',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _host(_SequencedMarketplaceRepository());
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame).first).padding.bottom,
      12,
      reason: 'The home ListView already owns navigation-aware end padding; its outer frame should not reserve another dead band.',
    );
    final pulse = find.byKey(const ValueKey('home-pulse-panel'));
    final featured = find.text('Best match for you');
    expect(pulse, findsOneWidget);
    expect(featured, findsOneWidget);
    expect(tester.getTopLeft(featured).dy, lessThan(tester.getTopLeft(pulse).dy));

    final featuredCards = find.byType(OpportunityCard);
    expect(featuredCards, findsWidgets);
    final featuredRect = tester.getRect(featuredCards.first);
    final homeViewport = tester.getRect(find.byType(ListView).first);
    expect(featuredRect.top, greaterThanOrEqualTo(homeViewport.top));
    expect(
      featuredRect.bottom,
      lessThanOrEqualTo(homeViewport.bottom),
      reason: 'The primary featured opportunity must fit in the first compact viewport.',
    );

    final compactPulse = find.byKey(const ValueKey('home-pulse-compact-strip'));
    expect(compactPulse, findsOneWidget);
    expect(tester.getSize(compactPulse).height, lessThanOrEqualTo(64));
    final metrics = find.byKey(const ValueKey('home-pulse-compact-metrics'));
    expect(metrics, findsOneWidget);
    final metricsRect = tester.getRect(metrics);
    final chipRects = <Rect>[];
    for (var index = 0; index < 4; index++) {
      final chip = find.byKey(ValueKey('home-pulse-compact-metric-$index'));
      expect(chip, findsOneWidget);
      final rect = tester.getRect(chip);
      chipRects.add(rect);
      expect(rect.left, greaterThanOrEqualTo(metricsRect.left));
      expect(rect.right, lessThanOrEqualTo(metricsRect.right));
      expect(rect.height, lessThanOrEqualTo(32));
    }
    expect(
      chipRects.map((rect) => rect.top.round()).toSet().length,
      2,
      reason: 'Compact Pulse should arrange its four complete metrics in two rows.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact fa-RTL Home keeps every featured tag inside the visible rail',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final featured = HopeJob.fromMap({
        'id': 'compact-home-match-rail',
        'title': 'طراحی رابط موبایل حرفه‌ای',
        'description': 'Responsive match-score rail fixture.',
        'kind': 'MISSION',
        'visibility': 'PUBLIC',
        'status': 'PUBLISHED',
        'categoryId': 'software',
        'category': 'نرم افزار',
        'isRecommended': true,
        'recommendationScore': 0.94,
        'recommendationReasons': const <String>[],
        'budgetMin': '15000000',
        'budgetMax': '25000000',
        'city': 'تهران',
      });
      final harness = await _host(
        _SequencedMarketplaceRepository(initial: featured),
        locale: 'fa',
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final rail = find.byKey(
        const ValueKey('opportunity-featured-scan-tag-rail'),
      );
      expect(rail, findsOneWidget);
      final tags = find.descendant(
        of: rail,
        matching: find.byType(PremiumTag),
      );
      expect(tags, findsNWidgets(3));
      expect(
        tester.widgetList<PremiumTag>(tags).map((tag) => tag.label),
        contains('۹۴٪ تطابق'),
      );

      final railRect = tester.getRect(rail);
      for (var index = 0; index < tags.evaluate().length; index++) {
        final tagRect = tester.getRect(tags.at(index));
        expect(
          tagRect.left,
          greaterThanOrEqualTo(railRect.left),
          reason:
              'Featured tag $index must not be clipped at the rail left edge.',
        );
        expect(
          tagRect.right,
          lessThanOrEqualTo(railRect.right),
          reason:
              'Featured tag $index must not be clipped at the rail right edge.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late wallet result from an old Home load cannot overwrite the newest refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final marketplace = _SequencedMarketplaceRepository();
      final wallets = _DelayedWalletRepository();
      final harness = await _host(
        marketplace,
        authenticated: true,
        transactions: _ImmediateTransactions(),
        wallets: wallets,
      );
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      expect(wallets.requests, hasLength(1));

      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final refreshFuture = refresh.onRefresh();
      await tester.pump();
      expect(wallets.requests, hasLength(2));

      wallets.requests[1].complete(HopeWallet(
        id: 'wallet-new',
        userId: 'u1',
        currency: 'TOMAN',
        availableBalance: 0,
        lockedBalance: 0,
        status: 'ACTIVE',
        escrowBalance: 5555,
      ));
      marketplace.staleRefresh.complete([marketplace.fresh]);
      await refreshFuture;
      await tester.pumpAndSettle();

      final metric =
          find.byKey(const ValueKey('home-pulse-stat-Held in escrow'));
      expect(metric, findsOneWidget);
      final latestBalance = HopeDisplayFormatter.money(5555, locale: 'en');
      final oldBalance = HopeDisplayFormatter.money(1111, locale: 'en');
      final visibleMetricText = tester
          .widgetList<Text>(
            find.descendant(of: metric, matching: find.byType(Text)),
          )
          .map((widget) => widget.data ?? '')
          .toList();
      expect(
        visibleMetricText,
        contains(latestBalance),
        reason: 'Current metric texts: ${visibleMetricText.join(' | ')}',
      );

      wallets.requests[0].complete(HopeWallet(
        id: 'wallet-old',
        userId: 'u1',
        currency: 'TOMAN',
        availableBalance: 0,
        lockedBalance: 0,
        status: 'ACTIVE',
        escrowBalance: 1111,
      ));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: metric, matching: find.text(latestBalance)),
        findsOneWidget,
        reason: 'A stale wallet response must not replace the newest snapshot.',
      );
      expect(
        find.descendant(of: metric, matching: find.text(oldBalance)),
        findsNothing,
      );
    },
  );

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
      'home pulse stays a quiet rail before the primary match on responsive widths',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1.0;

    try {
      final repository = _SequencedMarketplaceRepository();
      final harness = await _host(repository);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      final pulse = find.byKey(const ValueKey('home-pulse-panel'));
      final pulseSize = tester.getSize(pulse);
      final statGridWidth = tester.getSize(
        find.byKey(const ValueKey('home-pulse-stat-grid')),
      ).width;
      final expectedMaximumHeight = statGridWidth >= 800 ? 70.0 : 140.0;
      expect(pulseSize.height, lessThanOrEqualTo(expectedMaximumHeight));

      final bestMatch = find.text('Best match for you');
      expect(bestMatch, findsOneWidget);
      expect(
        tester.getTopLeft(pulse).dy,
        lessThan(tester.getTopLeft(bestMatch).dy),
      );
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets(
      'home pulse adapts its metric rows to the actual responsive rail width at 720x1280',
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
      final gridWidth = tester.getSize(
        find.byKey(const ValueKey('home-pulse-stat-grid')),
      ).width;

      if (gridWidth >= 800) {
        expect(tops.every((top) => (top - tops.first).abs() < 1.0), isTrue);
      } else {
        expect((tops[0] - tops[1]).abs(), lessThan(1.0));
        expect((tops[2] - tops[3]).abs(), lessThan(1.0));
        expect(tops[2], greaterThan(tops[0]));
      }
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

      final opportunityCards = tester.widgetList<OpportunityCard>(
        find.byType(OpportunityCard),
      );
      expect(
        opportunityCards.any(
          (card) => card.variant == OpportunityCardVariant.featured,
        ),
        isTrue,
        reason: 'At 1.5x text scale, the proven featured layout must replace the compressed first-fold scan card.',
      );

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

  testWidgets('home money labels localize Persian digits and grouping in fa-RTL',
      (tester) async {
    final harness = await _host(
      _SequencedMarketplaceRepository(),
      locale: 'fa',
    );
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      moneyLabel(tester.element(find.byType(PremiumHomeFeed)), 125000),
      contains('۱۲۵٬۰۰۰'),
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
