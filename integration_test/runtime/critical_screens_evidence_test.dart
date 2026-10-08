// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:hope_mobile/core/application/application_registry.dart';
import 'package:hope_mobile/core/chat/chat_repository.dart';
import 'package:hope_mobile/core/financial/financial_insights_repository.dart';
import 'package:hope_mobile/core/jobs/job_satisfaction_repository.dart';
import 'package:hope_mobile/core/marketplace/employer_candidate_matching_repository.dart';
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
import 'package:hope_mobile/core/testing/runtime_render_settle.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/vazirmatn_loader.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/transactions/wallet_repository.dart';
import 'package:hope_mobile/core/uploads/upload_queue.dart';
import 'package:hope_mobile/features/applications/my_applications_page.dart';
import 'package:hope_mobile/features/chat/chat_page.dart';
import 'package:hope_mobile/features/financial/financial_insights_page.dart';
import 'package:hope_mobile/features/auth/login_page.dart';
import 'package:hope_mobile/features/auth/password_reset_page.dart';
import 'package:hope_mobile/features/auth/register_page.dart';
import 'package:hope_mobile/features/home/home_page.dart';
import 'package:hope_mobile/features/jobs/job_satisfaction_page.dart';
import 'package:hope_mobile/features/jobs/jobs_page.dart';
import 'package:hope_mobile/features/jobs/saved_searches_page.dart';
import 'package:hope_mobile/features/marketplace/create_job_page.dart';
import 'package:hope_mobile/features/marketplace/employer_candidate_matches_page.dart';
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
    _jobFixture(editorialMedia: true),
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

class _EvidenceFinancialInsightsRepository implements FinancialInsightsRepository {
  @override
  Future<HopeFinancialInsights> getInsights({int months = 6}) async =>
      HopeFinancialInsights.fromMap({
        'currency': 'TOMAN',
        'range': {'months': months},
        'summary': {
          'availableBalance': 2500000,
          'lockedBalance': 1000000,
          'totalInflow': 4200000,
          'totalOutflow': 1700000,
          'totalReserved': 1000000,
          'netCashFlow': 2500000,
        },
        'monthlyCashFlow': [
          {'month': '2026-04', 'label': 'فروردین', 'inflow': 600000, 'outflow': 240000, 'reserved': 200000, 'net': 360000},
          {'month': '2026-05', 'label': 'اردیبهشت', 'inflow': 900000, 'outflow': 380000, 'reserved': 250000, 'net': 520000},
          {'month': '2026-06', 'label': 'خرداد', 'inflow': 750000, 'outflow': 310000, 'reserved': 180000, 'net': 440000},
          {'month': '2026-07', 'label': 'تیر', 'inflow': 1100000, 'outflow': 420000, 'reserved': 220000, 'net': 680000},
          {'month': '2026-08', 'label': 'مرداد', 'inflow': 500000, 'outflow': 210000, 'reserved': 100000, 'net': 290000},
          {'month': '2026-09', 'label': 'شهریور', 'inflow': 350000, 'outflow': 140000, 'reserved': 50000, 'net': 210000},
        ],
        'balanceTrend': [
          {'date': '2026-04-01', 'balance': 1100000},
          {'date': '2026-05-01', 'balance': 1550000},
          {'date': '2026-06-01', 'balance': 1780000},
          {'date': '2026-07-01', 'balance': 2200000},
          {'date': '2026-08-01', 'balance': 2380000},
          {'date': '2026-09-01', 'balance': 2500000},
        ],
        'bySource': [
          {'source': 'JOB', 'credit': 3000000, 'debit': 1500000, 'amount': 1500000},
          {'source': 'MISSION', 'credit': 1200000, 'debit': 200000, 'amount': 1000000},
        ],
      });
}

class _EvidenceJobSatisfactionRepository implements JobSatisfactionRepository {
  @override
  Future<JobSatisfactionState> getState(String jobId) async =>
      JobSatisfactionState.fromMap({
        'jobId': jobId,
        'role': 'WORKER',
        'submitted': false,
        'questions': const [],
        'progress': {'submittedCount': 0, 'requiredCount': 2},
      });

  @override
  Future<Map<String, dynamic>> submit({
    required String jobId,
    required int overallRating,
    required bool completedAsAgreed,
    required int communicationRating,
    required String report,
  }) async =>
      const {};

  @override
  Future<List<HopeJobSatisfaction>> history() async => const [];
}

