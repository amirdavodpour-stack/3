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
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/features/home/premium_home_feed.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

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
  final initial = _job('initial', 'Initial opportunity');
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

HopeJob _job(String id, String title) => HopeJob.fromMap({
  'id': id,
  'title': title,
  'description': 'description',
  'kind': 'MISSION',
  'visibility': 'PUBLIC',
  'city': 'تهران',
  'status': 'PUBLISHED',
  'categoryId': 'tech',
  'category': 'فناوری',
});

class _HomeHarness {
  const _HomeHarness(this.widget, this.settings);

  final Widget widget;
  final HopeSettingsController settings;
}

Future<_HomeHarness> _host(
    _SequencedMarketplaceRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(_AuthRepo(), SecureStore());
  auth.continueAsGuest();
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
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          Provider<ApplicationRegistry>.value(
            value: ApplicationRegistry(marketplace: repository),
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

  testWidgets('latest home refresh wins over an older failed refresh',
      (tester) async {
    final repository = _SequencedMarketplaceRepository();
    final harness = await _host(repository);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Initial opportunity'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Initial opportunity'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Refresh'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.bySemanticsLabel('Refresh'));
    await tester.pump();
    expect(repository.calls, 2);

    await tester.tap(find.bySemanticsLabel('Refresh'));
    await tester.pumpAndSettle();

    expect(repository.calls, 3);
    expect(find.text('Fresh opportunity'), findsOneWidget);

    repository.staleRefresh.completeError(StateError('stale refresh failed'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh opportunity'), findsOneWidget);
    expect(find.text('Opportunities are unavailable'), findsNothing);
  });
}
