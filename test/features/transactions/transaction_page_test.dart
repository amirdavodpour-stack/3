import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/uploads/upload_queue.dart';
import 'package:hope_mobile/features/transactions/transaction_page.dart';
import 'package:hope_mobile/core/ui/brand.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// Behavior tests for the transaction page: loading, error + retry, funded
/// start, financial details, refund gate (owner only) and settled-completion
/// states. Each test builds its own fake transaction repository.
class _FakeTx implements TransactionRepository {
  _FakeTx({this.failLoad = false});

  Future<HopePayment>? payment;
  final List<Future<HopePayment>> paymentResponses = [];
  bool failLoad = false;
  final List<String> calls = [];

  @override
  Future<HopePayment> getPayment(String jobId) async {
    calls.add('get:$jobId');
    if (failLoad) throw Exception('load boom');
    if (paymentResponses.isNotEmpty) {
      return paymentResponses.removeAt(0);
    }
    return (await payment)!;
  }

  @override
  Future<HopePayment> fundPayment(String jobId, {String? idempotencyKey}) {
    calls.add('fund:$jobId');
    return Future.value(_data(jobId, 'FUNDED'));
  }

  @override
  Future<HopePayment> refundPayment(String jobId) {
    calls.add('refund:$jobId');
    return Future.value(_data(jobId, 'REFUND_PENDING'));
  }

  @override
  Future<HopePayment> releasePayment(String jobId) {
    calls.add('release:$jobId');
    return Future.value(_data(jobId, 'RELEASED'));
  }

  @override
  Future<HopeJob> startJob(String jobId) {
    calls.add('start:$jobId');
    return Future.value(_job(jobId, 'IN_PROGRESS', providerId: 'u1'));
  }

  @override
  Future<HopeJob> deliverJob(String jobId) {
    calls.add('deliver:$jobId');
    return Future.value(_job(jobId, 'IN_PROGRESS', providerId: 'u1'));
  }

  @override
  Future<HopeJob> acceptJob(String jobId) {
    calls.add('accept:$jobId');
    return Future.value(_job(jobId, 'COMPLETED', providerId: 'u1'));
  }

  @override
  Future<List<HopeJob>> listMyJobs() async => [];

  @override
  Future<void> submitEvidence(String jobId,
      {required String uri,
      required String notes,
      required String type}) async {
    calls.add('evidence:$jobId');
  }

  static HopePayment _data(String jobId, String status) => HopePayment.fromMap({
        'id': 'pay-$jobId',
        'status': status,
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job(jobId, 'FUNDED').toMap(),
        'fees': {
          'baseAmount': 1000000,
          'employerFee': 100000,
          'workerFee': 100000,
          'platformFee': 0,
          'employerCharge': 1100000,
          'providerPayout': 900000,
          'policyVersion': 'v1',
          'currency': 'IRR',
        },
      });
}

HopeJob _job(String id, String status, {String? providerId}) =>
    HopeJob.fromMap({
      'id': id,
      'title': 'Design landing page',
      'description': 'Deliver a landing page.',
      'categoryId': 'c1',
      'kind': 'MISSION',
      'status': status,
      'ownerId': 'u1',
      'providerId': providerId,
      'visibility': 'PUBLIC',
      'budgetMin': '1000000',
      'budgetMax': '1500000',
      'offerCount': 0,
      'isOwner': false,
    });

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

