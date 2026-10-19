import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/auth/google_sign_in_service.dart';
import 'package:hope_mobile/core/config/backend_capabilities.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/core/ui/hope_l10n.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/features/auth/login_page.dart';
import 'package:hope_mobile/features/auth/password_reset_page.dart';
import 'package:hope_mobile/features/auth/register_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthRepo implements AuthRepository {
  bool failLogin = false;
  bool failRegister = false;
  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastRegisteredEmail;
  String? lastRegisteredPassword;
  String? lastDisplayName;

  @override
  Future<AuthSession> loginWithGoogle(String _) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(String email, String password) async {
    lastLoginEmail = email;
    lastLoginPassword = password;
    if (failLogin) throw StateError('credentials rejected');
    return const AuthSession(accessToken: 'a', refreshToken: 'r', user: {'id': 'u'});
  }

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  ) async {
    lastRegisteredEmail = email;
    lastRegisteredPassword = password;
    lastDisplayName = displayName;
    if (failRegister) throw StateError('registration rejected');
    return const AuthSession(accessToken: 'a', refreshToken: 'r', user: {'id': 'u'});
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}
}

class _BackendCapabilitiesRepo implements BackendCapabilitiesRepository {
  _BackendCapabilitiesRepo(this.capabilities, {this.fail = false});

  final BackendCapabilities? capabilities;
  final bool fail;

  @override
  Future<BackendCapabilities> load() async {
    if (fail) throw StateError('capability endpoint unavailable');
    return capabilities!;
  }
}

Future<Widget> _screen(
  Widget child, {
  double textScale = 1,
  AuthRepository? authRepository,
  GoogleSignInService? googleSignIn,
  BackendCapabilitiesRepository? capabilities,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(authRepository ?? _AuthRepo(), SecureStore());
  return MaterialApp(
    theme: ThemeData.light(),
    locale: const Locale('fa'),
    supportedLocales: const [Locale('fa'), Locale('en')],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<HopeSettingsController>.value(value: settings),
        ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController(settings)),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        if (googleSignIn != null)
          Provider<GoogleSignInService>.value(value: googleSignIn),
        if (capabilities != null)
          Provider<BackendCapabilitiesRepository>.value(value: capabilities),
      ],
      child: child,
    ),
  );
}

