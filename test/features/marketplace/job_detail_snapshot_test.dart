import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/features/marketplace/job_detail_page.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/job_detail_repository.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/uploads/upload_queue.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class _AuthRepo implements AuthRepository {
  @override Future<AuthSession> loginWithGoogle(String _) => throw UnimplementedError();
  @override Future<AuthSession> login(String _, String __) => throw UnimplementedError();
  @override Future<AuthSession> register(String _, String __, String ___) => throw UnimplementedError();
  @override Future<void> logout() async {}
  @override Future<void> requestPasswordReset(String _) async {}
}

class _DetailRepo implements JobDetailRepository {
  @override
  Future<List<HopeCandidate>> listCandidates(String _) async => const [];
  @override
  Future<HopeApplication> applyToJob(String _, {required String resumeText, required String skills}) => throw UnimplementedError();
  @override
  Future<HopeOffer> submitOffer(String _, {required String price, required String message}) => throw UnimplementedError();
  @override
  Future<void> candidateAction(String _, String __, String ___) async {}
  @override
  Future<Map<String, dynamic>> compareCandidates(String _, List<String> __) async => const {};
  @override
  Future<void> reportJob(String _, {required String reason, String details = ''}) async {}
}

class _TxRepo implements TransactionRepository {
  @override Future<List<HopeJob>> listMyJobs() async => [];
  @override Future<HopePayment> getPayment(String _) => throw UnimplementedError();
  @override Future<HopePayment> fundPayment(String _, {String? idempotencyKey}) => throw UnimplementedError();
  @override Future<HopePayment> refundPayment(String _) => throw UnimplementedError();
  @override Future<HopePayment> releasePayment(String _) => throw UnimplementedError();
  @override Future<HopeJob> startJob(String _) => throw UnimplementedError();
  @override Future<HopeJob> deliverJob(String _) => throw UnimplementedError();
  @override Future<HopeJob> acceptJob(String _) => throw UnimplementedError();
  @override Future<void> submitEvidence(String _, {required String uri, required String notes, required String type}) async {}
}

class _Queue implements UploadQueue {
  @override late final ApiClient api;
  @override int get maxAttempts => 1;
  @override void Function(PendingUpload item, Object error)? onPermanentFailure;
  @override void Function(PendingUpload item, Object error)? onTransientFailure;
  @override Future<dynamic> uploadNowWithRetry(String _, File __) async => {};
  @override Future<void> enqueue(PendingUpload _) async {}
  @override Future<void> drain() async {}
  @override int get pendingCount => 0;
}

HopeJob _job() => HopeJob.fromMap(const {
  'id': 'j1',
  'title': 'Design a logo',
  'description': 'A clear deliverable description.',
  'categoryId': 'design',
  'category': 'Design',
  'budgetType': 'FIXED',
  'budgetMin': '1000000',
  'budgetMax': '1500000',
  'duration': '8',
  'acceptanceCriteria': 'Acceptance criteria',
  'status': 'PUBLISHED',
  'ownerId': 'owner',
  'providerId': 'worker',
  'city': 'Tehran',
  'kind': 'MISSION',
  'visibility': 'PUBLIC',
  'recommendationScore': 94,
  'recommendationComponents': {
    'skills': 0.98,
    'category': 0.93,
    'location': 0.94,
    'salary': 0.87,
  },
  'recommendationReasons': [
    'SKILL_MATCH',
    'WORK_MODE_MATCH',
    'NEARBY',
  ],
});

void main() {
  testWidgets('opportunity detail keeps duplicate core facts below primary context',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final auth = AuthController(_AuthRepo(), SecureStore());
    await auth.applyRefreshedUser({'id': 'worker', 'displayName': 'Worker'});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<JobDetailRepository>.value(value: _DetailRepo()),
          Provider<TransactionRepository>.value(value: _TxRepo()),
          Provider<UploadQueue>.value(value: _Queue()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: JobDetailPage(job: _job()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('خلاصه فرصت'), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-detail-hero-match')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('opportunity-detail-hero-budget')),
      findsNothing,
    );
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Field'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);

    final heroSize = tester.getSize(find.byType(PremiumHero).first);
    expect(heroSize.height, lessThanOrEqualTo(180));

    final snapshotTop = tester.getTopLeft(find.text('خلاصه فرصت')).dy;
    final descriptionTop = tester.getTopLeft(find.text('A clear deliverable description.')).dy;
    expect(descriptionTop, lessThan(snapshotTop));
  });

  testWidgets('premium hero domain marker stays bounded on compact RTL surfaces',
    (tester) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(240, 640)),
      child: MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(20),
              child: PremiumHero(
                eyebrow: 'ماموریت',
                title: 'طراحی رابط موبایل حرفه‌ای',
                message: 'Software • تهران',
                icon: Icons.work_outline,
                domain: HopeProductDomain.discovery,
                height: 146,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(tester.getSize(find.byType(PremiumHero)).height, 176);
  expect(tester.takeException(), isNull);
});

}
