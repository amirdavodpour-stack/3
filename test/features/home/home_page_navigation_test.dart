import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/notifications/notification.dart';
import 'package:hope_mobile/core/notifications/notification_repository.dart';
import 'package:hope_mobile/core/profile/profile_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/features/home/home_page.dart';
import 'package:hope_mobile/features/auth/login_page.dart';
import 'package:hope_mobile/features/transactions/transactions_page.dart';
import 'package:hope_mobile/features/marketplace/create_job_page.dart';
import 'package:hope_mobile/features/auth/register_page.dart';import 'package:hope_mobile/features/applications/my_applications_page.dart';
import 'package:hope_mobile/core/router/auth_return_intent.dart';
import 'package:hope_mobile/features/notifications/notifications_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home navigation behavior: drawer intents, admin gate, language toggle and
/// bottom-tab switching. Every test builds its own widgets/fakes, so there is
/// no shared mutable state between tests.
class _AuthRepo implements AuthRepository {
  _AuthRepo({this.allowLogin = false, this.allowRegister = false});

  final bool allowLogin;
  final bool allowRegister;

  @override
  Future<AuthSession> loginWithGoogle(String _) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(String e, String p) async {
    if (!allowLogin) throw UnimplementedError();
    return const AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      user: {'id': 'u1', 'displayName': 'Ali'},
    );
  }

  @override
  Future<AuthSession> register(String e, String p, String n) async {
    if (!allowRegister) throw UnimplementedError();
    return const AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      user: {'id': 'u1', 'displayName': 'Ali'},
    );
  }
  @override
  Future<void> logout() async {}
  @override
  Future<void> requestPasswordReset(String e) async {}
}

class _Transactions implements TransactionRepository {
  @override
  Future<List<HopeJob>> listMyJobs() async => [];
  @override
  Future<HopePayment> getPayment(String id) => throw UnimplementedError();
  @override
  Future<HopePayment> fundPayment(String id, {String? idempotencyKey}) =>
      throw UnimplementedError();
  @override
  Future<HopePayment> refundPayment(String id) => throw UnimplementedError();
  @override
  Future<HopePayment> releasePayment(String id) => throw UnimplementedError();
  @override
  Future<HopeJob> startJob(String id) => throw UnimplementedError();
  @override
  Future<HopeJob> deliverJob(String id) => throw UnimplementedError();
  @override
  Future<HopeJob> acceptJob(String id) => throw UnimplementedError();
  @override
  Future<void> submitEvidence(String jobId,
      {required String uri,
      required String notes,
      required String type}) async {}
}

class _Notifications implements NotificationRepository {
  @override
  Future<HopeNotificationPage> listNotifications(
          {int limit = 50, int offset = 0}) async =>
      const HopeNotificationPage(items: [], unreadCount: 0);
  @override
  Future<HopeNotification> markRead(String id) async => HopeNotification(
      id: id, type: 'x', title: 't', body: 'b', createdAt: null, readAt: 'now');
  @override
  Future<HopeNotificationPreferences> getPreferences() async =>
      const HopeNotificationPreferences(
          inApp: true,
          push: true,
          email: true,
          jobAlerts: true,
          applicationUpdates: true,
          paymentUpdates: true,
          marketing: false);

  @override
  Future<HopeNotificationPreferences> updatePreferences(
          Map<String, bool> patch) async =>
      getPreferences();

  @override
  Future<int> markAllRead() async => 0;
  @override
  Future<List<HopeNotificationDevice>> listDevices() async => const [];

  @override
  Future<void> disableDevice(String id) async {}
}

class _ProfileRepo implements ProfileRepository {
  @override
  Future<HopeProviderProfile> getProviderProfile() async =>
      const HopeProviderProfile(
          providerType: 'INDIVIDUAL',
          capacity: '3',
          verificationStatus: 'VERIFIED',
          trustSignals: {'verified': true});
  @override
  Future<List<HopeApplication>> listApplications() async => const [];
  @override
  Future<HopeApplication> withdrawApplication(String applicationId) =>
      throw UnimplementedError();
}

void _setView(WidgetTester tester) {
  // Tall viewport so every drawer tile (including the last, language) is
  // laid out and tappable.
  tester.view.physicalSize = const Size(700, 1700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<Widget> _app({
  bool admin = false,
  bool authenticated = false,
  bool allowLogin = false,
  bool allowRegister = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  // The app defaults to Persian; tests exercise the English navigation
  // labels, so pin the locale explicitly and deterministically.
  await settings.setLanguage('en');
  final auth = AuthController(
    _AuthRepo(allowLogin: allowLogin, allowRegister: allowRegister),
    SecureStore(),
  );
  if (authenticated) {
    await auth.applyRefreshedUser({
      'id': 'u1',
      'displayName': 'Ali',
      if (admin) 'role': 'ADMIN',
    });
  } else {
    auth.continueAsGuest();
  }
  // Providers sit ABOVE the MaterialApp so routes pushed onto the app
  // Navigator (NotificationsPage via HopeRoutes) resolve them. The whole app
  // rebuilds with the settings locale when the drawer toggles the language.
  return ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => ThemeController(settings)),
        ChangeNotifierProvider.value(value: auth),
        Provider<TransactionRepository>.value(value: _Transactions()),
        Provider<NotificationRepository>.value(value: _Notifications()),
        Provider<ProfileRepository>.value(value: _ProfileRepo()),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        locale: Locale(settings.language),
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomePage(),
      ),
    ),
  );
}

void main() {
  testWidgets('member drawer shows account entries and hides admin panel',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(authenticated: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('App menu'));
    await tester.pumpAndSettle();
    expect(find.text('App menu'), findsOneWidget);
    // A non-admin member sees notifications but no admin panel.
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Admin panel'), findsNothing);
    expect(find.text('Current location'), findsOneWidget);
  });

  testWidgets('admin member sees the admin panel entry in the drawer',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(authenticated: true, admin: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('App menu'));
    await tester.pumpAndSettle();
    expect(find.text('Admin panel'), findsOneWidget);
  });

  testWidgets('notifications drawer entry opens the notifications page',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(authenticated: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('App menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsPage), findsOneWidget);
  });

  testWidgets('drawer language toggle switches the app locale', (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(authenticated: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('App menu'));
    await tester.pumpAndSettle();
    expect(find.text('Language: English'), findsOneWidget);
    await tester.tap(find.text('Language: English'));
    await tester.pumpAndSettle();
    // The settings controller switched languages and the app rebuilds with
    // the Persian locale; navigation bar still present.
    final settings = tester
        .element(find.byType(NavigationBar))
        .read<HopeSettingsController>();
    expect(settings.language, 'fa');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('authenticated drawer does not duplicate primary Wallet',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(authenticated: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('App menu'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Wallet'),
      ),
      findsNothing,
    );
    expect(find.text('Wallet'), findsWidgets);
  });

  testWidgets(
      'guest create resumes CreateJob exactly once after successful login',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(allowLogin: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Log in to HOPE'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(CreateJobPage), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets(
      'guest create resumes CreateJob exactly once after successful registration',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(allowRegister: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Ali');
    await tester.enterText(find.byType(TextField).at(1), 'ali@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsNothing);
    expect(find.byType(CreateJobPage), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('guest create cancelled from auth returns to Home without CreateJob',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(CreateJobPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Activity exposes Applications, Offers and Notifications',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(authenticated: true));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Activity'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TransactionsPage), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('bottom navigation switches tabs and shows profile scaffold',
      (tester) async {
    _setView(tester);
    await tester.pumpWidget(await _app(authenticated: true));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
