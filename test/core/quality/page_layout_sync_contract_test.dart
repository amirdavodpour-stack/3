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
      'lib/features/marketplace/create_job_page.dart',
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
      'lib/features/marketplace/create_job_page.dart',
    ];
    for (final path in paths) {
      final source = _read(path);
      expect(source, isNot(contains('AppBar(')), reason: path);
    }
  });

  test('premium shell paints a full opaque canvas behind tab content', () {
    final source = _read('lib/features/home/home_page.dart');
    expect(source, contains('body: ColoredBox('));
    expect(source, contains('Theme.of(context).scaffoldBackgroundColor'));
  });

  test('compact premium hero preserves the requested short height', () {
    final source = _read('lib/core/ui/premium_components.dart');
    expect(source, contains('height.clamp(152.0, 320.0)'));
    expect(source, contains('mainAxisSize: MainAxisSize.max'));
  });

  test('responsive match breakdown becomes two-column before desktop width', () {
    final source = _read('lib/features/marketplace/job_detail_page.dart');
    expect(source, contains('constraints.maxWidth >= 240'));
  });

  test('transaction detail keeps its canonical shell in the part file', () {
    final source = _read('lib/features/transactions/transaction_widgets.part.dart');
    expect(source, contains('PremiumPageFrame'));
    expect(source, contains('PremiumHeader'));
  });
}
