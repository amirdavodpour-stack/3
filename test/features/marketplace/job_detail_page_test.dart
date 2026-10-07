import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/marketplace/job_detail_repository.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/theme_controller.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/uploads/upload_queue.dart';
import 'package:hope_mobile/features/marketplace/job_detail_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/features/transactions/transaction_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// Behavior tests for the job detail page: mission vs job rendering, owner
/// candidate pipeline, owner transaction navigation, non-owner candidate
/// suppression. Fresh fakes per test, no network.
class _FakeDetail implements JobDetailRepository {
  _FakeDetail({
    this.candidates = const [],
    this.compareResult = const {},
  });

  List<HopeCandidate> candidates;
  final Map<String, dynamic> compareResult;
  final List<String> calls = [];
  Completer<void>? candidateGate;

  @override
  Future<List<HopeCandidate>> listCandidates(String jobId) async => candidates;

  @override
  Future<HopeApplication> applyToJob(String jobId,
      {required String resumeText, required String skills}) async {
    calls.add('apply:$jobId');
    return HopeApplication.fromMap(
        {'id': 'app1', 'jobId': jobId, 'jobTitle': 't', 'status': 'PENDING'});
  }

  @override
  Future<HopeOffer> submitOffer(String jobId,
      {required String price, required String message}) async {
    calls.add('offer:$jobId:$price');
    return HopeOffer.fromMap({
      'id': 'o1',
      'jobId': jobId,
      'providerId': 'u1',
      'price': price,
      'message': message,
      'status': 'PENDING'
    });
  }

  @override
  Future<void> candidateAction(
      String jobId, String candidateId, String action) async {
    calls.add('candidate:$candidateId:$action');
    if (candidateGate != null) await candidateGate!.future;
  }

  @override
  Future<Map<String, dynamic>> compareCandidates(
          String jobId, List<String> applicationIds) async =>
      compareResult;

  @override
  Future<void> reportJob(String jobId,
      {required String reason, String details = ''}) async {}
}

