import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/admin/admin_repository.dart';
import 'package:hope_mobile/core/marketplace/application.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/features/admin/admin_operations_page.dart';
import 'package:provider/provider.dart';

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
}

Widget _host(_FakeAdminOperations repository) => MaterialApp(
      locale: const Locale('en'),
      home: Provider<AdminRepository>.value(
        value: repository,
        child: const AdminOperationsPage(),
      ),
    );

void main() {
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
