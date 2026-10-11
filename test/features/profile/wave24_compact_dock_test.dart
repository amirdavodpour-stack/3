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
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wave24AuthRepository implements AuthRepository {
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

class _Wave24ProfileRepository implements ProfileRepository {
  @override
  Future<HopeProviderProfile> getProviderProfile() async =>
      const HopeProviderProfile(
        providerType: 'INDIVIDUAL',
        capacity: 'OPEN',
        verificationStatus: 'VERIFIED',
        trustSignals: {'verified': true},
      );
  @override
  Future<List<HopeApplication>> listApplications() async => const [];
  @override
  Future<HopeApplication> withdrawApplication(String applicationId) =>
      throw UnimplementedError();
}

void main() {
  testWidgets(
    'Wave 25 first-fold profile language selector stays fully above the dock and remains tappable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      // Match the compact Android capture's bottom system/gesture inset.
      tester.view.padding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      SharedPreferences.setMockInitialValues({});
      final settings = HopeSettingsController();
      await settings.load();
      final auth = AuthController(_Wave24AuthRepository(), SecureStore());
      await auth.applyRefreshedUser({
        'id': 'wave24-user',
        'displayName': 'کاربر',
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          locale: const Locale('fa'),
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
              ChangeNotifierProvider(create: (_) => ThemeController(settings)),
              ChangeNotifierProvider.value(value: auth),
              Provider<ProfileRepository>.value(
                value: _Wave24ProfileRepository(),
              ),
            ],
            child: const ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selector = find.byKey(
        const ValueKey('profile-language-selector'),
      );
      // Do not auto-scroll: assert the actual first fold at 360x640.
      final dock = find.byKey(const ValueKey('hope-navigation-dock'));
      expect(selector, findsOneWidget);
      expect(dock, findsOneWidget);
      final selectorRect = tester.getRect(selector);
      final dockRect = tester.getRect(dock);
      expect(
        selectorRect.bottom,
        lessThanOrEqualTo(dockRect.top - HopeV2Navigation.scrollEndGap),
        reason: 'Language control must be fully above the fixed dock.',
      );
      final persian = find.descendant(
        of: selector,
        matching: find.text('فارسی'),
      );
      expect(persian, findsOneWidget);
      await tester.tap(persian);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