class _FakeTx implements TransactionRepository {
  @override
  Future<List<HopeJob>> listMyJobs() async => [];
  @override
  Future<HopePayment> getPayment(String id) async => HopePayment(
        id: 'p1',
        status: 'FUNDED',
        amount: '1000000',
        providerRef: 'r1',
        job: _job(kind: 'MISSION', ownerId: 'u1'),
        fees: const HopePaymentFees(
          baseAmount: '1000000',
          employerFee: '100000',
          workerFee: '100000',
          platformFee: '100000',
          employerCharge: '1100000',
          providerPayout: '900000',
          policyVersion: 'v1',
          currency: 'TOMAN',
        ),
      );
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

class _FakeQueue implements UploadQueue {
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
      <String, String>{'key': 'k1'};
  @override
  Future<void> enqueue(PendingUpload item) async {}
  @override
  Future<void> drain() async {}
  @override
  int get pendingCount => 0;
}

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

HopeJob _job({
  String id = 'j1',
  String kind = 'MISSION',
  String visibility = 'PUBLIC',
  String? ownerId = 'u1',
  String? city = 'Tehran',
  String? title,
  String status = 'PUBLISHED',
}) =>
    HopeJob.fromMap({
      'id': id,
      'title': title ?? (kind == 'JOB' ? 'Flutter developer' : 'Design a logo'),
      'description': 'A clear, concise deliverable description for the page.',
      'categoryId': 'c1',
      'category': 'Design',
      'jobType': kind == 'JOB' ? 'HOURLY' : 'FIXED',
      'budgetType': 'FIXED',
      'budgetMin': '1000000',
      'budgetMax': '1500000',
      'duration': '8',
      'acceptanceCriteria': 'Acceptance criteria are listed here.',
      'status': status,
      'ownerId': ownerId,
      'providerId': 'p1',
      'city': city,
      'kind': kind,
      'visibility': visibility,
      'schedule': kind == 'JOB' ? 'FULL_TIME' : null,
      'monthlySalary': kind == 'JOB' ? '12000000' : null,
      'applicationDeadline': kind == 'JOB' ? '2026-09-30' : null,
      'offerCount': 0,
      'isOwner': false,
      'distanceKm': null,
      'isRecommended': true,
      'recommendationScore': 94,
      'recommendationReasons': ['SKILL_MATCH', 'WORK_MODE_MATCH', 'CATEGORY_MATCH'],
       'recommendationComponents': {
         'skills': 96,
         'category': 100,
         'location': 88,
         'salary': 82,
       },
       'aiRecommendationConfidence': 0.92,
    });

Future<void> _pump(
  WidgetTester tester, {
  required HopeJob job,
  _FakeDetail? detail,
  String userId = 'u9',
  double width = 900,
  double height = 3400,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  await settings.setLanguage('en');
  final auth = AuthController(_AuthRepo(), SecureStore());
  await auth.applyRefreshedUser({'id': userId, 'displayName': 'Ali'});

  // Providers sit ABOVE the MaterialApp so routes pushed onto the app
  // Navigator (e.g. TransactionPage) resolve them.
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider(create: (_) => ThemeController(settings)),
      ChangeNotifierProvider.value(value: auth),
      Provider<JobDetailRepository>.value(value: detail ?? _FakeDetail()),
      Provider<TransactionRepository>.value(value: _FakeTx()),
      Provider<UploadQueue>.value(value: _FakeQueue()),
    ],
    child: MaterialApp(
      theme: ThemeData.light(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('fa')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: JobDetailPage(job: job),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mission details render pricing, duration and action entry',
      (tester) async {
    await _pump(tester, job: _job());
    expect(find.text('Job description'), findsOneWidget);
    expect(
      tester.widget<JobDetailPage>(find.byType(JobDetailPage)).job.title,
      'Design a logo',
    );
    expect(find.text('Budget'), findsOneWidget);
    expect(find.textContaining('TOMAN'), findsWidgets);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('View financial flow'), findsNothing);
    expect(find.textContaining('reviewed by an admin'), findsNothing);
  });

  testWidgets('job details render monthly pay, deadline and admin banner',
      (tester) async {
    await _pump(tester, job: _job(kind: 'JOB'));
    expect(find.text('Job description'), findsOneWidget);
    expect(
      tester.widget<JobDetailPage>(find.byType(JobDetailPage)).job.title,
      'Flutter developer',
    );
    expect(find.text('Monthly pay'), findsOneWidget);
    expect(find.textContaining('TOMAN'), findsWidgets);
    expect(find.textContaining('2026-09-30'), findsOneWidget);
    expect(find.textContaining('reviewed by an admin'), findsOneWidget);
    expect(find.text('View financial flow'), findsNothing);
  });

  testWidgets('match breakdown compresses into a two-column decision grid on compact mobile',
      (tester) async {
    await _pump(tester, job: _job(), width: 390, height: 844);

    final skills = find.byKey(const ValueKey('match-breakdown-skills'));
    final category = find.byKey(const ValueKey('match-breakdown-category'));
    final location = find.byKey(const ValueKey('match-breakdown-location'));
    final salary = find.byKey(const ValueKey('match-breakdown-salary'));
    expect(skills, findsOneWidget);
    expect(category, findsOneWidget);
    expect(location, findsOneWidget);
    expect(salary, findsOneWidget);
    expect(
      (tester.getTopLeft(category).dy - tester.getTopLeft(skills).dy).abs(),
      lessThan(90),
    );
    expect(
      (tester.getTopLeft(salary).dy - tester.getTopLeft(location).dy).abs(),
      lessThan(90),
    );
  });

  testWidgets('opportunity hero preserves a stronger editorial focal height',
      (tester) async {
    await _pump(tester, job: _job());
    final hero = find.byType(PremiumHero);
    expect(hero, findsOneWidget);
    expect(tester.getSize(hero).height, greaterThanOrEqualTo(180));
  });

  testWidgets(
      'compact opportunity detail keeps a painted match surface in the tight runtime viewport',
      (tester) async {
    await _pump(tester, job: _job(), width: 274, height: 457);

    final match = find.byKey(
      const ValueKey('opportunity-match-intelligence-compact-surface'),
    );
    final hero = find.byType(PremiumHero);
    expect(match, findsOneWidget);
    final matchBoundary = find.byKey(
      const ValueKey('opportunity-match-intelligence-compact-boundary'),
    );
    expect(matchBoundary, findsOneWidget);
    expect(tester.getSize(matchBoundary).height, greaterThanOrEqualTo(160));
    expect(tester.getSize(hero).height, lessThanOrEqualTo(180));
    expect(find.text('94% Match'), findsOneWidget);
    expect(find.text('Match intelligence'), findsOneWidget);
    expect(tester.getTopLeft(match).dy, lessThan(280));
    expect(tester.getSize(match).height, greaterThanOrEqualTo(160));
    expect(tester.getSize(match).width, greaterThan(240));
    expect(find.text('Match signals'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long opportunity titles stay contained in the hero',
      (tester) async {
    await _pump(
      tester,
      job: _job(
        title:
            'طراحی و پیاده‌سازی کامل رابط کاربری اپلیکیشن بازار کار برای موبایل',
      ),
    );

    final title = find.textContaining('طراحی و پیاده‌سازی کامل');
    expect(title, findsOneWidget);
    final widget = tester.widget<Text>(title);
    expect(widget.maxLines, 2);
    expect(widget.overflow, TextOverflow.ellipsis);
  });

  testWidgets('owner job with forwarded candidates renders candidate actions',
      (tester) async {
    final detail = _FakeDetail(candidates: const [
      HopeCandidate(
          id: 'c1',
          skills: 'Flutter',
          resumeText: 'Cross-platform experience.',
          status: 'FORWARDED'),
      HopeCandidate(
          id: 'c2',
          skills: 'Dart',
          resumeText: 'Backend experience.',
          status: 'OFFERED'),
    ]);
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1'),
      detail: detail,
      userId: 'u1',
    );

    await tester.ensureVisible(find.text('Forwarded candidates'));
    expect(find.text('Forwarded candidates'), findsOneWidget);
    expect(find.text('Anonymous candidate'), findsNWidgets(2));
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Interview'), findsOneWidget);
    expect(find.text('Hire'), findsOneWidget);

    // A candidate action is serialized across the whole pipeline; another
    // candidate cannot submit a concurrent transition while one is pending.
    detail.candidateGate = Completer<void>();
    await tester.ensureVisible(find.text('Interview'));
    await tester.tap(find.text('Interview'));
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Interview')).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hire')).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Compare')).onPressed,
      isNull,
    );
    detail.candidateGate!.complete();
    await tester.pumpAndSettle();
    expect(detail.calls, contains('candidate:c1:interview'));

    await tester.ensureVisible(find.text('Interview'));
    await tester.tap(find.text('Interview'));
    await tester.pumpAndSettle();
    expect(detail.calls, contains('candidate:c1:interview'));

    await tester.ensureVisible(find.text('Hire'));
    await tester.tap(find.text('Hire'));
    await tester.pumpAndSettle();
    expect(detail.calls, contains('candidate:c2:hire'));
  });

