// ignore_for_file: avoid_print

import 'dart:io';

import 'package:integration_test/src/channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/auth/google_sign_in_service.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/category.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/job_detail_repository.dart';
import 'package:hope_mobile/core/marketplace/marketplace_repository.dart';
import 'package:hope_mobile/core/marketplace/offer_repository.dart';
import 'package:hope_mobile/core/marketplace/saved_search_repository.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/notifications/notification.dart';
import 'package:hope_mobile/core/notifications/notification_repository.dart';
import 'package:hope_mobile/core/profile/profile_repository.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/vazirmatn_loader.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/core/uploads/upload_queue.dart';
import 'package:hope_mobile/features/applications/my_applications_page.dart';
import 'package:hope_mobile/features/auth/login_page.dart';
import 'package:hope_mobile/features/auth/password_reset_page.dart';
import 'package:hope_mobile/features/auth/register_page.dart';
import 'package:hope_mobile/features/home/home_page.dart';
import 'package:hope_mobile/features/jobs/jobs_page.dart';
import 'package:hope_mobile/features/jobs/saved_searches_page.dart';
import 'package:hope_mobile/features/marketplace/create_job_page.dart';
import 'package:hope_mobile/features/marketplace/job_detail_page.dart';
import 'package:hope_mobile/features/notifications/notifications_page.dart';
import 'package:hope_mobile/features/offers/offers_page.dart';
import 'package:hope_mobile/features/profile/profile_page.dart';
import 'package:hope_mobile/features/transactions/transaction_page.dart';
import 'package:hope_mobile/features/transactions/transactions_page.dart';
import 'package:hope_mobile/features/wallet/wallet_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

class _EvidenceAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> loginWithGoogle(String _) => throw UnimplementedError();

  @override
  Future<AuthSession> login(String email, String password) async =>
      const AuthSession(
        accessToken: 'runtime-access',
        refreshToken: 'runtime-refresh',
        user: {'id': 'runtime-user', 'displayName': 'HOPE Runtime'},
      );

  @override
  Future<AuthSession> register(
    String email,
    String password,
    String displayName,
  ) async =>
      const AuthSession(
        accessToken: 'runtime-access',
        refreshToken: 'runtime-refresh',
        user: {'id': 'runtime-user', 'displayName': 'HOPE Runtime'},
      );

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset(String email) async {}
}

class _EvidenceWalletRepository implements WalletRepository {
  final _wallet = HopeWallet.fromMap({
    'id': 'wallet-runtime-evidence',
    'userId': 'runtime-user',
    'currency': 'TOMAN',
    'availableBalance': 2500000,
    'lockedBalance': 1000000,
    'status': 'ACTIVE',
  });

  @override
  Future<HopeWallet> getWallet() async => _wallet;

  @override
  Future<WalletTransactionsPage> listTransactions({
    int limit = 30,
    String? cursor,
  }) async =>
      WalletTransactionsPage(
        items: [
          HopeWalletTransaction.fromMap({
            'id': 'tx-runtime-1',
            'entryType': 'TRANSFER',
            'direction': 'CREDIT',
            'amount': 500000,
            'currency': 'TOMAN',
            'referenceType': 'TRANSFER',
            'financialOperationId': 'runtime-op-1',
            'createdAt': '2026-09-21T06:00:00Z',
          }),
        ],
      );

  @override
  Future<List<HopePayout>> listPayouts() async => [
        HopePayout.fromMap({
          'id': 'payout-runtime-1',
          'walletId': 'wallet-runtime-evidence',
          'amount': 400000,
          'currency': 'TOMAN',
          'provider': 'internal',
          'status': 'REQUESTED',
          'idempotencyKey': 'runtime-key-1',
        }),
      ];

