import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/profile/profile_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/features/profile/profile_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthRepo implements AuthRepository {
  @override
  Future<AuthSession> loginWithGoogle(String _) =>
      throw UnimplementedError();
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

class _ProfileRepo implements ProfileRepository {
  final Completer<HopeApplication> withdrawResult =
      Completer<HopeApplication>();
  int withdrawCalls = 0;

  @override
  Future<HopeProviderProfile> getProviderProfile() async =>
      const HopeProviderProfile(
          providerType: 'INDIVIDUAL',
          capacity: 'OPEN',
          verificationStatus: 'VERIFIED',
          trustSignals: {'verified': true});

  bool failApplicationReload = false;

  @override
  Future<List<HopeApplication>> listApplications() async {
    await Future<void>.delayed(Duration.zero);
    if (failApplicationReload) {
      throw StateError('applications unavailable');
    }
    return const <HopeApplication>[];
  }

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) {
    withdrawCalls += 1;
    return withdrawResult.future;
  }
}

class _PendingProfileRepo extends _ProfileRepo {
  final Completer<HopeProviderProfile> profileCompleter =
      Completer<HopeProviderProfile>();

  @override
  Future<HopeProviderProfile> getProviderProfile() => profileCompleter.future;
}

Future<void> _pump(
  WidgetTester tester, {
  bool authenticated = false,
  double width = 900,
  double height = 2400,
  ProfileRepository? repository,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(_AuthRepo(), SecureStore());
  if (authenticated) {
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'کاربر'});
  } else {
    auth.continueAsGuest();
  }
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => ThemeController(settings)),
          ChangeNotifierProvider.value(value: auth),
          Provider<ProfileRepository>.value(value: repository ?? _ProfileRepo()),
        ],
        child: const ProfilePage(),
      ),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'profile professional loading uses the canonical async state',
    (tester) async {
      final repo = _PendingProfileRepo();
      await _pump(
        tester,
        authenticated: true,
        repository: repo,
        settle: false,
      );

      expect(find.byType(HopeAsyncState), findsOneWidget);
      expect(find.text('در حال بارگذاری اطلاعات حرفه‌ای'), findsOneWidget);

      repo.profileCompleter.complete(
        const HopeProviderProfile(
          providerType: 'INDIVIDUAL',
          capacity: 'OPEN',
          verificationStatus: 'VERIFIED',
          trustSignals: {'verified': true},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('مجری مستقل'), findsOneWidget);
    },
  );

testWidgets('profile keeps application management in the dedicated work destination',
      (tester) async {
    await _pump(tester, authenticated: true);
    expect(find.text('مرکز کار'), findsOneWidget);
    expect(find.byTooltip('انصراف'), findsNothing);
    expect(find.text('درخواست‌ها'), findsNothing);
  });

  testWidgets('guest profile explains sign-in requirement', (tester) async {
    await _pump(tester);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.textContaining('ورود'), findsWidgets);
  });

  testWidgets('profile stays stable across the compact-to-medium device matrix',
      (tester) async {
    for (final width in const [320.0, 360.0, 390.0, 412.0, 600.0]) {
      await _pump(tester, authenticated: true, width: width);

      expect(find.text('کاربر'), findsWidgets, reason: 'profile missing at $width dp');
      expect(find.text('فارسی'), findsOneWidget, reason: 'Persian control missing at $width dp');
      expect(find.text('انگلیسی'), findsOneWidget, reason: 'English control missing at $width dp');
      expect(tester.takeException(), isNull, reason: 'render exception at $width dp');
    }
  });

  testWidgets('authenticated profile compresses secondary settings on narrow screens', (tester) async {
    await _pump(tester, authenticated: true, width: 390);

    final panel = find.byKey(const ValueKey('profile-settings-panel'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).height, lessThan(700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated profile uses a compact account summary',
      (tester) async {
    await _pump(tester, authenticated: true, width: 390);

    final header = tester.widget<PremiumHeader>(
      find.byType(PremiumHeader).first,
    );
    expect(header.dense, isTrue);

    final summary = find.byKey(const ValueKey('profile-account-summary'));
    expect(summary, findsOneWidget);
    expect(tester.getSize(summary).height, lessThan(112));
    expect(find.text('حساب فعال'), findsOneWidget);
    expect(find.text('مجری مستقل'), findsOneWidget);
    expect(find.text('تأییدشده'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated profile displays account and provider data',
      (tester) async {
    await _pump(tester, authenticated: true);
    expect(find.byType(PremiumPageFrame), findsOneWidget);
    expect(find.text('کاربر'), findsWidgets);
    expect(find.text('سلام، کاربر'), findsNothing);

    expect(find.text('مجری مستقل'), findsOneWidget);
    expect(find.text('آماده همکاری'), findsWidgets);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('INDIVIDUAL'), findsNothing);
    expect(find.text('تأییدشده'), findsWidgets);
    expect(find.textContaining('VERIFIED'), findsNothing);
  });
  testWidgets(
    'Wave 24 language selector clears the dock at 360x640 and remains tappable',
    (tester) async {
      await _pump(tester, authenticated: true, width: 360, height: 640);
      final selector = find.byKey(const ValueKey('profile-language-selector'));
      final dock = find.byKey(const ValueKey('hope-navigation-dock'));
      expect(selector, findsOneWidget);
      expect(dock, findsOneWidget);
      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      final selectorRect = tester.getRect(selector);
      final dockRect = tester.getRect(dock);
      expect(
        selectorRect.bottom,
        lessThanOrEqualTo(dockRect.top - HopeV2Navigation.scrollEndGap),
        reason: 'Language selection must be reachable without overlapping navigation.',
      );
      await tester.tapAt(
        Offset(selectorRect.left + selectorRect.width * .25, selectorRect.center.dy),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

}
