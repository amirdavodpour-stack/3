import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('HOPE operational screens declare an explicit product domain', () {
    const expectations = <String, String>{
      'lib/features/home/premium_home_feed.dart': 'HopeProductDomain.overview',
      'lib/features/jobs/jobs_page.dart': 'HopeProductDomain.discovery',
      'lib/features/applications/my_applications_page.dart': 'HopeProductDomain.work',
      'lib/features/offers/offers_page.dart': 'HopeProductDomain.work',
      'lib/features/transactions/transactions_page.dart': 'HopeProductDomain.work',
      'lib/features/wallet/wallet_page.dart': 'HopeProductDomain.finance',
      'lib/features/profile/profile_page.dart': 'HopeProductDomain.account',
      'lib/features/notifications/notifications_page.dart': 'HopeProductDomain.communication',
      'lib/features/chat/chat_page.dart': 'HopeProductDomain.collaboration',
      'lib/features/jobs/job_satisfaction_page.dart': 'HopeProductDomain.trust',
      'lib/features/financial/financial_insights_page.dart': 'HopeProductDomain.finance',
      'lib/features/admin/admin_page.dart': 'HopeProductDomain.control',
      'lib/features/admin/admin_operations_page.dart': 'HopeProductDomain.control',
      'lib/features/admin/admin_disputes_page.dart': 'HopeProductDomain.control',
      'lib/features/recommendation/recommendation_onboarding_page.dart': 'HopeProductDomain.intelligence',
      'lib/features/marketplace/create_job_page.dart': 'HopeProductDomain.work',
    };

    for (final entry in expectations.entries) {
      final source = _read(entry.key);
      expect(source, contains(entry.value), reason: entry.key);
    }
  });

  test('HOPE domain language is centralized instead of screen-local', () {
    final source = _read('lib/core/ui/hope_product_architecture.dart');
    for (final name in const [
      'overview',
      'discovery',
      'work',
      'finance',
      'account',
      'trust',
      'control',
      'communication',
      'collaboration',
      'intelligence',
    ]) {
      expect(source, contains(name), reason: name);
    }
  });

  test('PremiumHeader and PremiumSectionHeader accept domain semantics', () {
    final source = _read('lib/core/ui/premium_components.dart');
    expect(source, contains('HopeProductDomain? domain'));
    expect(source, contains('PremiumDomainMarker'));
  });
}