  @override
  Future<Map<String, dynamic>> transfer({
    required String destinationWalletId,
    required int amount,
    required String idempotencyKey,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>> requestPayout({
    required int amount,
    required String idempotencyKey,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>> topUp({
    required int amount,
    required String idempotencyKey,
  }) async =>
      const {};
}

class _EvidenceTransactionRepository implements TransactionRepository {
  HopeJob get _job => _jobFixture();

  HopePayment get _payment => HopePayment(
        id: 'payment-runtime-1',
        status: 'LOCKED',
        amount: '1500000',
        providerRef: 'internal-ledger',
        job: _job,
        fees: const HopePaymentFees(
          baseAmount: '1500000',
          employerFee: '30000',
          workerFee: '15000',
          platformFee: '15000',
          employerCharge: '1530000',
          providerPayout: '1485000',
          policyVersion: 'v1',
          currency: 'TOMAN',
        ),
      );

  @override
  Future<List<HopeJob>> listMyJobs() async => [_job];

  @override
  Future<HopePayment> getPayment(String jobId) async => _payment;

  @override
  Future<HopePayment> fundPayment(String jobId, {String? idempotencyKey}) async =>
      _payment;

  @override
  Future<HopePayment> refundPayment(String jobId) async => _payment;

  @override
  Future<HopePayment> releasePayment(String jobId) async => _payment;

  @override
  Future<HopeJob> startJob(String jobId) async => _job;

  @override
  Future<HopeJob> deliverJob(String jobId) async => _job;

  @override
  Future<HopeJob> acceptJob(String jobId) async => _job;

  @override
  Future<void> submitEvidence(
    String jobId, {
    required String uri,
    required String notes,
    required String type,
  }) async {}
}

class _EvidenceMarketplaceRepository implements MarketplaceRepository {
  final _jobs = <HopeJob>[
    _jobFixture(),
    HopeJob.fromMap({..._jobFixture().toMap(), 'id': 'job-runtime-2', 'title': 'توسعه Flutter برای محصول جدید', 'kind': 'JOB', 'recommendationScore': 87, 'recommendationReasons': ['SKILL_MATCH']}),
    HopeJob.fromMap({..._jobFixture().toMap(), 'id': 'job-runtime-3', 'title': 'طراحی هویت بصری استارتاپ', 'kind': 'MISSION', 'recommendationScore': 76, 'recommendationReasons': ['CATEGORY_MATCH']}),
  ];

  @override
  Future<List<HopeCategory>> listCategories() async => const [
        HopeCategory(
          id: 'cat-1',
          slug: 'software',
          name: 'نرم‌افزار',
          nameEn: 'Software',
          description: 'Software work',
          parentId: null,
          sortOrder: 1,
          isActive: true,
        ),
      ];

  @override
  Future<HopeJob> getOpportunity(String id) async => _jobFixture();

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
      _jobs;

  @override
  Future<HopeJob> createOpportunity(Map<String, dynamic> body) async =>
      _jobFixture();

  @override
  Future<void> publishOpportunity(String id) async {}
}

class _EvidenceSavedSearchRepository implements SavedSearchRepository {
  @override
  Future<List<HopeSavedSearch>> list() async => const [
        HopeSavedSearch(
          id: 'search-1',
          name: 'Flutter',
          query: 'Flutter',
          kind: 'JOB',
          visibility: 'PUBLIC',
          city: 'تهران',
          category: 'Software',
          updatedAt: '2026-09-21T06:00:00Z',
        ),
      ];

  @override
  Future<HopeSavedSearch> upsert(HopeSavedSearch search) async => search;

  @override
  Future<void> delete(String id) async {}
}

class _EvidenceProfileRepository implements ProfileRepository {
  @override
  Future<HopeProviderProfile> getProviderProfile() async =>
      const HopeProviderProfile(
        providerType: 'INDIVIDUAL',
        capacity: 'FULL_TIME',
        verificationStatus: 'VERIFIED',
        trustSignals: {
          'verified': true,
          'completedJobs': 27,
          'activeJobs': 2,
          'memberSince': '2025',
        },
      );

  @override
  Future<List<HopeApplication>> listApplications() async => [_applicationFixture()];

  @override
  Future<HopeApplication> withdrawApplication(String applicationId) async =>
      _applicationFixture();
}

class _EvidenceJobDetailRepository implements JobDetailRepository {
  @override
  Future<List<HopeCandidate>> listCandidates(String jobId) async => const [
        HopeCandidate(
          id: 'candidate-1',
          skills: 'Flutter, Dart',
          resumeText: 'Mobile engineer',
          status: 'INTERVIEW',
        ),
      ];

  @override
  Future<HopeApplication> applyToJob(
    String jobId, {
    required String resumeText,
    required String skills,
  }) async =>
      _applicationFixture();

  @override
  Future<HopeOffer> submitOffer(
    String jobId, {
    required String price,
    required String message,
  }) async =>
      _offerFixture();

  @override
  Future<void> candidateAction(
    String jobId,
    String candidateId,
    String action,
  ) async {}

  @override
  Future<Map<String, dynamic>> compareCandidates(
    String jobId,
    List<String> applicationIds,
  ) async =>
      const {'items': []};

  @override
  Future<void> reportJob(
    String jobId, {
    required String reason,
    String details = '',
  }) async {}
}

class _EvidenceOfferRepository implements OfferRepository {
  @override
  Future<List<HopeOffer>> listForJob(String jobId) async => [_offerFixture()];

  @override
  Future<List<HopeOffer>> listMine() async => [_offerFixture()];

  @override
  Future<HopeOffer> get(String offerId) async => _offerFixture();

  @override
  Future<HopeOffer> submit(
    String jobId, {
    required String price,
    String message = '',
  }) async =>
      _offerFixture();

  @override
  Future<Map<String, dynamic>> accept(String offerId) async => const {};
}

class _EvidenceNotificationRepository implements NotificationRepository {
  @override
  Future<HopeNotificationPage> listNotifications({
    int limit = 50,
    int offset = 0,
  }) async =>
      const HopeNotificationPage(
        unreadCount: 1,
        items: [
          HopeNotification(
            id: 'notification-1',
            type: 'PAYMENT_UPDATE',
            title: 'پرداخت پروژه به‌روزرسانی شد',
            body: 'پرداخت در وضعیت قفل‌شده قرار گرفت.',
            createdAt: '2026-09-21T06:00:00Z',
            readAt: null,
            data: {'paymentId': 'payment-runtime-1'},
          ),
        ],
      );

  @override
  Future<HopeNotification> markRead(String id) async =>
      const HopeNotification(
        id: 'notification-1',
        type: 'PAYMENT_UPDATE',
        title: 'پرداخت',
        body: 'به‌روزرسانی شد',
        createdAt: '2026-09-21T06:00:00Z',
        readAt: '2026-09-21T07:00:00Z',
      );

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<HopeNotificationPreferences> getPreferences() async =>
      const HopeNotificationPreferences(
        inApp: true,
        push: true,
        email: false,
        jobAlerts: true,
        applicationUpdates: true,
        paymentUpdates: true,
        marketing: false,
      );

  @override
  Future<HopeNotificationPreferences> updatePreferences(
    Map<String, bool> patch,
  ) async =>
      getPreferences();

  @override
  Future<List<HopeNotificationDevice>> listDevices() async => const [
        HopeNotificationDevice(
          id: 'device-1',
          platform: 'ANDROID',
          enabled: true,
        ),
      ];

  @override
  Future<void> disableDevice(String id) async {}
}

HopeJob _jobFixture() => HopeJob.fromMap({
      'id': 'job-runtime-1',
      'title': 'طراحی رابط موبایل حرفه‌ای',
      'description':
          'بازطراحی یک اپلیکیشن موبایل با تمرکز بر تجربه کاربری، دسترس‌پذیری و عملکرد.',
      'categoryId': 'cat-1',
      'category': 'Software',
      'jobType': 'FIXED',
      'budgetType': 'FIXED',
      'budgetMin': '1500000',
      'budgetMax': '2500000',
      'duration': '8 روز',
      'acceptanceCriteria': 'تحویل نسخه نهایی و تست‌شده',
      'status': 'PUBLISHED',
      'ownerId': 'runtime-owner',
      'providerId': null,
      'city': 'تهران',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'schedule': 'FULL_TIME',
      'offerCount': 4,
      'isOwner': false,
    });

HopeApplication _applicationFixture() => HopeApplication.fromMap({
      'id': 'application-runtime-1',
      'jobId': 'job-runtime-1',
      'jobTitle': 'طراحی رابط موبایل حرفه‌ای',
      'jobCity': 'تهران',
      'jobKind': 'JOB',
      'resumeText': 'Mobile engineer',
      'skills': 'Flutter, Dart, UX',
      'status': 'SHORTLISTED',
      'createdAt': '2026-09-20T06:00:00Z',
      'updatedAt': '2026-09-21T06:00:00Z',
    });

HopeOffer _offerFixture() => HopeOffer.fromMap({
      'id': 'offer-runtime-1',
      'jobId': 'job-runtime-1',
      'providerId': 'runtime-user',
      'price': '1800000',
      'message': 'تحویل سریع و با تست کامل',
      'status': 'PENDING',
      'createdAt': '2026-09-21T06:00:00Z',
      'updatedAt': '2026-09-21T06:00:00Z',
    });

ApplicationRegistry _registry() => ApplicationRegistry(
      marketplace: _EvidenceMarketplaceRepository(),
      jobDetail: _EvidenceJobDetailRepository(),
      transactions: _EvidenceTransactionRepository(),
      wallets: _EvidenceWalletRepository(),
      auth: _EvidenceAuthRepository(),
      notifications: _EvidenceNotificationRepository(),
      profile: _EvidenceProfileRepository(),
      savedSearches: _EvidenceSavedSearchRepository(),
    );

final GoogleSignInService _runtimeGoogleSignIn = GoogleSignInService();
Future<void>? _runtimeFontLoad;

Future<({AuthController auth, HopeSettingsController settings, ApplicationRegistry registry})>
    _prepare() async {
  _runtimeFontLoad ??= loadVazirmatnFont();
  await _runtimeFontLoad;
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(_EvidenceAuthRepository(), SecureStore());
  await auth.applyRefreshedUser({
    'id': 'runtime-user',
    'displayName': 'HOPE Runtime',
    'email': 'runtime@example.invalid',
  });
  print('HOPE_RUNTIME_PREPARE:google-start');
  await _runtimeGoogleSignIn.initialize();
  print('HOPE_RUNTIME_PREPARE:google-done');
  final requireGoogle =
      Platform.environment['HOPE_REQUIRE_GOOGLE_AUTH'] == '1';
  if (requireGoogle && !_runtimeGoogleSignIn.isConfigured) {
    throw StateError(
      'GOOGLE_SERVER_CLIENT_ID is required for runtime auth evidence.',
    );
  }
  print('HOPE_GOOGLE_AUTH_CONFIGURED:${_runtimeGoogleSignIn.isConfigured}');
  return (auth: auth, settings: settings, registry: _registry());
}

class _EvidenceHost extends StatelessWidget {
  const _EvidenceHost({
    required this.runtime,
    required this.locale,
    required this.child,
  });

  final _Runtime runtime;
  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HopeSettingsController>.value(
          value: runtime.settings,
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(runtime.settings),
        ),
        ChangeNotifierProvider<AuthController>.value(value: runtime.auth),
        Provider<GoogleSignInService>.value(value: _runtimeGoogleSignIn),
        Provider<ApplicationRegistry>.value(value: runtime.registry),
        Provider<MarketplaceRepository>.value(value: runtime.registry.marketplace!),
        Provider<JobDetailRepository>.value(value: runtime.registry.jobDetail!),
        Provider<TransactionRepository>.value(value: runtime.registry.transactions!),
        Provider<WalletRepository>.value(value: runtime.registry.wallets!),
        Provider<SavedSearchRepository>.value(value: runtime.registry.savedSearches),
        Provider<ProfileRepository>.value(value: runtime.registry.profile!),
        Provider<NotificationRepository>.value(value: runtime.registry.notifications!),
        Provider<OfferRepository>.value(value: _EvidenceOfferRepository()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: Directionality(
          textDirection: locale.languageCode == 'en'
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: child,
        ),
      ),
    );
  }
}

const _responsiveOnly =
    bool.fromEnvironment('HOPE_RESPONSIVE_ONLY', defaultValue: false);
const _captureLocale =
    String.fromEnvironment('HOPE_CAPTURE_LOCALE', defaultValue: '');
const _adbScreenshotCapture =
    bool.fromEnvironment('HOPE_ADB_SCREENSHOT_CAPTURE', defaultValue: false);
const _screenshotSyncRoot =
    String.fromEnvironment('HOPE_SCREENSHOT_SYNC_ROOT', defaultValue: '');

class _EvidenceUploadQueue implements UploadQueue {
  @override
  late final ApiClient api;
  @override
  int get maxAttempts => 1;
  @override
  void Function(PendingUpload item, Object error)? onPermanentFailure;
  @override
  void Function(PendingUpload item, Object error)? onTransientFailure;
  @override
  Future<dynamic> uploadNowWithRetry(String path, File file) async =>
      <String, String>{'key': 'runtime'};
  @override
  Future<void> enqueue(PendingUpload item) async {}
  @override
  Future<void> drain() async {}
  @override
  int get pendingCount => 0;
}

typedef _Runtime = ({
  AuthController auth,
  HopeSettingsController settings,
  ApplicationRegistry registry,
});

var _runtimeScreenshotSurfacePrepared = false;

Future<void> _prepareRuntimeScreenshotSurface(WidgetTester tester) async {
  if (_runtimeScreenshotSurfacePrepared) {
    return;
  }

  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  print('HOPE_SCREENSHOT_SURFACE_CONVERT_START');
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
  _runtimeScreenshotSurfacePrepared = true;
  print('HOPE_SCREENSHOT_SURFACE_CONVERT_DONE');
}

Future<void> _captureRuntimeScreenshot(
  WidgetTester tester,
  String marker,
) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;

  print('HOPE_SCREENSHOT_CAPTURE_START:$marker');

  if (_adbScreenshotCapture) {
    if (_screenshotSyncRoot.isEmpty) {
      throw StateError(
        'HOPE_SCREENSHOT_SYNC_ROOT is required for host synchronization.',
      );
    }
    final directory = Directory(_screenshotSyncRoot);
    await directory.create(recursive: true);

    // Use integration_test's native Android capture directly, rather than
    // relying on VM-service screenshot RPC or an external adb screencap.
    // This returns the actual rendered Flutter PNG bytes while the Flutter
    // surface is converted to the Android screenshot surface.
    final rawBytes =
        await integrationTestChannel.invokeMethod<List<dynamic>>(
      'captureScreenshot',
      <String, dynamic>{'name': marker},
    );
    if (rawBytes == null || rawBytes.isEmpty) {
      throw StateError('Android captureScreenshot returned no PNG bytes.');
    }
    final bytes = rawBytes.cast<int>();
    final screenshot = File('$_screenshotSyncRoot/$marker.png');
    await screenshot.writeAsBytes(bytes, flush: true);

    // The capture bytes are now materialized. Restore the Flutter surface
    // immediately so subsequent screens are not frozen on this ImageView.
    await integrationTestChannel.invokeMethod<void>('revertFlutterImage');
    await tester.pump();
    await tester.binding.endOfFrame;

    final request = File('$_screenshotSyncRoot/$marker.ready');
    if (await request.exists()) {
      await request.delete();
    }
    await request.writeAsString('ready', flush: true);
    print('HOPE_SCREENSHOT_READY:$marker');
    while (await request.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    try {
      await screenshot.delete();
    } catch (_) {}
    return;
  }

  await binding.takeScreenshot(marker);
  print('HOPE_SCREENSHOT_READY:$marker');
}

Future<void> _waitForRuntimeRenderToSettle(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final hasSpinner =
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
    final hasSkeleton =
        find.byType(SkeletonBox).evaluate().isNotEmpty;
    if (!hasSpinner && !hasSkeleton) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  final hasSpinner =
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
  final hasSkeleton =
      find.byType(SkeletonBox).evaluate().isNotEmpty;
  if (hasSpinner || hasSkeleton) {
    throw StateError(
      'Runtime render remained in loading/skeleton state after bounded settle',
    );
  }
}

Future<void> _captureRuntimeScreen(
  WidgetTester tester, {
  required _Runtime runtime,
  required Locale locale,
  required String marker,
  required Widget child,
}) async {
  // Rebuild the complete host for every screen. Flutter's Android screenshot
  // surface is a stateful image view; a full widget-tree rebuild prevents
  // stale layers from one complex screen leaking into the next capture.
  await tester.pumpWidget(
    _EvidenceHost(
      runtime: runtime,
      locale: locale,
      child: child,
    ),
  );
  await tester.pump();
  await tester.binding.endOfFrame;

  // Android's screenshot surface conversion creates the ImageView used by
  // integration_test. After each capture, revert it so the next pump can
  // render a fresh Flutter surface; otherwise ADB framebuffer screenshots
  // can remain frozen on the first converted frame.
  // In the native Android capture path, bypass the binding's private
  // surface-state bookkeeping and invoke the same supported platform-channel
  // methods directly. The binding API keeps an internal converted-state flag;
  // our app-side immediate revert must not leave that flag stale for the
  // next screen.
  if (_adbScreenshotCapture) {
    await integrationTestChannel.invokeMethod<void>(
      'convertFlutterSurfaceToImage',
    );
  } else {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.convertFlutterSurfaceToImage();
  }
  await tester.pump();
  await tester.binding.endOfFrame;

  await tester.pump(const Duration(milliseconds: 1200));
  await tester.binding.endOfFrame;
  await _waitForRuntimeRenderToSettle(tester);
  await tester.pump();
  await tester.binding.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 250));
  await tester.pump();
  await tester.binding.endOfFrame;

