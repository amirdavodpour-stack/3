import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/auth_controller.dart';
import 'package:hope_mobile/core/auth/auth_repository.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/settings/settings_controller.dart';
import 'package:hope_mobile/core/storage/secure_store.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/transactions/payment.dart';
import 'package:hope_mobile/core/transactions/transaction_repository.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/premium_lifecycle.dart';
import 'package:hope_mobile/features/transactions/transactions_page.dart';
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

class _Transactions implements TransactionRepository {
  List<HopeJob> jobs = const [];
  bool paymentUnavailable = false;
  bool failList = false;
  @override
  Future<List<HopeJob>> listMyJobs() async {
    if (failList) throw StateError('activity unavailable');
    return jobs;
  }
  @override
  Future<HopePayment> getPayment(String id) async {
    if (paymentUnavailable) {
      throw StateError('payment service unavailable');
    }
    final job = jobs.firstWhere(
      (item) => item.id == id,
      orElse: () => _job(id),
    );
    return HopePayment(
      id: 'payment-$id',
      status: 'FUNDED',
      amount: '100',
      job: job,
    );
  }
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

Future<void> _pump(
  WidgetTester tester,
  _Transactions repo, {
  bool guest = false,
  double width = 900,
  double height = 2400,
  double textScale = 1,
  Locale locale = const Locale('fa'),
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final settings = HopeSettingsController();
  await settings.load();
  final auth = AuthController(_AuthRepo(), SecureStore());
  if (guest) {
    auth.continueAsGuest();
  } else {
    await auth.applyRefreshedUser({'id': 'u1', 'displayName': 'User'});
  }
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light(),
    locale: locale,
    supportedLocales: const [Locale('fa'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: MultiProvider(
        providers: [ChangeNotifierProvider.value(value: auth)],
        child: TransactionsPage(repository: repo),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

HopeJob _job(String id, {String status = 'OPEN'}) => HopeJob.fromMap({
      'id': id,
      'title': 'پروژه $id',
      'description': '',
      'status': status,
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
    });

// Wave 1 regression harness: numeric/status assertions stay scoped to the compact work-center composition.

void main() {
  testWidgets('guest transactions protect private activity', (tester) async {
    final repo = _Transactions();
    await _pump(tester, repo, guest: true);
    expect(find.byType(TransactionsPage), findsOneWidget);
    expect(find.textContaining('خصوصی'), findsOneWidget);
  });

  testWidgets('empty authenticated transactions show the empty state',
      (tester) async {
    final repo = _Transactions()..jobs = [];
    await _pump(tester, repo);
    expect(find.text('هنوز کاری ثبت نشده است'), findsOneWidget);
  });

  testWidgets('activity metrics fit three compact cells on one narrow row',
      (tester) async {
    final repo = _Transactions()
      ..jobs = [_job('a', status: 'IN_PROGRESS')];
    await _pump(tester, repo, width: 360);

    final metrics = find.byKey(const ValueKey('work-center-metrics'));
    expect(metrics, findsOneWidget);
    expect(find.text('همکاری‌ها'), findsOneWidget);
    expect(
      find.descendant(
        of: metrics,
        matching: find.text('در حال اجرا'),
      ),
      findsOneWidget,
    );
    expect(find.text('تسویه‌شده'), findsOneWidget);
    expect(
      find.descendant(of: metrics, matching: find.text('1')),
      findsNWidgets(2),
    );
    expect(tester.getSize(metrics).height, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact work-center metrics hide secondary captions on narrow screens',
      (tester) async {
    final repo = _Transactions()
      ..jobs = [_job('compact', status: 'IN_PROGRESS')];
    await _pump(tester, repo, width: 360);

    expect(find.text('تمام همکاری‌های ثبت‌شده'), findsNothing);
    expect(find.text('در مسیر انجام یا بررسی'), findsNothing);
    expect(find.text('پایان‌یافته مالی'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('work-center omits a redundant parent header for other-only states',
      (tester) async {
    final repo = _Transactions()
      ..jobs = [_job('other-only', status: 'PUBLISHED')];
    await _pump(tester, repo);

    expect(find.text('جریان همکاری‌ها'), findsNothing);
    expect(find.text('سایر وضعیت‌ها'), findsOneWidget);
    expect(find.text('پروژه other-only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transactions avoids nested quick-action blur on the heavy work surface',
      (tester) async {
    final repo = _Transactions()..jobs = [_job('blur-check', status: 'IN_PROGRESS')];
    await _pump(tester, repo);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('loaded work center uses dense header hierarchy', (tester) async {
    final repo = _Transactions()
      ..jobs = [_job('dense-header', status: 'IN_PROGRESS')];
    await _pump(tester, repo);

    final header = tester.widget<PremiumHeader>(find.byType(PremiumHeader));
    expect(header.dense, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated transactions render active and completed jobs',
      (tester) async {
    final repo = _Transactions()
      ..jobs = [
        _job('a', status: 'IN_PROGRESS'),
        _job('b', status: 'COMPLETED')
      ];
    await _pump(tester, repo);
    expect(find.text('پروژه a'), findsOneWidget);

    // The activity list is scrollable and each project card contains a
    // lifecycle section, so the second card may be outside the initial
    // viewport and therefore not built by ListView yet. Scroll to it before
    // asserting that the completed job is rendered.
    await tester.scrollUntilVisible(
      find.text('پروژه b'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('پروژه b'), findsOneWidget);
  });

  testWidgets('activity refresh failure preserves existing items and shows retry state',
      (tester) async {
    final repo = _Transactions()..jobs = [_job('refresh-stale', status: 'IN_PROGRESS')];
    await _pump(tester, repo);

    expect(find.text('پروژه refresh-stale'), findsOneWidget);
    repo.failList = true;

    final refreshIndicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first);
    await refreshIndicator.onRefresh();
    await tester.pump();

    expect(find.text('پروژه refresh-stale'), findsOneWidget);
    expect(find.text('دریافت فعالیت ناموفق بود'), findsOneWidget);
    expect(find.text('تلاش دوباره'), findsOneWidget);
  });

  testWidgets('transactions safely localize unknown job status',
      (tester) async {
    final repo = _Transactions()
      ..jobs = [_job('unknown', status: 'UNKNOWN_STATE')];
    await _pump(tester, repo);
    await tester.scrollUntilVisible(
      find.text('پروژه unknown'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'وضعیت کار: UNKNOWN_STATE',
      ),
      findsNothing,
    );
    expect(find.text('نیازمند بررسی'), findsWidgets);
  });

  testWidgets('transactions still render when payment lookup is unavailable',
      (tester) async {
    final repo = _Transactions()
      ..paymentUnavailable = true
      ..jobs = [_job('payment-unavailable', status: 'IN_PROGRESS')];
    await _pump(tester, repo);
    expect(find.text('پروژه payment-unavailable'), findsOneWidget);
  });

  // Runtime certification trigger: grouped Wave G-3B Create + Work Center.
  testWidgets(
    'Wave 24 collaboration lifecycle clears the dock at 360x640 and remains tappable',
    (tester) async {
      final repo = _Transactions()
        ..jobs = [_job('wave24-active', status: 'IN_PROGRESS')];
      await _pump(tester, repo, width: 360, height: 640);
      await tester.scrollUntilVisible(
        find.text('پروژه wave24-active'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final lifecycle = find.byKey(
        const ValueKey('work-center-lifecycle-wave24-active'),
      );
      final dock = find.byKey(const ValueKey('hope-navigation-dock'));
      expect(lifecycle, findsOneWidget);
      expect(dock, findsOneWidget);
      await tester.ensureVisible(lifecycle);
      await tester.pumpAndSettle();
      final lifecycleRect = tester.getRect(lifecycle);
      final dockRect = tester.getRect(dock);
      expect(
        lifecycleRect.bottom,
        lessThanOrEqualTo(dockRect.top - HopeV2Navigation.scrollEndGap),
        reason: 'The collaboration lifecycle must be reachable above the fixed dock.',
      );
      await tester.tapAt(lifecycleRect.center);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'Wave30 English Work Center expands lifecycle rows at 1.5x and preserves scroll reachability',
    (tester) async {
      final repo = _Transactions()
        ..jobs = [_job('scale', status: 'IN_PROGRESS')];
      await _pump(
        tester,
        repo,
        width: 360,
        height: 640,
        textScale: 1.5,
        locale: const Locale('en'),
      );

      final lifecycle = find.byKey(
        const ValueKey('work-center-lifecycle-scale'),
      );
      await tester.scrollUntilVisible(
        lifecycle,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(lifecycle, findsOneWidget);
      expect(tester.widget<PremiumLifecycle>(lifecycle).compact, isFalse);
      expect(find.text('Work flow'), findsOneWidget);
      expect(lifecycle.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 29 last Work Center item stays reachable above the fixed dock with a 12-item list',
    (tester) async {
      final repo = _Transactions()
        ..jobs = List.generate(
          12,
          (index) => _job('reach-$index', status: 'IN_PROGRESS'),
        );
      await _pump(tester, repo, width: 360, height: 640);

      final lastJob = find.text('پروژه reach-11');
      await tester.scrollUntilVisible(
        lastJob,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(lastJob);
      await tester.pumpAndSettle();

      final dock = find.byKey(const ValueKey('hope-navigation-dock'));
      expect(lastJob, findsOneWidget);
      expect(dock, findsOneWidget);
      final rowBounds = tester.getRect(lastJob);
      final dockBounds = tester.getRect(dock);
      expect(
        rowBounds.bottom,
        lessThanOrEqualTo(dockBounds.top - HopeV2Navigation.scrollEndGap),
      );
      expect(lastJob.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

}
