import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/network/api_client.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/uploads/upload_queue.dart';
import 'package:hope_mobile/features/transactions/transaction_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
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
          'platformFee': 200000,
          'employerCharge': 1100000,
          'providerPayout': 900000,
          'policyVersion': '2026-08-v1',
          'currency': 'TOMAN',
        },
      });
}

HopeJob _job(String id, String status, {String? providerId, String? title}) =>
    HopeJob.fromMap({
      'id': id,
      'title': title ?? 'Design landing page',
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
  double textScale = 1.0,
  bool disableAnimations = false,
  bool useActualViewportMetrics = false,
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
      data: MediaQueryData(
        size: useActualViewportMetrics ? Size(width, 2200) : Size.zero,
        devicePixelRatio: 1.0,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
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

  testWidgets(
    'transaction detail initial loading previews its financial card hierarchy',
    (tester) async {
      final pending = Completer<HopePayment>();
      final repo = _FakeTx()..paymentResponses.add(pending.future);

      await _pump(
        tester,
        repo,
        width: 360,
        textScale: 1.5,
        disableAnimations: true,
        useActualViewportMetrics: true,
      );

      expect(
        find.byKey(const ValueKey('transaction-detail-loading-skeleton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('transaction-loading-financial-summary')),
        findsOneWidget,
      );
      expect(find.text('Loading financial status'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      pending.complete(_FakeTx._data('j1', 'HELD'));
      await tester.pump();
    },
  );

  testWidgets('financial summary leads into the payment lifecycle', (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p1',
        'status': 'HELD',
        'amount': 1000000,
        'providerRef': 'ref-1',
        'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
        'fees': {
          'baseAmount': 1000000,
          'employerFee': 100000,
          'workerFee': 100000,
          'platformFee': 200000,
          'employerCharge': 1100000,
          'providerPayout': 900000,
          'policyVersion': '2026-08-v1',
          'currency': 'TOMAN',
        },
      }));
    await _pump(tester, repo, ownerId: 'u1');

    expect(find.text('Financial summary'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transaction-payment-base-amount-label')),
      findsOneWidget,
      reason: 'The headline amount must identify the backend base amount, not an unlabeled generic amount.',
    );
    final payoutSummary = find.byKey(
      const ValueKey('transaction-payment-payout-summary'),
    );
    expect(payoutSummary, findsOneWidget);
    expect(
      find.descendant(of: payoutSummary, matching: find.text('Employer charge')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: payoutSummary, matching: find.text('Worker payout')),
      findsOneWidget,
    );
    final header = tester.widget<PremiumHeader>(
      find.byType(PremiumHeader).first,
    );
    expect(header.dense, isTrue);
    expect(find.byKey(const ValueKey('transaction-payment-lifecycle')), findsOneWidget);
    expect(find.text('Payment status'), findsOneWidget);
    expect(find.text('Payment & job flow'), findsOneWidget);
    expect(find.text('Protected by HOPE'), findsOneWidget);
    expect(find.text('Start work'), findsOneWidget);
    expect(find.text('Stage 2 of 6'), findsOneWidget);
    final lifecycleProgress = find.byKey(
      const ValueKey('transaction-lifecycle-progress'),
    );
    expect(lifecycleProgress, findsOneWidget);
    expect(
      (tester.widget<LinearProgressIndicator>(lifecycleProgress).valueColor
              as AlwaysStoppedAnimation<Color>)
          .value,
      HopeV2ChartColors.matchSignal(tester.element(lifecycleProgress)),
      reason: 'Numeric lifecycle progress uses the shared teal chart role, not indigo.',
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PremiumTag && widget.label == 'Funds held',
      ),
      findsOneWidget,
      reason: 'The canonical payment status is already shown in the page heading.',
    );
  });

  testWidgets(
    'Wave 23 vertical transaction timeline remains decision-dense on compact screens',
    (tester) async {
      final repo = _FakeTx()
        ..payment = Future.value(HopePayment.fromMap({
          'id': 'p1',
          'status': 'HELD',
          'amount': 1000000,
          'providerRef': 'ref-1',
          'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
        }));
      await _pump(tester, repo, ownerId: 'u1', width: 360);

      final flow =
          find.byKey(const ValueKey('transaction-payment-lifecycle'));
      expect(flow, findsOneWidget);
      expect(tester.getSize(flow).height, lessThan(340));
      expect(find.text('Fund'), findsOneWidget);
      expect(find.text('Hold'), findsOneWidget);
      expect(find.text('Payout'), findsOneWidget);
      expect(
        find.byType(HopeLifecycleRail),
        findsNothing,
        reason: 'Compact transaction detail should use the readable vertical timeline instead of a horizontal rail.',
      );
      expect(tester.takeException(), isNull);
    },
  );

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

    expect(find.text('Funds held'), findsWidgets);
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
    final startAction = find.widgetWithText(FilledButton, 'Start work');
    expect(
      tester.widget<FilledButton>(startAction).style?.backgroundColor?.resolve({}),
      HopeV2Colors.markedPrimaryActionDarkGreen,
    );
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

  testWidgets(
    'transaction detail preserves a long opportunity title at 1.5x',
    (tester) async {
      const longTitle =
          'Senior product design lead responsible for editorial systems, accessible financial workflows, multilingual experience strategy, and cross-functional delivery';
      final repo = _FakeTx()
        ..payment = Future.value(HopePayment.fromMap({
          'id': 'p1',
          'status': 'HELD',
          'amount': '9000000000',
          'providerRef': 'ref-1',
          'job': _job(
            'j1',
            'FUNDED',
            providerId: 'u1',
            title: longTitle,
          ).toMap(),
        }));

      await _pump(
        tester,
        repo,
        width: 360,
        textScale: 1.5,
        useActualViewportMetrics: true,
      );

      final titleFinder = find.text(longTitle);
      expect(titleFinder, findsOneWidget);
      final titleText = tester.widget<Text>(titleFinder);
      expect(titleText.maxLines, isNull);
      expect(titleText.overflow, TextOverflow.visible);
      expect(
        tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 45 transaction summary preserves full TOMAN amount and fee values at 1.5x',
    (tester) async {
      final repo = _FakeTx()
        ..payment = Future.value(HopePayment.fromMap({
          'id': 'p1',
          'status': 'RELEASE_PENDING',
          'amount': '9000000000000000',
          'providerRef':
              'provider-reference-1234567890-abcdefghijklmnopqrstuvwxyz',
          'fees': {
            'baseAmount': '8999999999000000',
            'employerFee': '1000000',
            'workerFee': '500000',
            'platformFee': '0',
            'employerCharge': '9000000000000000',
            'providerPayout': '8999999998500000',
          },
          'job': _job('j1', 'COMPLETED').toMap(),
        }));

      await _pump(
        tester,
        repo,
        ownerId: 'u1',
        width: 360,
        textScale: 1.5,
        useActualViewportMetrics: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('Payment status'), findsOneWidget);
      final baseAmountLabel = find.byKey(
        const ValueKey('transaction-payment-base-amount-label'),
      );
      expect(baseAmountLabel, findsOneWidget);
      expect(tester.widget<Text>(baseAmountLabel).data, 'Base amount');
      expect(find.text('Reference'), findsNothing);
      expect(
        find.text(
          'provider-reference-1234567890-abcdefghijklmnopqrstuvwxyz',
        ),
        findsNothing,
      );

      final mainAmount = find.byKey(
        const ValueKey('transaction-payment-amount'),
      );
      expect(mainAmount, findsOneWidget);
      final mainAmountText = tester.widget<Text>(mainAmount);
      expect(
        mainAmountText.data!.replaceAll(',', ''),
        '8999999999000000 TOMAN',
        reason: 'The headline value is the canonical backend baseAmount; employerCharge remains a separate amount.',
      );
      expect(find.text('Employer charge'), findsAtLeastNWidgets(1));
      expect(find.text('Worker payout'), findsAtLeastNWidgets(1));
      expect(mainAmountText.maxLines, isNull);
      expect(mainAmountText.softWrap, isTrue);
      expect(mainAmountText.overflow, TextOverflow.visible);
      expect(tester.getRect(mainAmount).right, lessThanOrEqualTo(360));

      Finder moneyTextWithoutCommas(String digits) => find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data != null &&
                widget.data!.replaceAll(',', '') == '$digits TOMAN',
          );

      final feeAmount = moneyTextWithoutCommas('8999999999000000');
      await tester.scrollUntilVisible(
        feeAmount,
        180,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      await tester.pumpAndSettle();
      expect(feeAmount, findsOneWidget);
      final feeAmountText = tester.widget<Text>(feeAmount);
      expect(
        feeAmountText.style?.color,
        HopeV2SemanticColors.price(tester.element(feeAmount)),
        reason: 'Financial detail rows must use the semantic price foreground.',
      );
      expect(feeAmountText.maxLines, isNull);
      expect(feeAmountText.softWrap, isTrue);
      expect(feeAmountText.overflow, TextOverflow.visible);
      expect(tester.getRect(feeAmount).right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('Stage unavailable'), findsOneWidget);
    expect(find.text('Stage 1 of 6'), findsNothing);
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
          'platformFee': 200000,
          'employerCharge': 1100000,
          'providerPayout': 900000,
          'policyVersion': '2026-08-v1',
          'currency': 'TOMAN',
        },
      }));
    await _pump(tester, repo);

    // Scroll the fee breakdown into the built viewport.
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    final detailPanel = find.byKey(
      const ValueKey('transaction-payment-financial-details'),
    );
    expect(detailPanel, findsOneWidget);
    Finder detailText(String label) => find.descendant(
          of: detailPanel,
          matching: find.text(label),
        );
    expect(detailText('Financial details'), findsOneWidget);
    expect(detailText('Base amount'), findsOneWidget);
    expect(detailText('Employer fee'), findsOneWidget);
    expect(detailText('Worker fee'), findsOneWidget);
    expect(detailText('Platform fee'), findsOneWidget);
    expect(detailText('Employer charge'), findsOneWidget);
    expect(detailText('Worker payout'), findsOneWidget);
    // Exact MISSION contract fixture: 10% fee on each side, 20% platform fee.
    expect(detailText('100,000 TOMAN'), findsNWidgets(2));
    expect(detailText('200,000 TOMAN'), findsOneWidget);
    expect(detailText('1,100,000 TOMAN'), findsOneWidget);
    expect(detailText('900,000 TOMAN'), findsOneWidget);
  });


  testWidgets('compact transaction summary prioritizes amount over technical reference copy',
      (tester) async {
    final repo = _FakeTx()
      ..payment = Future.value(HopePayment.fromMap({
        'id': 'p-compact',
        'status': 'HELD',
        'amount': 1650000,
        'providerRef': 'internal-ledger-reference-compact',
        'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
      }));

    await _pump(tester, repo, ownerId: 'u1', width: 360);

    expect(find.text('Financial summary'), findsOneWidget);
    expect(find.text('Reference'), findsNothing);
    expect(find.text('1,650,000 TOMAN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets(
    'transaction details hide internal provider references but retain public references',
    (tester) async {
      final internalRepo = _FakeTx()
        ..payment = Future.value(HopePayment.fromMap({
          'id': 'payment-internal-id',
          'status': 'HELD',
          'amount': 1650000,
          'providerRef': 'internal-ledger-reference-compact',
          'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
        }));
      await _pump(
        tester,
        internalRepo,
        width: 1200,
        useActualViewportMetrics: true,
      );

      expect(find.text('internal-ledger-reference-compact'), findsNothing);
      expect(find.text('Reference'), findsNothing);

      // Force a fresh State/controller for the public-reference phase rather
      // than reusing the internal-reference page's already-loaded payment.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final publicRepo = _FakeTx()
        ..payment = Future.value(HopePayment.fromMap({
          'id': 'payment-public-reference',
          'status': 'HELD',
          'amount': 1650000,
          'providerRef': 'HP-1042',
          'job': _job('j1', 'FUNDED', providerId: 'u1').toMap(),
        }));
      await _pump(
        tester,
        publicRepo,
        width: 1200,
        useActualViewportMetrics: true,
      );

      expect(find.text('Reference'), findsOneWidget);
      expect(find.text('#HP-1042'), findsOneWidget);
      expect(find.text('HP-1042'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

}