  await _captureRuntimeScreenshot(tester, marker);
}
Future<void> _signalRuntimeTestBodyComplete() async {
  if (!_adbScreenshotCapture || _screenshotSyncRoot.isEmpty) {
    return;
  }
  final marker = File('$_screenshotSyncRoot/test-complete.ready');
  await marker.writeAsString('complete', flush: true);
  print('HOPE_RUNTIME_TEST_BODY_COMPLETE');
}

Future<void> _captureBaselineLocale(
  WidgetTester tester, {
  required Locale locale,
  required String suffix,
  required _Runtime runtime,
}) async {
  final pages = <String, Widget Function()>{
    'home': () => const HomePage(),
    'jobs': () => const JobsPage(),
    'job-detail': () => JobDetailPage(job: _jobFixture()),
    'applications': () => const MyApplicationsPage(),
    'saved-searches': () => const SavedSearchesPage(),
    'transactions': () =>
        TransactionsPage(repository: runtime.registry.transactions),
    'transaction-detail': () => TransactionPage(
          repository: runtime.registry.transactions!,
          uploadQueue: _EvidenceUploadQueue(),
          jobId: 'job-runtime-1',
        ),
    'wallet': () => WalletPage(repository: runtime.registry.wallets!),
    'profile': () => const ProfilePage(),
    'notifications': () => const NotificationsPage(),
    'offers': () => const OffersPage(jobId: 'job-runtime-1'),
    'create-job': () => const CreateJobPage(),
    'login': () => const LoginPage(),
    'register': () => const RegisterPage(),
    'password-reset': () => const PasswordResetPage(),
  };
  for (final entry in pages.entries) {
    print('HOPE_RUNTIME_PAGE_START:${entry.key}-$suffix');
    await _captureRuntimeScreen(
      tester,
      runtime: runtime,
      locale: locale,
      marker: '${entry.key}-$suffix',
      child: entry.value(),
    );
    print('HOPE_RUNTIME_PAGE_DONE:${entry.key}-$suffix');
  }
}

