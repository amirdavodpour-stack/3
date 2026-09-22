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
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/features/profile/profile_page.dart';
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
  _ProfileRepo({this.applications = const []});

  final List<HopeApplication> applications;
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
    return applications;
  }

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) {
    withdrawCalls += 1;
    return withdrawResult.future;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  bool authenticated = false,
  double width = 900,
  ProfileRepository? repository,
}) async {
  tester.view.physicalSize = Size(width, 2400);
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
  await tester.pumpAndSettle();
}

void main() {
testWidgets('withdrawing an application disables the action until completion',
      (tester) async {
    const application = HopeApplication(
      id: 'a1',
      jobId: 'j1',
      jobTitle: 'Flutter developer',
      jobCity: 'تهران',
      jobKind: 'JOB',
      resumeText: 'A concise resume with enough detail.',
      skills: 'Flutter',
      status: 'PENDING',
      createdAt: null,
      updatedAt: null,
    );
    final repo = _ProfileRepo(applications: [application]);
    await _pump(tester, authenticated: true, repository: repo);

    await tester.scrollUntilVisible(
      find.text('Flutter developer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final undo = find.widgetWithIcon(IconButton, Icons.undo_rounded);
    expect(undo, findsOneWidget);

    await tester.tap(undo);
    await tester.pump();

    expect(repo.withdrawCalls, 1);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is IconButton &&
            widget.icon is SizedBox &&
            widget.onPressed == null,
      ),
      findsOneWidget,
    );

    repo.withdrawResult.complete(application);
    await tester.pumpAndSettle();
    expect(repo.withdrawCalls, 1);
  });

  testWidgets('withdraw refresh failure stays visible instead of becoming empty',
      (tester) async {
    final application = const HopeApplication(
      id: 'a2',
      jobId: 'j2',
      jobTitle: 'Backend engineer',
      jobCity: 'تهران',
      jobKind: 'JOB',
      resumeText: 'A concise resume with enough detail.',
      skills: 'Dart',
      status: 'PENDING',
      createdAt: null,
      updatedAt: null,
    );
    final repo = _ProfileRepo(applications: [application]);
    await _pump(tester, authenticated: true, repository: repo);

    await tester.scrollUntilVisible(
      find.text('Backend engineer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.undo_rounded));
    await tester.pump();
    repo.failApplicationReload = true;
    repo.withdrawResult.complete(application);
    await tester.pumpAndSettle();

    expect(find.text('درخواست‌ها در دسترس نیستند'), findsOneWidget);
    expect(find.text('Backend engineer'), findsOneWidget);
  });

  testWidgets('guest profile explains sign-in requirement', (tester) async {
    await _pump(tester);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.textContaining('ورود'), findsWidgets);
  });

  testWidgets('profile settings stay usable on narrow screens',
      (tester) async {
    await _pump(tester, authenticated: true, width: 360);
    await tester.pumpAndSettle();

    expect(find.text('کاربر'), findsWidgets);
    expect(find.text('فارسی'), findsOneWidget);
    expect(find.text('انگلیسی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated profile displays account and provider data',
      (tester) async {
    await _pump(tester, authenticated: true);
    expect(find.text('کاربر'), findsWidgets);
    expect(find.text('سلام، کاربر'), findsNothing);

    expect(find.text('مجری مستقل'), findsOneWidget);
    expect(find.text('آماده همکاری'), findsWidgets);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('INDIVIDUAL'), findsNothing);
    expect(find.text('تأییدشده'), findsWidgets);
    expect(find.textContaining('VERIFIED'), findsNothing);
  });
}
