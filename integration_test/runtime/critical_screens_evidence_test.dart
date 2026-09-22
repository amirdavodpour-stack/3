// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
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
          baseAmount: 1500000,
          employerFee: 30000,
          workerFee: 15000,
          platformFee: 15000,
          employerCharge: 1530000,
          providerPayout: 1485000,
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
  final _jobs = <HopeJob>[_jobFixture()];

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

Future<({AuthController auth, HopeSettingsController settings, ApplicationRegistry registry})>
    _prepare() async {
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(_EvidenceAuthRepository(), SecureStore());
  await auth.applyRefreshedUser({
    'id': 'runtime-user',
    'displayName': 'HOPE Runtime',
    'email': 'runtime@example.invalid',
  });
  return (auth: auth, settings: settings, registry: _registry());
}

Widget _host({
  required Locale locale,
  required Widget child,
  required AuthController auth,
  required HopeSettingsController settings,
  required ApplicationRegistry registry,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<HopeSettingsController>.value(value: settings),
      ChangeNotifierProvider<ThemeController>(
        create: (_) => ThemeController(settings),
      ),
      ChangeNotifierProvider<AuthController>.value(value: auth),
      Provider<ApplicationRegistry>.value(value: registry),
      Provider<MarketplaceRepository>.value(value: registry.marketplace!),
      Provider<JobDetailRepository>.value(value: registry.jobDetail!),
      Provider<TransactionRepository>.value(value: registry.transactions!),
      Provider<WalletRepository>.value(value: registry.wallets!),
      Provider<SavedSearchRepository>.value(value: registry.savedSearches),
      Provider<ProfileRepository>.value(value: registry.profile!),
      Provider<NotificationRepository>.value(value: registry.notifications!),
      Provider<OfferRepository>.value(value: _EvidenceOfferRepository()),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.light(),
      home: child,
    ),
  );
}

Future<void> _render(
  WidgetTester tester, {
  required String marker,
  required Locale locale,
  required Widget child,
  required AuthController auth,
  required HopeSettingsController settings,
  required ApplicationRegistry registry,
}) async {
  print('HOPE_SCREEN_STARTED:$marker');
  await tester.pumpWidget(
    _host(
      locale: locale,
      child: child,
      auth: auth,
      settings: settings,
      registry: registry,
    ),
  );
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pump();
  print('HOPE_SCREENSHOT_READY:$marker');
  await Future<void>.delayed(const Duration(milliseconds: 600));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HOPE critical screens rendered evidence — fa RTL and en LTR',
      (tester) async {
    final prepared = await _prepare();
    final uploadQueue = UploadQueue(
      ApiClient(SecureStore(), baseUrl: 'https://example.invalid'),
    );

    final screens = <String, Widget Function()>{
      'home': () => const HomePage(),
      'jobs': () => const JobsPage(),
      'job-detail': () => JobDetailPage(job: _jobFixture()),
      'applications': () => const MyApplicationsPage(),
      'saved-searches': () => const SavedSearchesPage(),
      'transactions': () => TransactionsPage(
            repository: prepared.registry.transactions,
          ),
      'transaction-detail': () => TransactionPage(
            repository: prepared.registry.transactions!,
            uploadQueue: uploadQueue,
            jobId: 'job-runtime-1',
          ),
      'wallet': () => WalletPage(repository: prepared.registry.wallets!),
      'profile': () => const ProfilePage(),
      'notifications': () => const NotificationsPage(),
      'offers': () => const OffersPage(jobId: 'job-runtime-1'),
      'create-job': () => const CreateJobPage(),
    };

    for (final locale in const [Locale('fa'), Locale('en')]) {
      final suffix = locale.languageCode == 'fa' ? 'fa-rtl' : 'en-ltr';
      for (final entry in screens.entries) {
        await _render(
          tester,
          marker: '${entry.key}-$suffix',
          locale: locale,
          child: entry.value(),
          auth: prepared.auth,
          settings: prepared.settings,
          registry: prepared.registry,
        );
      }
      await _render(
        tester,
        marker: 'login-$suffix',
        locale: locale,
        child: const LoginPage(),
        auth: prepared.auth,
        settings: prepared.settings,
        registry: prepared.registry,
      );
      await _render(
        tester,
        marker: 'register-$suffix',
        locale: locale,
        child: const RegisterPage(),
        auth: prepared.auth,
        settings: prepared.settings,
        registry: prepared.registry,
      );
      await _render(
        tester,
        marker: 'password-reset-$suffix',
        locale: locale,
        child: const PasswordResetPage(),
        auth: prepared.auth,
        settings: prepared.settings,
        registry: prepared.registry,
      );
    }
  });
}