class _NoopUploadQueue implements UploadQueue {
  // Plain stand-in: no real file IO, no network. The api field is never read
  // by the flows under test.
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

Future<void> _pump(
  WidgetTester tester,
  _FakeTx repo, {
  String ownerId = 'u1',
  double width = 900,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = Size(width, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final auth = AuthController(_AuthRepo(), SecureStore());
  await auth.applyRefreshedUser({'id': ownerId, 'displayName': 'Ali'});

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('fa')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<TransactionRepository>.value(value: repo),
          Provider<UploadQueue>.value(value: _NoopUploadQueue()),
        ],
        child: TransactionPage(
          repository: repo,
          uploadQueue: _NoopUploadQueue(),
          jobId: 'j1',
        ),
      ),
    ),
  ));
  // These fakes resolve immediately; bounded pumps avoid treating any
  // unrelated ongoing animation as a test failure.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
      'transaction lifecycle honors reduced motion',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'HELD',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
      }));
    await _pump(tester, repo, ownerId: 'u1', disableAnimations: true);

    final animated = find.byType(AnimatedContainer);
    expect(animated, findsWidgets);
    for (final widget in tester.widgetList<AnimatedContainer>(animated)) {
      expect(widget.duration, Duration.zero);
    }
  });

  testWidgets('financial summary leads into the payment lifecycle', (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'HELD',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
      }));
    await _pump(tester, repo, ownerId: 'u1');

    expect(find.text('Financial summary'), findsOneWidget);
    expect(find.text('Payment status'), findsOneWidget);
    expect(find.text('Payment & job flow'), findsOneWidget);
    expect(find.text('Start work'), findsOneWidget);
  });

  testWidgets('loading then funded payload shows status, amount and start work',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'HELD',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
      }));
    await _pump(tester, repo, ownerId: 'u1');

    expect(find.text('Funded'), findsWidgets);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is! Text || widget.data == null) return false;
        return widget.data!.replaceAll(',', '') == '1000000 TOMAN';
      }),
      findsOneWidget,
    );
    expect(find.text('Design landing page'), findsAtLeastNWidgets(1));
    expect(find.text('Start work'), findsOneWidget);
    await tester.ensureVisible(find.text('Start work'));
    await tester.tap(find.text('Start work'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('start:j1'));
  });

  testWidgets('load failure shows retry which recovers', (tester) async {
    final repo = _FakeTx(failLoad: true);
    await _pump(tester, repo);

    expect(find.text('Payment refresh failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    repo.failLoad = false;
    repo.payment = Future.value(HopePayment.fromMap({
      'id': 'p1',
      'status': 'NO_TRANSACTION',
      'job': _job('j1', 'FUNDED').toMap(),
    }));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Fund payment'), findsOneWidget);
  });

  testWidgets('refresh failure with existing payment shows retry error without hiding stale data',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'HELD',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
      }));
    await _pump(tester, repo, ownerId: 'u1');

    expect(find.text('Design landing page'), findsOneWidget);
    repo.failLoad = true;

    await tester.tap(find.byTooltip('Refresh status'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Design landing page'), findsOneWidget);
    expect(find.text('Payment refresh failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('transaction refresh disables duplicate requests while pending',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'HELD',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
      }));
    final pending = Completer<HopePayment>();
    await _pump(tester, repo, ownerId: 'u1');
    repo.paymentResponses.add(pending.future);

    final refreshTooltip = find.byTooltip('Refresh status');
    expect(refreshTooltip, findsOneWidget);
    final refreshButton = find.ancestor(
      of: refreshTooltip,
      matching: find.byType(IconButton),
    );
    expect(refreshButton, findsOneWidget);
    await tester.tap(refreshTooltip);
    await tester.pump();

    expect(repo.calls.where((call) => call == 'get:j1').length, 2);
    expect(tester.widget<IconButton>(refreshButton).onPressed, isNull);

    pending.complete(HopePayment.fromMap({
      'id': 'p2',
      'status': 'HELD',
      'amount': 2000000,
      'providerRef': 'ref-2',
      'job': {
        ..._job('j1', 'FUNDED', providerId: 'u1').toMap(),
        'title': 'Fresh landing page',
      },
    }));
    await tester.pumpAndSettle();

    expect(find.text('Fresh landing page'), findsOneWidget);
    expect(find.textContaining('2,000,000'), findsOneWidget);
  });

  testWidgets('no-transaction view offers fund payment', (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': null,
        'status': 'NO_TRANSACTION',
        'job': _job('j1', 'FUNDED').toMap(),
      }));
    await _pump(tester, repo);

    expect(find.text('No payment'), findsOneWidget);
    await tester.ensureVisible(find.text('Fund payment'));
    await tester.tap(find.text('Fund payment'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('fund:j1'));
    expect(find.text('Operation completed.'), findsOneWidget);
  });

  testWidgets('held payment shows refund only to the job owner',
      (tester) async {
    final held = HopePayment.fromMap({
      'id': 'p1',
      'status': 'HELD',
      'amount': 1000000,
      'job': _job('j1', 'FUNDED').toMap(),
    });
    final repo = _FakeTx()..payment = Future.value(held);
    await _pump(tester, repo, ownerId: 'someone-else');
    // Non-owner: no refund action.
    expect(find.text('Request a refund'), findsNothing);

    final repo2 = _FakeTx()..payment = Future.value(held);
    await _pump(tester, repo2, ownerId: 'u1');
    expect(find.text('Request a refund'), findsOneWidget);
    await tester.ensureVisible(find.text('Request a refund'));
    await tester.tap(find.text('Request a refund'));
    await tester.pumpAndSettle();
    expect(find.text('Request refund'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(repo2.calls, contains('refund:j1'));
  });

  testWidgets('transaction summary contains long values on narrow screens',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'RELEASE_PENDING',
        'amount': '9000000000000000',
        'providerRef':
            'provider-reference-1234567890-abcdefghijklmnopqrstuvwxyz',
        'job': _job('j1', 'COMPLETED').toMap(),
      }));

    await _pump(tester, repo, ownerId: 'u1', width: 360);
    await tester.pumpAndSettle();

    expect(find.text('Payment status'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);
    expect(
      find.text(
        'provider-reference-1234567890-abcdefghijklmnopqrstuvwxyz',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed and released payment shows settled copy',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'RELEASED',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'COMPLETED').toMap(),
      }));
    await _pump(tester, repo);

    expect(find.text('Settled'), findsWidgets);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('This financial cycle is fully settled.'), findsOneWidget);
  });

  testWidgets('transaction status surfaces never leak unknown backend states',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'PROVIDER_RECONCILIATION_PENDING',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'EXTERNAL_REVIEW_REQUIRED', providerId: 'u1').toMap(),
      }));
    await _pump(tester, repo);

    expect(find.text('PROVIDER_RECONCILIATION_PENDING'), findsNothing);
    expect(find.text('EXTERNAL_REVIEW_REQUIRED'), findsNothing);

    expect(find.text('Needs review'), findsWidgets);
  });

  testWidgets('financial details section renders fee breakdown rows',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'HELD',
        'amount': 1000000,
        'job': _job('j1', 'FUNDED').toMap(),
        'fees': {
          'baseAmount': 1000000,
          'employerFee': 100000,
          'workerFee': 100000,
          'platformFee': 0,
          'employerCharge': 1100000,
          'providerPayout': 900000,
          'policyVersion': 'v1',
          'currency': 'IRR',
        },
      }));
    await _pump(tester, repo);

    // Scroll the fee breakdown into the built viewport.
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('Financial details'), findsOneWidget);
    expect(find.text('Base amount'), findsOneWidget);
    expect(find.text('Employer fee'), findsOneWidget);
    expect(find.text('Worker fee'), findsOneWidget);
    expect(find.text('Employer charge'), findsOneWidget);
    expect(find.text('Worker payout'), findsOneWidget);
  });
}
