import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('canonical route registry exposes human chat destinations', () {
    final source = _read('lib/core/router/app_routes.dart');
    expect(source, contains("features/chat/chat_page.dart"));
    expect(source, contains('static Route<void> jobChat(String jobId)'));
    expect(source, contains('static Route<void> adminChat()'));
  });

  test('flagship secondary pages use the canonical premium page shell', () {
    const paths = <String>[
      'lib/features/recommendation/recommendation_onboarding_page.dart',
      'lib/features/financial/financial_insights_page.dart',
      'lib/features/jobs/job_satisfaction_page.dart',
      'lib/features/chat/chat_page.dart',
      'lib/features/offers/offers_page.dart',
      'lib/features/notifications/notifications_page.dart',
      'lib/features/applications/my_applications_page.dart',
    ];
    for (final path in paths) {
      final source = _read(path);
      expect(source, contains('PremiumPageFrame'), reason: path);
      expect(source, contains('PremiumHeader'), reason: path);
    }
  });

  test('secondary premium pages do not duplicate the page shell with AppBar', () {
    const paths = <String>[
      'lib/features/offers/offers_page.dart',
      'lib/features/notifications/notifications_page.dart',
      'lib/features/applications/my_applications_page.dart',
    ];
    for (final path in paths) {
      final source = _read(path);
      expect(source, isNot(contains('AppBar(')), reason: path);
    }
  });

  test('transaction detail keeps its canonical shell in the part file', () {
    final source = _read('lib/features/transactions/transaction_widgets.part.dart');
    expect(source, contains('PremiumPageFrame'));
    expect(source, contains('PremiumHeader'));
  });
}