class _EvidenceChatRepository implements ChatRepository {
  final _conversation = const HopeChatConversation(
    id: 'chat-runtime-1',
    kind: 'JOB',
    jobId: 'job-runtime-1',
    status: 'OPEN',
    title: 'همکاری طراحی رابط موبایل',
    otherUserName: 'استودیو هُپ',
  );

  @override
  Future<List<HopeChatConversation>> listConversations() async =>
      [_conversation];

  @override
  Future<HopeChatThread> getMessages(String conversationId) async =>
      HopeChatThread(
        conversation: _conversation,
        messages: [
          HopeChatMessage(
            id: 'message-runtime-1',
            conversationId: conversationId,
            senderId: 'runtime-owner',
            senderName: 'استودیو هُپ',
            body: 'فایل‌های طراحی برای بازبینی آماده شد.',
            createdAt: DateTime.utc(2026, 9, 21, 6),
          ),
          HopeChatMessage(
            id: 'message-runtime-2',
            conversationId: conversationId,
            senderId: 'runtime-user',
            senderName: 'HOPE Runtime',
            body: 'دریافت شد؛ نسخه نهایی را بررسی می‌کنم.',
            createdAt: DateTime.utc(2026, 9, 21, 6, 4),
          ),
        ],
      );

  @override
  Future<HopeChatMessage> sendMessage(
    String conversationId,
    String message,
  ) async =>
      HopeChatMessage(
        id: 'message-runtime-3',
        conversationId: conversationId,
        senderId: 'runtime-user',
        senderName: 'HOPE Runtime',
        body: message,
        createdAt: DateTime.utc(2026, 9, 21, 6, 5),
      );
}

HopeEmployerCandidateMatchList _candidateMatchFixture() =>
    HopeEmployerCandidateMatchList.fromMap({
      'jobId': 'job-runtime-1',
      'kind': 'JOB',
      'candidates': [
        {
          'rank': 1,
          'userId': 'candidate-user-1',
          'displayName': 'دانا رضایی',
          'score': 92,
          'matchReasons': ['SKILL_MATCH', 'EXPERIENCE_MATCH', 'WORK_MODE_MATCH'],
          'matchComponents': {
            'skills': 96,
            'experience': 90,
            'location': 88,
            'salary': 94,
          },
          'application': {
            'id': 'application-runtime-1',
            'status': 'SHORTLISTED',
            'resumeHighlights': 'Flutter, Dart, accessibility',
            'skills': 'Flutter, Dart, UX',
          },
        },
        {
          'rank': 2,
          'userId': 'candidate-user-2',
          'displayName': 'نیما احمدی',
          'score': 87,
          'matchReasons': ['CATEGORY_MATCH', 'LOCATION_MATCH'],
          'matchComponents': {
            'skills': 88,
            'experience': 86,
            'location': 93,
          },
          'application': {
            'id': 'application-runtime-2',
            'status': 'PENDING',
            'skills': 'Flutter, UI',
          },
        },
      ],
    });

