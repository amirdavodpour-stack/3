import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/google_sign_in_service.dart';
import 'package:hope_mobile/core/config/backend_capabilities.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/profile/profile_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import '../../core/network/test_fixtures.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/features/profile/profile_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthRepo implements AuthRepository, GoogleAccountLinkRepository {
  String? linkedGoogleToken;
  Object? googleLinkFailure;

  @override
  Future<void> linkGoogleAccount(String idToken) async {
    if (googleLinkFailure != null) throw googleLinkFailure!;
    linkedGoogleToken = idToken;
  }

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

class _FakeGoogleSignInService extends GoogleSignInService {
  _FakeGoogleSignInService() : super(serverClientId: 'test-server-client');

  @override
  Future<String> authenticate() async => 'verified-google-id-token';
}

class _CapabilitiesRepo implements BackendCapabilitiesRepository {
  _CapabilitiesRepo(this.enabled);
  final bool enabled;
  @override
  Future<BackendCapabilities> load() async => BackendCapabilities(googleSignIn: enabled);
}

class _ProfileRepo implements ProfileRepository {
  final Completer<HopeApplication> withdrawResult =
      Completer<HopeApplication>();
  int withdrawCalls = 0;

  bool failProviderProfile = false;

  @override
  Future<HopeProviderProfile> getProviderProfile() async {
    if (failProviderProfile) {
      throw StateError('provider profile unavailable');
    }
    return const HopeProviderProfile(
      providerType: 'INDIVIDUAL',
      capacity: 'OPEN',
      verificationStatus: 'VERIFIED',
      trustSignals: {'verified': true},
    );
  }

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
  ThemeData? theme,
  double textScale = 1.0,
  bool googleCapabilityEnabled = false,
  GoogleSignInService? googleSignIn,
  _AuthRepo? authRepository,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(authRepository ?? _AuthRepo(), SecureStore());
  if (authenticated) {
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'کاربر'});
  } else {
    auth.continueAsGuest();
  }
  await tester.pumpWidget(MaterialApp(
    theme: theme ?? ThemeData.light(),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider(create: (_) => ThemeController(settings)),
            ChangeNotifierProvider.value(value: auth),
            Provider<ProfileRepository>.value(value: repository ?? _ProfileRepo()),
            Provider<BackendCapabilitiesRepository>.value(value: _CapabilitiesRepo(googleCapabilityEnabled)),
            if (googleSignIn != null) Provider<GoogleSignInService>.value(value: googleSignIn),
          ],
          child: const ProfilePage(),
        ),
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
  setUp(() => installFakeSecureStorageForTests());

  testWidgets('profile can explicitly link a verified Google account from account settings', (tester) async {
    final repository = _AuthRepo();
    await _pump(
      tester,
      authenticated: true,
      googleCapabilityEnabled: true,
      googleSignIn: _FakeGoogleSignInService(),
      authRepository: repository,
    );

    final linkAction = find.byKey(const ValueKey('profile-link-google-account'));
    expect(linkAction, findsOneWidget);
    await tester.tap(linkAction);
    await tester.pumpAndSettle();

    expect(repository.linkedGoogleToken, 'verified-google-id-token');
    expect(find.text('حساب گوگل با موفقیت متصل شد.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-link-google-account')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile hides Google account linking when backend capability is disabled', (tester) async {
    await _pump(
      tester,
      authenticated: true,
      googleCapabilityEnabled: false,
      googleSignIn: _FakeGoogleSignInService(),
    );
    expect(find.byKey(const ValueKey('profile-link-google-account')), findsNothing);
  });

  testWidgets('authenticated profile exposes the explicit Google account-link action only when Google is enabled', (tester) async {
    await _pump(
      tester,
      authenticated: true,
      googleCapabilityEnabled: true,
      googleSignIn: _FakeGoogleSignInService(),
    );

    expect(find.byKey(const ValueKey('profile-link-google-account')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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

  testWidgets(
    'profile professional data failure is visible and retry restores the real profile',
    (tester) async {
      final repo = _ProfileRepo()..failProviderProfile = true;
      await _pump(
        tester,
        authenticated: true,
        repository: repo,
      );

      expect(find.byType(HopeAsyncState), findsOneWidget);
      expect(find.text('اطلاعات حرفه‌ای در دسترس نیست'), findsOneWidget);
      expect(find.text('تلاش دوباره'), findsOneWidget);
      expect(find.text('مجری مستقل'), findsNothing);
      expect(find.text('تأییدشده'), findsNothing);
      expect(find.text('اعتماد'), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-professional-first-fold')),
        findsNothing,
      );

      repo.failProviderProfile = false;
      await tester.tap(find.text('تلاش دوباره'));
      await tester.pumpAndSettle();

      expect(find.text('اطلاعات حرفه‌ای در دسترس نیست'), findsNothing);
      expect(find.text('مجری مستقل'), findsOneWidget);
      expect(find.text('تأییدشده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

testWidgets('profile keeps application management in the dedicated work destination',
      (tester) async {
    await _pump(tester, authenticated: true);
    expect(find.text('مرکز کار'), findsOneWidget);
    expect(find.byTooltip('انصراف'), findsNothing);
    expect(find.text('درخواست‌ها'), findsNothing);
  });

  testWidgets('guest profile uses the Hero as the single editorial introduction',
      (tester) async {
    await _pump(tester, width: 390, height: 844);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.textContaining('ورود'), findsWidgets);

    final hero = find.byType(PremiumHero);
    expect(hero, findsOneWidget);
    expect(
      tester.getTopLeft(hero).dy,
      lessThan(100),
      reason: 'The guest introduction should not repeat a title and paragraph before the Hero.',
    );
    expect(tester.takeException(), isNull);
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

  testWidgets(
    'compact profile setting labels fully wrap at 1.5x text scale',
    (tester) async {
      await _pump(
        tester,
        authenticated: true,
        width: 360,
        height: 900,
        textScale: 1.5,
      );

      const label = 'پیشنهادهای شخصی‌سازی‌شده';
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final widget = tester.widget<Text>(finder);
      expect(
        widget.maxLines,
        isNull,
        reason:
            'Compact account settings must preserve full setting names at enlarged text scale.',
      );
      expect(widget.overflow, TextOverflow.visible);
      expect(
        tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

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
  testWidgets('verified profile trust label uses a readable trust token, not brand indigo',
      (tester) async {
    await _pump(
      tester,
      authenticated: true,
      theme: AppTheme.light(),
    );

    final railFinder = find.byType(HopeTrustSignalRail);
    expect(railFinder, findsOneWidget);
    final rail = tester.widget<HopeTrustSignalRail>(railFinder);
    final context = tester.element(railFinder);
    final verification = rail.signals.firstWhere(
      (signal) => signal.label == 'اعتماد',
    );

    expect(verification.color, HopeV2SemanticColors.verified(context));
    expect(verification.color, HopeV2Colors.trustTextLight);
    expect(verification.color, isNot(Theme.of(context).colorScheme.primary));
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


  testWidgets(
    'profile account and utility settings use semantic accents instead of blanket brand indigo',
    (tester) async {
      await _pump(
        tester,
        authenticated: true,
        width: 390,
        theme: AppTheme.dark(),
      );

      final accountTile = tester.widget<HopeIconTile>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-account-summary')),
          matching: find.byType(HopeIconTile),
        ).first,
      );
      expect(accountTile.color, HopeV2Colors.success);

      final settingsTiles = tester.widgetList<HopeIconTile>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-settings-panel')),
          matching: find.byType(HopeIconTile),
        ),
      ).toList();
      expect(settingsTiles.length, greaterThanOrEqualTo(4));
      expect(settingsTiles[0].color, HopeV2Colors.secondary,
          reason: 'Language is an informational utility, not a primary action.');
      expect(settingsTiles[2].color, HopeV2Colors.secondary,
          reason: 'Current-location state uses the information accent.');
      expect(settingsTiles[3].color, HopeV2Colors.secondary,
          reason: 'City selection shares the information/location role.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact appearance action keeps a 48dp rendered and semantic target',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(
          tester,
          authenticated: true,
          width: 390,
          height: 844,
          theme: AppTheme.dark(),
        );

        final appearanceLabel = find.text('ظاهر برنامه');
        expect(appearanceLabel, findsOneWidget);
        final appearanceTile = find.ancestor(
          of: appearanceLabel,
          matching: find.byType(ListTile),
        ).first;
        await tester.ensureVisible(appearanceTile);
        await tester.pumpAndSettle();

        expect(
          tester.getSize(appearanceTile).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSemantics(appearanceTile).rect.height,
          greaterThanOrEqualTo(48),
          reason: 'The TalkBack action target must meet the 48dp minimum.',
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );


}