Future<void> _captureResponsiveLocale(
  WidgetTester tester, {
  required Locale locale,
  required String suffix,
  required _Runtime runtime,
}) async {
  final pages = <String, Widget Function()>{
    'home': () => const HomePage(),
    'jobs': () => const JobsPage(),
    'job-detail': () => JobDetailPage(job: _jobFixture()),
    'transactions': () =>
        TransactionsPage(repository: runtime.registry.transactions),
    'wallet': () => WalletPage(repository: runtime.registry.wallets!),
    'profile': () => const ProfilePage(),
  };
  for (final entry in pages.entries) {
    print('HOPE_RUNTIME_PAGE_START:responsive-${entry.key}-$suffix');
    await _captureRuntimeScreen(
      tester,
      runtime: runtime,
      locale: locale,
      marker: 'responsive-720x1280-${entry.key}-$suffix',
      child: entry.value(),
    );
  }
}
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HOPE critical screens rendered screenshot evidence',
      (tester) async {
    final runtime = await _prepare();
    await tester.pumpWidget(
      _EvidenceHost(
        runtime: runtime,
        locale: _captureLocale == 'en' ? const Locale('en') : const Locale('fa'),
        child: const HomePage(),
      ),
    );
      if (_responsiveOnly) {
      if (_captureLocale != 'en') {
        await _captureResponsiveLocale(
          tester,
          runtime: runtime,
          locale: const Locale('fa'),
          suffix: 'fa-rtl',
        );
      }
      if (_captureLocale != 'fa') {
        await _captureResponsiveLocale(
          tester,
          runtime: runtime,
          locale: const Locale('en'),
          suffix: 'en-ltr',
        );
      }
      await _signalRuntimeTestBodyComplete();
      await Future<void>.delayed(const Duration(seconds: 1));
      return;
    }

    if (_captureLocale != 'en') {
      await _captureBaselineLocale(
        tester,
        runtime: runtime,
        locale: const Locale('fa'),
        suffix: 'fa-rtl',
      );
    }
    if (_captureLocale != 'fa') {
      await _captureBaselineLocale(
        tester,
        runtime: runtime,
        locale: const Locale('en'),
        suffix: 'en-ltr',
      );
    }
    await _signalRuntimeTestBodyComplete();
    await Future<void>.delayed(const Duration(seconds: 1));
  });
}
