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
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/profile/profile_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wave30AuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loginWithGoogle(String _) => throw UnimplementedError();

  @override
  Future<AuthSession> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> register(String email, String password, String name) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}
}

class _Wave30ProfileRepository implements ProfileRepository {
  final Completer<HopeApplication> withdrawal = Completer();

  @override
  Future<HopeProviderProfile> getProviderProfile() async =>
      const HopeProviderProfile(
        providerType: 'INDIVIDUAL',
        capacity: 'OPEN',
        verificationStatus: 'VERIFIED',
        trustSignals: {'verified': true},
      );

  @override
  Future<List<HopeApplication>> listApplications() async {
    await Future<void>.delayed(Duration.zero);
    return const <HopeApplication>[];
  }

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) =>
      withdrawal.future;
}

void main() {
  testWidgets(
    'Wave30 Profile language selector uses a readable stacked layout at 1.5x English LTR',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final settings = HopeSettingsController();
      await settings.load();
      final auth = AuthController(_Wave30AuthRepository(), SecureStore());
      await auth.applyRefreshedUser({'id': 'wave30-user', 'displayName': 'Ali'});
      final repository = _Wave30ProfileRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: settings),
                  ChangeNotifierProvider(
                    create: (_) => ThemeController(settings),
                  ),
                  ChangeNotifierProvider.value(value: auth),
                  Provider<ProfileRepository>.value(value: repository),
                ],
                child: const ProfilePage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = find.text('App language');
      final selector = find.byKey(
        const ValueKey('profile-language-selector'),
      );
      final dock = find.byKey(const ValueKey('hope-navigation-dock'));

      expect(title, findsOneWidget);
      expect(selector, findsOneWidget);
      expect(dock, findsOneWidget);
      expect(
        tester.getSize(title).height,
        lessThan(80),
        reason: 'At 1.5x text, the title must not break into three narrow lines.',
      );

      await tester.ensureVisible(selector);
      await tester.pumpAndSettle();
      final selectorRect = tester.getRect(selector);
      final dockRect = tester.getRect(dock);
      expect(
        selectorRect.left,
        lessThan(100),
        reason: 'At enlarged text, the selector must stack below the details.',
      );
      expect(
        selectorRect.right,
        lessThanOrEqualTo(360),
        reason: 'The selector must stay within the compact viewport.',
      );
      expect(
        selectorRect.bottom,
        lessThanOrEqualTo(dockRect.top - HopeV2Navigation.scrollEndGap),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
