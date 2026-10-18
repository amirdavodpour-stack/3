import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  Completer<List<HopeJob>>? listCompleter;
  @override
  Future<List<HopeJob>> listMyJobs() async {
    if (failList) throw StateError('activity unavailable');
    final pending = listCompleter;
    if (pending != null) return pending.future;
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
  bool settle = true,
  bool disableAnimations = false,
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
        disableAnimations: disableAnimations,
      ),
      child: MultiProvider(
        providers: [ChangeNotifierProvider.value(value: auth)],
        child: TransactionsPage(repository: repo),
      ),
    ),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

HopeJob _job(
  String id, {
  String status = 'OPEN',
  String? title,
}) =>
    HopeJob.fromMap({
      'id': id,
      'title': title ?? 'پروژه $id',
      'description': '',
      'status': status,
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
    });

// Wave 1 regression harness: numeric/status assertions stay scoped to the compact work-center composition.

void main() {
  testWidgets(
    'Wave48 Work Center preserves lifecycle reachability across widths and locales',
    (tester) async {
      const widths = [320.0, 360.0, 390.0, 600.0, 900.0, 1200.0];
      final cases = <({
        double width,
        double height,
        Locale locale,
        double textScale,
      })>[];
      for (final width in widths) {
        final height = width <= 390 ? 640.0 : 900.0;
        for (final locale in const [Locale('fa'), Locale('en')]) {
          cases.add((
            width: width,
            height: height,
            locale: locale,
            textScale: 1,
          ));
        }
      }
      for (final width in const [320.0, 390.0]) {
        final height = width == 320 ? 640.0 : 844.0;
        for (final locale in const [Locale('fa'), Locale('en')]) {
          cases.add((
            width: width,
            height: height,
            locale: locale,
            textScale: 1.5,
          ));
        }
      }

      for (final item in cases) {
        final repository = _Transactions()
          ..jobs = [
            _job('matrix-active', status: 'OPEN'),
            _job('matrix-settled', status: 'COMPLETED'),
          ];
        await _pump(
          tester,
          repository,
          width: item.width,
          height: item.height,
          textScale: item.textScale,
          locale: item.locale,
        );
        final contextLabel =
            '${item.width.toInt()}dp/${item.locale.languageCode}/${item.textScale}x';
        expect(find.byType(TransactionsPage), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(TransactionsPage))),
          item.locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr,
          reason: 'Incorrect direction at $contextLabel',
        );

        final lifecycle = find.byKey(
          const ValueKey('work-center-lifecycle-matrix-active'),
        );
        await tester.scrollUntilVisible(
          lifecycle,
          180,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 35,
        );
        await tester.pumpAndSettle();
        expect(lifecycle, findsOneWidget,
            reason: 'Active lifecycle not reachable at $contextLabel');
        final lifecycleRect = tester.getRect(lifecycle);
        expect(lifecycleRect.left, greaterThanOrEqualTo(0),
            reason: 'Lifecycle clips at leading edge for $contextLabel');
        expect(lifecycleRect.right, lessThanOrEqualTo(item.width),
            reason: 'Lifecycle clips at trailing edge for $contextLabel');
        expect(lifecycleRect.top, greaterThanOrEqualTo(0),
            reason: 'Lifecycle scroll target is above viewport at $contextLabel');

        if (item.width < HopeV2Breakpoints.medium) {
          final dock = find.byKey(const ValueKey('hope-navigation-dock'));
          expect(dock, findsOneWidget,
              reason: 'Compact/medium primary dock missing at $contextLabel');
          if (item.textScale == 1) {
            expect(
              lifecycleRect.bottom,
              lessThanOrEqualTo(
                tester.getRect(dock).top - HopeV2Navigation.scrollEndGap,
              ),
              reason: 'Work Center dock occludes lifecycle at $contextLabel',
            );
          }
        } else {
          expect(find.byType(PremiumNavigationRail), findsOneWidget,
              reason: 'Expanded viewport should use the navigation rail at $contextLabel');
        }
        expect(tester.takeException(), isNull,
            reason: 'Work Center render error at $contextLabel');
      }
    },
  );

  testWidgets('guest transactions protect private activity with compact first-fold CTA',
      (tester) async {
    final repo = _Transactions();
    await _pump(tester, repo, guest: true, width: 390, height: 844);
    expect(find.byType(TransactionsPage), findsOneWidget);
    expect(find.textContaining('شخصی'), findsOneWidget);
    expect(
      tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
      24,
      reason: 'The page frame must not duplicate the navigation-aware scroll tail.',
    );

    final action = find.byType(FilledButton);
    expect(action, findsOneWidget);
    expect(
      tester.getTopLeft(action).dy,
      lessThan(240),
      reason: 'The sign-in action should not be pushed down by an oversized blank band.',
    );
    expect(
      tester.widget<PremiumPanel>(find.byType(PremiumPanel)).padding,
      const EdgeInsets.all(12),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Work Center initial loading uses a content-shaped skeleton instead of a spinner',
    (tester) async {
      final repo = _Transactions()
        ..listCompleter = Completer<List<HopeJob>>();
      await _pump(
        tester,
        repo,
        width: 360,
        height: 640,
        settle: false,
        disableAnimations: true,
      );

      expect(
        find.byKey(const ValueKey('work-center-loading-skeleton')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('empty authenticated transactions show the empty state',
      (tester) async {
    final repo = _Transactions()..jobs = [];
    await _pump(tester, repo);
    expect(find.text('هنوز فعالیتی ثبت نشده است'), findsOneWidget);
    expect(
      tester.widget<PremiumPageFrame>(find.byType(PremiumPageFrame)).padding.bottom,
      24,
      reason: 'The empty state keeps a compact outer page tail.',
    );
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
      find.descendant(of: metrics, matching: find.text('۱')),
      findsNWidgets(2),
    );
    expect(tester.getSize(metrics).height, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Work Center metrics reflow and preserve full labels at 1.5x in RTL and LTR',
    (tester) async {
      for (final locale in const [Locale('fa'), Locale('en')]) {
        final repo = _Transactions()
          ..jobs = [
            _job('metric-active', status: 'IN_PROGRESS'),
            _job('metric-settled', status: 'COMPLETED'),
          ];
        await _pump(
          tester,
          repo,
          width: 320,
          height: 640,
          textScale: 1.5,
          locale: locale,
        );

        final metrics = find.byKey(const ValueKey('work-center-metrics'));
        expect(metrics, findsOneWidget);
        final metricTexts = tester.widgetList<Text>(
          find.descendant(of: metrics, matching: find.byType(Text)),
        ).toList(growable: false);
        expect(metricTexts, hasLength(6));
        expect(
          metricTexts.every(
            (text) =>
                text.maxLines == null &&
                text.overflow == TextOverflow.visible &&
                text.softWrap == true,
          ),
          isTrue,
          reason:
              'Work Center summary labels and counts must remain fully readable at 1.5x in ${locale.languageCode}.',
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );

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

  testWidgets(
    'Work Center keeps the full opportunity title at 1.5x system text',
    (tester) async {
      const title =
          'Senior product design lead responsible for editorial systems, accessible financial workflows, multilingual experience strategy, component governance, and cross-functional delivery';
      final repo = _Transactions()
        ..jobs = [
          _job(
            'long-work-center-title',
            status: 'IN_PROGRESS',
            title: title,
          ),
        ];
      await _pump(
        tester,
        repo,
        width: 360,
        height: 900,
        textScale: 1.5,
      );

      final titleFinder = find.text(title);
      await tester.scrollUntilVisible(
        titleFinder,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(titleFinder, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(titleFinder).didExceedMaxLines,
        isFalse,
        reason: 'The Work Center card should allow its complete project title to wrap at enlarged text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact Work Center cards omit repeated lifecycle helper copy',
    (tester) async {
      final repo = _Transactions()
        ..jobs = [_job('compact-lifecycle-copy', status: 'IN_PROGRESS')];
      await _pump(
        tester,
        repo,
        width: 360,
        height: 640,
        locale: const Locale('en'),
      );

      final lifecycle = find.byKey(
        const ValueKey('work-center-lifecycle-compact-lifecycle-copy'),
      );
      await tester.scrollUntilVisible(
        lifecycle,
        180,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 35,
      );
      await tester.pumpAndSettle();

      expect(lifecycle, findsOneWidget);
      expect(find.text('Work flow'), findsOneWidget);
      expect(
        find.text('Follow the current collaboration state at a glance.'),
        findsNothing,
        reason:
            'The generic lifecycle helper sentence repeats in every compact job card and consumes vertical space without adding job-specific information.',
      );
      expect(tester.takeException(), isNull);
    },
  );

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


  testWidgets(
    'transaction status action keeps a 48dp tap target in compact RTL layouts',
    (tester) async {
      final repo = _Transactions()
        ..jobs = [_job('tap-target', status: 'IN_PROGRESS')];
      await _pump(repo: repo, tester: tester, width: 390, height: 844);
      final label = find.text('مشاهده وضعیت معامله');
      await tester.scrollUntilVisible(
        label,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      final action = find.ancestor(
        of: label,
        matching: find.byType(OutlinedButton),
      );
      expect(action, findsOneWidget);
      final button = tester.widget<OutlinedButton>(action);
      expect(
        button.style?.minimumSize?.resolve(const {})?.height,
        greaterThanOrEqualTo(48),
        reason: 'The transaction status action must not inherit a compact theme density that shrinks its target below 48dp.',
      );
      expect(
        button.style?.visualDensity?.resolve(const {}),
        VisualDensity.standard,
      );
    },
  );

}