HopeJob _jobFixture({bool editorialMedia = false}) => HopeJob.fromMap({
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
      'isRecommended': true,
      'recommendationScore': 94,
      'recommendationReasons': [
        'SKILL_MATCH',
        'WORK_MODE_MATCH',
        'CATEGORY_MATCH',
      ],
      'recommendationComponents': {
        'skills': 96,
        'category': 100,
        'location': 88,
        'salary': 82,
      },
      'aiRecommendationConfidence': 0.92,
      // Runtime-only editorial media fixture: exercises the existing real media branch.
      if (editorialMedia)
        'imageUrl':
          'https://images.unsplash.com/photo-1758876022836-70b89d3e6944?auto=format&fit=crop&fm=jpg&q=60&w=1600',
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
        Provider<FinancialInsightsRepository>.value(value: _EvidenceFinancialInsightsRepository()),
        Provider<JobSatisfactionRepository>.value(value: _EvidenceJobSatisfactionRepository()),
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
        builder: (context, appChild) {
          final media = MediaQuery.of(context);
          return PremiumAppCanvas(
            child: MediaQuery(
              data: media.copyWith(disableAnimations: true),
              child: appChild!,
            ),
          );
        },
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

const _captureMode =
    String.fromEnvironment('HOPE_CAPTURE_MODE', defaultValue: 'baseline');
const _responsiveOnly =
    bool.fromEnvironment('HOPE_RESPONSIVE_ONLY', defaultValue: false);
const _captureLocale =
    String.fromEnvironment('HOPE_CAPTURE_LOCALE', defaultValue: '');
const _captureHomeOnly =
    bool.fromEnvironment('HOPE_CAPTURE_HOME_ONLY', defaultValue: false);
const _responsiveBatch =
    String.fromEnvironment('HOPE_RESPONSIVE_BATCH', defaultValue: 'all');
const _baselineBatch =
    String.fromEnvironment('HOPE_BASELINE_BATCH', defaultValue: 'all');
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

  // Android integration_test screenshots need the Flutter surface converted
  // before the first capture so the image comes from the Flutter render surface.
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  print('HOPE_SCREENSHOT_SURFACE_CONVERT_START');
  await binding.convertFlutterSurfaceToImage();
  await tester.pump();
  _runtimeScreenshotSurfacePrepared = true;
  print('HOPE_SCREENSHOT_SURFACE_CONVERT_DONE');
}

const _hopeRuntimeScreenshotChannel = MethodChannel('hope.runtime/screenshot');

Future<void> _captureHopeNativeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String marker,
) async {
  const integrationTestChannel =
      MethodChannel('plugins.flutter.io/integration_test');
  integrationTestChannel.setMethodCallHandler((call) async {
    if (call.method == 'scheduleFrame') {
      PlatformDispatcher.instance.scheduleFrame();
    }
  });

  final bytes = await _hopeRuntimeScreenshotChannel.invokeMethod<Uint8List>(
    'captureScreenshot',
    <String, Object?>{'name': marker},
  );
  if (bytes == null || bytes.isEmpty) {
    throw StateError('HOPE native screenshot returned no PNG bytes.');
  }

  binding.reportData ??= <String, dynamic>{};
  final screenshots =
      binding.reportData!['screenshots'] as List<dynamic>? ?? <dynamic>[];
  screenshots.add(<String, dynamic>{
    'screenshotName': marker,
    'bytes': bytes,
  });
  binding.reportData!['screenshots'] = screenshots;
}

Future<void> _captureRuntimeScreenshot(
  String marker, {
  bool useHopeNativeTransport = false,
}) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  print('HOPE_SCREENSHOT_CAPTURE_START:$marker');
  if (useHopeNativeTransport) {
    await _captureHopeNativeScreenshot(binding, marker);
    print('HOPE_SCREENSHOT_SOURCE:flutter-driver:onScreenshot-custom-native:$marker');
  } else {
    try {
      await binding.takeScreenshot(marker).timeout(const Duration(seconds: 12));
      print('HOPE_SCREENSHOT_SOURCE:flutter-driver:$marker');
    } on TimeoutException catch (error) {
      print('HOPE_SCREENSHOT_FLUTTER_DRIVER_TIMEOUT:$marker:$error');
      // Keep the proven Flutter-driver path as the primary transport, but do
      // not let one stalled screenshot RPC strand the whole evidence session.
      await _captureHopeNativeScreenshot(binding, marker);
      print('HOPE_SCREENSHOT_SOURCE:flutter-driver:onScreenshot-native-fallback:$marker');
    }
  }
  print('HOPE_SCREENSHOT_READY:$marker');
}

