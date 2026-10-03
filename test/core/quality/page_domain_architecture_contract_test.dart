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
      'lib/features/jobs/saved_searches_page.dart': 'HopeProductDomain.discovery',
      'lib/features/notifications/notification_devices_page.dart': 'HopeProductDomain.communication',
      'lib/features/privacy/privacy_center_page.dart': 'HopeProductDomain.account',
      'lib/features/admin/admin_access_page.dart': 'HopeProductDomain.control',
      'lib/features/marketplace/employer_candidate_matches_page.dart': 'HopeProductDomain.intelligence',
      'lib/features/transactions/transaction_widgets.part.dart': 'HopeProductDomain.finance',
      'lib/features/about/about_page.dart': 'HopeProductDomain.overview',
      'lib/features/marketplace/job_detail_page.dart': 'HopeProductDomain.discovery',
    };

    for (final entry in expectations.entries) {
      final source = _read(entry.key);
      expect(source, contains(entry.value), reason: entry.key);
    }
  });

  test('admin and job chat use distinct domains', () {
    final source = _read('lib/features/chat/chat_page.dart');
    expect(
      source,
      contains('HopeProductDomain.control'),
    );
    expect(
      source,
      contains('HopeProductDomain.collaboration'),
    );
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

  test('secondary navigation groups expose HOPE product domains', () {
    final source = _read('lib/features/home/home_page.dart');
    expect(source, contains('PremiumDomainNavigationGroup'));
    for (final domain in const [
      'discovery',
      'work',
      'intelligence',
      'communication',
      'control',
    ]) {
      expect(source, contains('HopeProductDomain.$domain'), reason: domain);
    }
  });

  test('operational screens declare a centralized page identity', () {
    final architecture = _read('lib/core/ui/hope_product_architecture.dart');
    final screens = <String, String>{
      'premium_home_feed.dart': 'HopePageId.home',
      'login_page.dart': 'HopePageId.login',
      'register_page.dart': 'HopePageId.register',
      'password_reset_page.dart': 'HopePageId.passwordReset',
      'jobs_page.dart': 'HopePageId.explore',
      'my_applications_page.dart': 'HopePageId.myApplications',
      'offers_page.dart': 'HopePageId.offers',
      'transactions_page.dart': 'HopePageId.activity',
      'wallet_page.dart': 'HopePageId.wallet',
      'profile_page.dart': 'HopePageId.profile',
      'notifications_page.dart': 'HopePageId.notifications',
      'chat_page.dart': 'HopePageId.chat',
      'job_satisfaction_page.dart': 'HopePageId.satisfaction',
      'financial_insights_page.dart': 'HopePageId.financialInsights',
      'admin_page.dart': 'HopePageId.admin',
      'admin_operations_page.dart': 'HopePageId.adminOperations',
      'admin_disputes_page.dart': 'HopePageId.adminDisputes',
      'recommendation_onboarding_page.dart': 'HopePageId.recommendation',
      'create_job_page.dart': 'HopePageId.createOpportunity',
      'saved_searches_page.dart': 'HopePageId.savedSearches',
      'notification_devices_page.dart': 'HopePageId.notificationDevices',
      'privacy_center_page.dart': 'HopePageId.privacy',
      'admin_access_page.dart': 'HopePageId.adminAccess',
      'job_detail_page.dart': 'HopePageId.opportunityDetail',
      'employer_candidate_matches_page.dart': 'HopePageId.candidateMatches',
      'transaction_widgets.part.dart': 'HopePageId.transactionDetail',
      'about_page.dart': 'HopePageId.about',
    };
    for (final entry in screens.entries) {
      expect(architecture, contains(entry.value), reason: entry.key);
    }
  });

  test('profile keeps account and work surfaces separate', () {
    final source = _read('lib/features/profile/profile_page.dart');
    expect(source, contains('HopeProductDomain.account'));
    expect(source, contains('HopeProductDomain.work'));
    expect(source, contains('Work center'));
    expect(source, contains('Work destinations'));
    expect(source, isNot(contains('FutureBuilder<List<HopeApplication>>')));
  });

  test('profile does not retain removed application state', () {
    final source = _read('lib/features/profile/profile_page.dart');
    expect(source, isNot(contains('_applicationBusyId')));
    expect(source, isNot(contains('_applicationsReloadError')));
    expect(source, isNot(contains('_applicationsReloadRequestId')));
    expect(source, isNot(contains('applications = _controller.loadApplications')));
  });

  test('admin control surfaces do not stack legacy AppBars over PremiumHeader', () {
    const paths = <String>[
      'lib/features/admin/admin_page.dart',
      'lib/features/admin/admin_operations_page.dart',
      'lib/features/admin/admin_disputes_page.dart',
    ];
    for (final path in paths) {
      final source = _read(path);
      expect(source, isNot(contains('appBar: AppBar(')), reason: path);
      expect(source, contains('HopeProductDomain.control'), reason: path);
    }
  });
}