void main() {
  testWidgets('login exposes guest entry and account actions', (tester) async {
    await tester.pumpWidget(await _screen(const LoginPage()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ادامه به‌عنوان مهمان'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(PremiumHero), findsOneWidget);
    expect(find.byType(PremiumPageFrame), findsOneWidget);
    expect(find.text('ادامه به‌عنوان مهمان'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('ساخت حساب'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('ساخت حساب'), findsOneWidget);
  });

  testWidgets('compact login keeps account creation within the initial viewport',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _screen(const LoginPage()));
    await tester.pumpAndSettle();

    final signup = find.textContaining('ساخت حساب');
    expect(signup, findsOneWidget);
    expect(tester.getRect(signup).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(signup).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login has no orphaned separator when Google sign-in is unavailable',
      (tester) async {
    await tester.pumpWidget(await _screen(const LoginPage()));
    await tester.pumpAndSettle();
    expect(find.text('یا'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'login hides configured Google sign-in when backend capability is disabled',
    (tester) async {
      await tester.pumpWidget(await _screen(
        const LoginPage(),
        googleSignIn: GoogleSignInService(serverClientId: 'test-server-client'),
        capabilities: _BackendCapabilitiesRepo(
          const BackendCapabilities(googleSignIn: false),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth-google-sign-in')), findsNothing);
      expect(find.text('یا'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login shows configured Google sign-in only when backend capability is enabled',
    (tester) async {
      await tester.pumpWidget(await _screen(
        const LoginPage(),
        googleSignIn: GoogleSignInService(serverClientId: 'test-server-client'),
        capabilities: _BackendCapabilitiesRepo(
          const BackendCapabilities(googleSignIn: true),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth-google-sign-in')), findsOneWidget);
      expect(find.text('یا'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'register shows configured Google sign-in visibly within a compact viewport',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _screen(
        const RegisterPage(),
        googleSignIn: GoogleSignInService(serverClientId: 'test-server-client'),
        capabilities: _BackendCapabilitiesRepo(
          const BackendCapabilities(googleSignIn: true),
        ),
      ));
      await tester.pumpAndSettle();

      final googleButton = find.byKey(const ValueKey('auth-google-sign-in'));
      expect(googleButton, findsOneWidget);
      expect(find.text('یا'), findsOneWidget);
      final bounds = tester.getRect(googleButton);
      expect(bounds.left, greaterThanOrEqualTo(0));
      expect(bounds.right, lessThanOrEqualTo(360));
      expect(
        bounds.top,
        greaterThanOrEqualTo(0),
        reason: 'The configured Google CTA must not be hidden above the captured frame.',
      );
      expect(
        bounds.bottom,
        lessThanOrEqualTo(640),
        reason: 'The configured Google CTA must be visible in the 360x640dp Register viewport.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'register hides configured Google sign-in when backend capability lookup fails',
    (tester) async {
      await tester.pumpWidget(await _screen(
        const RegisterPage(),
        googleSignIn: GoogleSignInService(serverClientId: 'test-server-client'),
        capabilities: _BackendCapabilitiesRepo(null, fail: true),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auth-google-sign-in')), findsNothing);
      expect(find.text('یا'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave47 login failure preserves credentials and re-enables the submit action',
    (tester) async {
      final repository = _AuthRepo()..failLogin = true;
      await tester.pumpWidget(
        await _screen(const LoginPage(), authRepository: repository),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'person@example.com');
      await tester.enterText(fields.at(1), 'correct-horse-battery');
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(repository.lastLoginEmail, 'person@example.com');
      expect(repository.lastLoginPassword, 'correct-horse-battery');
      expect(tester.widget<TextField>(fields.at(0)).controller?.text,
          'person@example.com');
      expect(tester.widget<TextField>(fields.at(1)).controller?.text,
          'correct-horse-battery');
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave47 registration failure preserves fields and re-enables the submit action',
    (tester) async {
      final repository = _AuthRepo()..failRegister = true;
      await tester.pumpWidget(
        await _screen(const RegisterPage(), authRepository: repository),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Amir User');
      await tester.enterText(fields.at(1), 'person@example.com');
      await tester.enterText(fields.at(2), 'correct-horse-battery');
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(repository.lastDisplayName, 'Amir User');
      expect(repository.lastRegisteredEmail, 'person@example.com');
      expect(repository.lastRegisteredPassword, 'correct-horse-battery');
      expect(tester.widget<TextField>(fields.at(0)).controller?.text, 'Amir User');
      expect(tester.widget<TextField>(fields.at(1)).controller?.text,
          'person@example.com');
      expect(tester.widget<TextField>(fields.at(2)).controller?.text,
          'correct-horse-battery');
      expect(find.byType(RegisterPage), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('login keeps the auth surface free of backdrop blur', (tester) async {
    await tester.pumpWidget(await _screen(const LoginPage()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('guest action changes authentication state without credentials',
      (tester) async {
    await tester.pumpWidget(await _screen(const LoginPage()));
    await tester.pumpAndSettle();
    final auth = Provider.of<AuthController>(
        tester.element(find.byType(LoginPage)),
        listen: false);
    await tester.scrollUntilVisible(find.text('ادامه به‌عنوان مهمان'), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('ادامه به‌عنوان مهمان'));
    await tester.pumpAndSettle();
    expect(auth.isGuest, isTrue);
    expect(auth.isAuthenticated, isFalse);
  });

  testWidgets('register page renders required account fields', (tester) async {
    await tester.pumpWidget(await _screen(const RegisterPage()));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(3));
    final copy = HopeCopy.of(tester.element(find.byType(RegisterPage)));
    expect(
      find.text(copy.copy_start_a_good_collaboration_9df52cf),
      findsOneWidget,
      reason: 'Compact auth heroes render the headline once and suppress the eyebrow to preserve first-fold density.',
    );
    expect(
      find.text(copy.copy_hope_account_4ba3966),
      findsNothing,
      reason: 'The compact registration hero intentionally suppresses the eyebrow.',
    );
  });

  testWidgets('auth entry surfaces use the canonical PremiumHero owner', (tester) async {
    for (final screen in [
      const LoginPage(),
      const RegisterPage(),
      const PasswordResetPage(),
    ]) {
      await tester.pumpWidget(await _screen(screen));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumHero), findsOneWidget);
    }
  });

  testWidgets('auth surfaces keep the hero compact for a denser first fold',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final screen in [
      const LoginPage(),
      const RegisterPage(),
      const PasswordResetPage(),
    ]) {
      await tester.pumpWidget(await _screen(screen));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(PremiumHero)).height,
        lessThanOrEqualTo(180),
      );
    }
  });

  testWidgets('login primary action spans the form content width', (tester) async {
    await tester.pumpWidget(await _screen(const LoginPage()));
    await tester.pumpAndSettle();

    final panelWidth = tester.getSize(find.byType(PremiumPanel)).width;
    final buttonWidth = tester.getSize(find.byType(FilledButton)).width;

    expect(buttonWidth, greaterThanOrEqualTo(panelWidth - 40));
  });

  testWidgets('password reset renders an email form', (tester) async {
    await tester.pumpWidget(await _screen(const PasswordResetPage()));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordResetPage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
  testWidgets('Wave 28 auth prefix glyphs have deterministic compact render bounds',
      (tester) async {
    final screens = <Widget>[
      const LoginPage(),
      const RegisterPage(),
      const PasswordResetPage(),
    ];
    final expectedKeys = <List<String>>[
      ['auth-email-field-icon', 'auth-password-field-icon'],
      ['auth-name-field-icon', 'auth-email-field-icon', 'auth-password-field-icon'],
      ['auth-email-field-icon'],
    ];

    for (var index = 0; index < screens.length; index++) {
      await tester.pumpWidget(await _screen(screens[index]));
      await tester.pumpAndSettle();
      for (final key in expectedKeys[index]) {
        final icon = find.byKey(ValueKey(key));
        expect(icon, findsOneWidget, reason: 'Missing field icon $key');
        expect(
          tester.widget<Icon>(icon).size,
          18,
          reason: 'The painted Material glyph for $key must be configured at 18dp; its prefix slot remains 48dp for touch/layout consistency.',
        );
      }
      expect(tester.takeException(), isNull);
    }
  });


  testWidgets(
    'login submit remains reachable above a compact keyboard at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        await _screen(const LoginPage(), textScale: 1.5),
      );
      await tester.pumpAndSettle();

      final submit = find.byType(FilledButton);
      expect(submit, findsOneWidget);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      final submitRect = tester.getRect(submit);
      expect(submitRect.top, greaterThanOrEqualTo(0));
      expect(
        submitRect.bottom,
        lessThanOrEqualTo(360),
        reason: 'The 280dp keyboard inset must not obscure the login CTA at 1.5x text.',
      );
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'register submit remains reachable above the keyboard on compact viewports',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(await _screen(const RegisterPage()));
      await tester.pumpAndSettle();

      final submit = find.byType(FilledButton);
      expect(submit, findsOneWidget);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();

      final submitRect = tester.getRect(submit);
      expect(submitRect.top, greaterThanOrEqualTo(0));
      expect(
        submitRect.bottom,
        lessThanOrEqualTo(360),
        reason: 'The 280dp keyboard inset must not obscure the registration CTA.',
      );
      expect(tester.takeException(), isNull);
    },
  );

}