  testWidgets('candidate comparison localizes backend status enums', (tester) async {
    final detail = _FakeDetail(
      candidates: const [
        HopeCandidate(
          id: 'c1',
          skills: 'Flutter',
          resumeText: 'Cross-platform experience.',
          status: 'FORWARDED',
        ),
        HopeCandidate(
          id: 'c2',
          skills: 'Dart',
          resumeText: 'Backend experience.',
          status: 'OFFERED',
        ),
      ],
      compareResult: {
        'candidates': [
          {
            'skills': 'Flutter',
            'resumeHighlights': 'Cross-platform experience.',
            'status': 'OFFERED',
          },
        ],
      },
    );
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1'),
      detail: detail,
      userId: 'u1',
    );

    await tester.ensureVisible(find.text('Compare'));
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Offer sent'),
      ),
      findsOneWidget,
    );
    expect(find.text('OFFERED'), findsNothing);
  });

  testWidgets(
      'match intelligence exposes four visual breakdown bars and a trust note',
      (tester) async {
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1'),
      userId: 'u9',
    );

    expect(find.byKey(const ValueKey('match-breakdown-skills')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-breakdown-category')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-breakdown-location')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-breakdown-salary')), findsOneWidget);
    expect(find.text('92% confidence'), findsOneWidget);
    expect(find.text('Match signals'), findsOneWidget);
  });

  testWidgets('match intelligence opens a detailed evidence sheet', (tester) async {
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1'),
      userId: 'u9',
    );

    expect(find.text('Match intelligence'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('opportunity-match-intelligence')));
    await tester.pumpAndSettle();

    expect(find.text('Why this opportunity fits'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Match signals'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Skill match')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Work mode fit')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Category match')),
      findsOneWidget,
    );
    expect(find.text('94%'), findsWidgets);
  });

  testWidgets(
      'opportunity snapshot renders as a compact flat fact strip',
      (tester) async {
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1'),
      userId: 'u9',
    );

    expect(find.byKey(const ValueKey('opportunity-snapshot-facts')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-snapshot-fact-budget')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-snapshot-fact-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-snapshot-fact-location')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-snapshot-fact-deadline')), findsOneWidget);
  });

  testWidgets('unknown job lifecycle status is presented safely', (tester) async {
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1', status: 'FUTURE_STATE'),
      userId: 'u1',
    );

    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('FUTURE_STATE'), findsNothing);
  });
  testWidgets('unknown lifecycle status does not mark a stage complete', (tester) async {
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1', status: 'FUTURE_STATE'),
      userId: 'u1',
    );

    final draft = tester.widget<Text>(find.text('Draft'));
    expect(draft.style?.fontWeight, isNot(FontWeight.w800));
    expect(find.text('Needs review'), findsOneWidget);
  });

  testWidgets('non-owner never sees the candidate pipeline', (tester) async {
    final detail = _FakeDetail(candidates: const [
      HopeCandidate(
          id: 'c1',
          skills: 'Flutter',
          resumeText: 'Cross-platform experience.',
          status: 'FORWARDED'),
    ]);
    await _pump(
      tester,
      job: _job(kind: 'JOB', ownerId: 'u1'),
      detail: detail,
      userId: 'u-other',
    );
    expect(find.text('Forwarded candidates'), findsNothing);
    expect(detail.calls, isEmpty);
  });

  testWidgets('owner mission opens the transaction route intent',
      (tester) async {
    await _pump(tester,
        job: _job(kind: 'MISSION', ownerId: 'u1'), userId: 'u1');
    expect(find.byType(TransactionPage), findsNothing);
    await tester.tap(find.text('View financial flow'));
    await tester.pumpAndSettle();
    // Navigation intent reached the transaction route and the transaction
    // page renders the funded payment.
    expect(find.byType(TransactionPage), findsOneWidget);
  });

  // Runtime certification trigger: Wave G-3A compact Match Intelligence.
}
