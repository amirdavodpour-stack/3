import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/admin/admin_repository.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/features/admin/admin_operations_page.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:provider/provider.dart';

class _LongMetricAdminOperations extends _FakeAdminOperations {
  @override
  Future<Map<String, dynamic>> getFinanceSummary() async => const {
        'reserved_payout_total': '123456789012345678901234567890',
      };
}

class _FakeAdminOperations implements AdminRepository {
  int resolveCalls = 0;
  final Completer<Map<String, dynamic>> resolveResult =
      Completer<Map<String, dynamic>>();
  final List<Map<String, dynamic>> payouts = const [
    {
      'id': 'p1',
      'status': 'UNKNOWN',
      'amount': '100000',
      'currency': 'TOMAN',
    },
  ];
  List<Map<String, dynamic>> reports = const [
    {
      'id': 'r1',
      'status': 'OPEN',
      'entityType': 'JOB',
      'entityId': 'j1',
      'reason': 'Spam',
      'details': '',
      'createdAt': '2026-09-22T00:00:00Z',
    },
  ];

  @override
  Future<HopeAdminSummary> getSummary() async =>
      const HopeAdminSummary(values: {});

  @override
  Future<List<HopeJob>> listJobs() async => const [];

  @override
  Future<List<HopeApplication>> listApplications() async => const [];

  @override
  Future<List<HopeAdminUser>> listUsers() async => const [];

  @override
  Future<List<HopeAdminAuditEvent>> listAudit() async => const [];

  @override
  Future<void> shortlistApplication(String id) async {}

  @override
  Future<void> forwardApplication(String id) async {}

  @override
  Future<void> rejectApplication(String id) async {}

  @override
  Future<void> moderateJob(String id, String status) async {}

  @override
  Future<void> setUserStatus(String id, String status) async {}

  @override
  Future<void> deleteJob(String id) async {}

  @override
  Future<Map<String, dynamic>> getFinanceSummary() async => const {};

  @override
  Future<List<Map<String, dynamic>>> listTrustReports({String? status}) async => reports;

  @override
  Future<void> updateTrustReportStatus(String id, String status) async {}

  @override
  Future<List<Map<String, dynamic>>> listUnknownPayouts({int limit = 100}) async =>
      payouts;

  @override
  Future<Map<String, dynamic>> resolveUnknownPayout(
    String id, {
    required String decision,
    String? providerRef,
    String? reason,
  }) {
    resolveCalls += 1;
    return resolveResult.future;
  }

  @override
  Future<Map<String, dynamic>> getAnalyticsSummary({int days = 30}) async =>
      const {};

  @override
  Future<Map<String, dynamic>> getFunnel({int days = 30}) async => const {};

  @override
  Future<Map<String, dynamic>> getCrashSummary({int days = 30}) async =>
      const {};
  @override Future<Map<String, dynamic>> grantAdminByEmail(String email) async => const {};
  @override Future<void> revokeAdministrator(String id) async {}
  @override Future<void> revokeUserSessions(String id) async {}
  @override
  Future<Map<String, dynamic>> getPanelAccess() async => const {
        'verified': true,
        'primaryAdmin': true,
        'permissions': ['admin.resolve_payouts'],
      };
  @override Future<Map<String, dynamic>> verifyPanelAccess(String name, String username) async => const {'verified': true};
  @override Future<void> lockPanel() async {}
  @override Future<List<Map<String, dynamic>>> listDisputes() async => const [];
  @override Future<Map<String, dynamic>> getDispute(String id) async => const {};
  @override Future<Map<String, dynamic>> resolveDispute(String id, {required String resolution, String? reason}) async => const {};
}

class _DelayedPanelAccessAdminOperations extends _FakeAdminOperations {
  final Completer<Map<String, dynamic>> panelAccess =
      Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> getPanelAccess() => panelAccess.future;
}

Widget _host(_FakeAdminOperations repository, {double textScale = 1}) => MaterialApp(
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      locale: const Locale('en'),
      home: Provider<AdminRepository>.value(
        value: repository,
        child: const AdminOperationsPage(),
      ),
    );

void main() {

  testWidgets(
    'admin operations does not show false empty reports while initial access is pending',
    (tester) async {
      final repository = _DelayedPanelAccessAdminOperations();
      await tester.pumpWidget(_host(repository));
      // Access is intentionally held pending; do not pumpAndSettle while the
      // expected loading indicator is animating.
      await tester.pump();

      await tester.tap(find.text('Trust & Safety'));
      await tester.pump();

      // Resolve the held access request after recording the visible interim state,
      // so the pending future cannot leak beyond this test if the assertion fails.
      final renderedFalseEmptyState =
          find.text('No reports').evaluate().isNotEmpty;
      repository.panelAccess.complete(const {
        'verified': true,
        'primaryAdmin': true,
        'permissions': ['admin.resolve_payouts'],
      });
      await tester.pumpAndSettle();

      expect(
        renderedFalseEmptyState,
        isFalse,
        reason: 'An initial Future.value([]) is only a placeholder; no reports should not be claimed before the access-gated fetch starts.',
      );
      expect(find.text('Spam'), findsOneWidget);
      expect(find.text('No reports'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'admin metric cards preserve long financial values at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(_LongMetricAdminOperations(), textScale: 1.5),
      );
      await tester.pumpAndSettle();

      final value = find.text('123456789012345678901234567890');
      expect(value, findsOneWidget);
      final valueWidget = tester.widget<Text>(value);
      expect(
        valueWidget.maxLines,
        isNull,
        reason: 'Operational financial values must not be clipped to one line when system text is enlarged.',
      );
      expect(valueWidget.overflow, TextOverflow.visible);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('admin operations preserves vertical workspace on a phone viewport',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(_FakeAdminOperations()));
    await tester.pumpAndSettle();

    final frame = tester.widget<PremiumPageFrame>(
      find.byType(PremiumPageFrame),
    );
    expect(frame.padding.bottom, 24);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.getSize(find.byType(TabBarView)).height, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('trust report enum fields use localized presentation', (tester) async {
    final repository = _FakeAdminOperations();
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trust & Safety'));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(find.textContaining('Opportunity'), findsOneWidget);
    expect(find.text('OPEN'), findsNothing);
    expect(find.text('JOB'), findsNothing);
    expect(find.text('Reviewing'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Dismissed'), findsOneWidget);
  });

  testWidgets(
    'unknown payout resolution disables duplicate operational actions until completion',
    (tester) async {
      final repository = _FakeAdminOperations();
      await tester.pumpWidget(_host(repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unknown payouts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark failed'));
      await tester.pump();

      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('UNKNOWN'), findsNothing);
      expect(find.text('status: UNKNOWN'), findsNothing);
      expect(find.text('TOMAN'), findsNothing);
      expect(find.text('currency: TOMAN'), findsNothing);

      expect(repository.resolveCalls, 1);
      expect(
        tester.widget<OutlinedButton>(find.widgetWithText(
          OutlinedButton,
          'Mark failed',
        )).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.widgetWithText(
          FilledButton,
          'Mark succeeded',
        )).onPressed,
        isNull,
      );

      await tester.tap(find.text('Mark failed'));
      await tester.pump();
      expect(repository.resolveCalls, 1);

      repository.resolveResult.complete(const {});
      await tester.pumpAndSettle();
      expect(repository.resolveCalls, 1);
    },
  );
}