Future<void> _signalRuntimeTestBodyComplete() async {
  print('HOPE_RUNTIME_TEST_BODY_COMPLETE');
}
Future<void> _waitForRuntimeRenderToSettle(WidgetTester tester) async {
  // WidgetTester frame completion does not always mean the Android raster thread
  // has committed the new surface. Give the engine several real frame turns.
  // HopeAsyncState can intentionally render a static loading surface when
  // animations are disabled, so it must participate in the same bounded wait.
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  for (var attempt = 0; attempt < 100; attempt++) {
    final hasSpinner =
        find.byWidgetPredicate(isBlockingRuntimeProgressIndicator).evaluate().isNotEmpty;
    final hasSkeleton =
        find.byType(SkeletonBox).evaluate().isNotEmpty;
    final hasAsyncLoading = find.byWidgetPredicate(
      (widget) => widget is HopeAsyncState && widget.kind == HopeStateKind.loading,
    ).evaluate().isNotEmpty;
    if (!hasSpinner && !hasSkeleton && !hasAsyncLoading) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  final hasSpinner =
      find.byWidgetPredicate(isBlockingRuntimeProgressIndicator).evaluate().isNotEmpty;
  final hasSkeleton =
      find.byType(SkeletonBox).evaluate().isNotEmpty;
  final hasAsyncLoading = find.byWidgetPredicate(
    (widget) => widget is HopeAsyncState && widget.kind == HopeStateKind.loading,
  ).evaluate().isNotEmpty;
  if (hasSpinner || hasSkeleton || hasAsyncLoading) {
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
  // Rebuild the complete host for every screen and explicitly settle the
  // rendered frame before asking integration_test for the device screenshot.
  await tester.pumpWidget(
    _EvidenceHost(
      runtime: runtime,
      locale: locale,
      child: child,
    ),
  );
  // Prepare the Android image surface only after the first target page is mounted.
  // Preparing it on the initial Home host and then rebuilding Login before the
  // first capture can leave the native image surface without a committed frame.
  await _prepareRuntimeScreenshotSurface(tester);
  print('HOPE_RUNTIME_SCREEN_PUMP_DONE:$marker');
  if (child is LoginPage) {
    // _prepareRuntimeScreenshotSurface already commits one frame after the
    // Android surface conversion. A second timed pump at this boundary has
    // repeatedly stalled the headless VM-service driver before takeScreenshot.
    // Capture immediately after the proven surface-commit boundary.
    print('HOPE_RUNTIME_LOGIN_DIRECT_CAPTURE:$marker');
    await _captureRuntimeScreenshot(marker);
    return;
  }
  // Register can legitimately keep an indeterminate auth-state indicator alive
  // in the isolated evidence host. The Android surface preparation above already
  // commits the first target frame; an additional timed/async settle can stall the
  // headless VM-service boundary (seen on current-head runtime evidence).
  // Capture immediately after the proven surface-commit boundary, like Login.
  if (child is RegisterPage) {
    print('HOPE_RUNTIME_REGISTER_DIRECT_CAPTURE:$marker');
    await _captureRuntimeScreenshot(marker);
    return;
  }
  // PasswordResetPage is a static auth surface. Surface preparation above
  // already commits the initial target frame, so keep the capture boundary
  // deterministic and avoid an extra timed/async pump.
  if (child is PasswordResetPage) {
    print('HOPE_RUNTIME_PASSWORD_RESET_DIRECT_CAPTURE:$marker');
    await _captureRuntimeScreenshot(marker);
    return;
  }
  // WalletPage can hit the same headless VM-service boundary as the
  // TransactionsPage: a zero-duration pump immediately after the page build
  // can dispose the driver before the Flutter screenshot request. Keep the
  // settle path deterministic and avoid that boundary for this surface.
  if (child is WalletPage) {
    // WalletPage starts its repository load from initState. The runtime host
    // disables animations, which makes HopeAsyncState render a static loading
    // surface instead of a spinner; use the canonical bounded settle so the
    // evidence boundary waits on the actual loading state without changing
    // product behavior.
    await _waitForRuntimeRenderToSettle(tester);
    final loadedLabel = locale.languageCode == 'fa'
        ? 'قابل استفاده'
        : 'Available';
    if (find.text(loadedLabel).evaluate().isEmpty) {
      throw StateError(
        'Runtime Wallet capture reached screenshot boundary before the loaded financial state.',
      );
    }
    print('HOPE_RUNTIME_WALLET_LOADED_STATE_ASSERTED:$marker');
    await _captureRuntimeScreenshot(marker);
    return;
  }
  // TransactionsPage is the heaviest current Work Center surface. A second
  // zero-duration pump can block the headless driver before the screenshot
  // request; give this page one deterministic 1.2s frame window instead.
  if (child is TransactionsPage) {
    // TransactionsPage materializes its FutureBuilder one frame after the
    // initial host build. Give the Flutter raster thread several committed
    // frame turns before requesting the Android surface image.
    await tester.pump(const Duration(milliseconds: 1800));
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    print('HOPE_RUNTIME_TRANSACTION_FAST_SETTLE_DONE:$marker');
    await _captureRuntimeScreenshot(marker);
    return;
  }
  await tester.pump();

  await tester.pump(const Duration(milliseconds: 1200));
  await _waitForRuntimeRenderToSettle(tester);
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  await _captureRuntimeScreenshot(marker);
}

Future<void> _captureBaselineLocale(
  WidgetTester tester, {
  required Locale locale,
  required String suffix,
  required _Runtime runtime,
}) async {
  // Risk-first baseline ordering: unresolved auth capture runs before the
  // already-proven discovery/work surfaces, so a transport regression fails
  // early instead of consuming several successful sessions first.
  final pages = <String, Widget Function()>{
    'login': () => const LoginPage(),
    'home': () => const HomePage(),
    'jobs': () => const JobsPage(),
    'job-detail': () => JobDetailPage(job: _jobFixture(editorialMedia: true)),
    'applications': () => const MyApplicationsPage(),
    'saved-searches': () => const SavedSearchesPage(),
    'transactions': () =>
        TransactionsPage(repository: runtime.registry.transactions),
    'wallet': () => WalletPage(repository: runtime.registry.wallets!),
    'transaction-detail': () => TransactionPage(
          repository: runtime.registry.transactions!,
          uploadQueue: _EvidenceUploadQueue(),
          jobId: 'job-runtime-1',
        ),
    'profile': () => const ProfilePage(),
    'notifications': () => const NotificationsPage(),
    'offers': () => const OffersPage(jobId: 'job-runtime-1'),
    'create-job': () => const CreateJobPage(),
    'register': () => const RegisterPage(),
    'password-reset': () => const PasswordResetPage(),
    // Extended visual-wave targets captured in addition to the 15 core baseline pages.
    'financial-insights': () => const FinancialInsightsPage(),
    'job-satisfaction': () => const JobSatisfactionPage(jobId: 'job-runtime-1'),
    'candidate-matches': () => EmployerCandidateMatchesPage(
          data: _candidateMatchFixture(),
          onRetry: () {},
        ),
    'chat': () => ChatPage(
          repository: _EvidenceChatRepository(),
          jobId: 'job-runtime-1',
        ),
  };
  final capturePages = _captureHomeOnly
      ? <String, Widget Function()>{'home': () => const HomePage()}
      : _responsiveBatch == '1'
          ? Map<String, Widget Function()>.fromEntries(
              pages.entries.take(3),
            )
          : _responsiveBatch == '2'
              ? Map<String, Widget Function()>.fromEntries(
                  pages.entries.skip(3).take(3),
                )
              : _responsiveBatch == '3'
                  ? Map<String, Widget Function()>.fromEntries(
                      pages.entries.skip(6).take(2),
                    )
              : _baselineBatch == 'a'
                  ? Map<String, Widget Function()>.fromEntries(
                      pages.entries.take(7),
                    )
                  : _baselineBatch == 'b'
                      ? Map<String, Widget Function()>.fromEntries(
                          pages.entries.skip(7).take(1),
                        )
                      : _baselineBatch == 'c'
                          ? Map<String, Widget Function()>.fromEntries(
                              pages.entries.skip(8).take(4),
                            )
                          : _baselineBatch == 'd'
                              ? Map<String, Widget Function()>.fromEntries(
                                  pages.entries.skip(12).take(3),
                                )
                              : pages;
  for (final entry in capturePages.entries) {
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
    'job-detail': () => JobDetailPage(job: _jobFixture(editorialMedia: true)),
    'transactions': () =>
        TransactionsPage(repository: runtime.registry.transactions),
    'wallet': () => WalletPage(repository: runtime.registry.wallets!),
    'profile': () => const ProfilePage(),
  };
  final capturePages = _captureHomeOnly
      ? <String, Widget Function()>{'home': () => const HomePage()}
      : _responsiveBatch == '1'
          ? Map<String, Widget Function()>.fromEntries(pages.entries.take(3))
          : _responsiveBatch == '2'
              ? Map<String, Widget Function()>.fromEntries(pages.entries.skip(3).take(1))
              : _responsiveBatch == '3'
                  ? Map<String, Widget Function()>.fromEntries(pages.entries.skip(4).take(2))
                  : pages;
  for (final entry in capturePages.entries) {
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
  if (_captureLocale != 'fa' && _captureLocale != 'en') {
    throw StateError(
      'HOPE_CAPTURE_LOCALE must be supplied as fa or en for exact-locale runtime evidence.',
    );
  }
  print('HOPE_RUNTIME_CAPTURE_LOCALE:$_captureLocale');

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
    print('HOPE_RUNTIME_HOST_PUMP_DONE');
    // Surface preparation is deferred until the first target screen is mounted.
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
      // Keep the final responsive surface mounted for a deterministic frame
      // window so any deferred layout assertion retains its active widget creator.
      await tester.pump(const Duration(seconds: 2));
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
