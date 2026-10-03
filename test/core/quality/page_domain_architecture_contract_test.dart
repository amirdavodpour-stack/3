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

  test('PremiumHero accepts HOPE page identity', () {
    final source = _read('lib/core/ui/premium_components.dart');
    expect(source, contains('final HopePageId? page;'));
    expect(source, contains('class PremiumHero'));
    expect(source, contains('resolvedDomain'));
  });

  test('PremiumHeader and PremiumSectionHeader accept domain semantics', () {
    final source = _read('lib/core/ui/premium_components.dart');
    expect(source, contains('HopeProductDomain? domain'));
    expect(source, contains('PremiumDomainMarker'));
  });

  test('home finance preview does not leak backend currency', () {
    final source = _read('lib/features/home/premium_home_feed.dart');
    expect(source, contains('moneyLabel(context'));
    expect(source, isNot(contains("wallet.currency == 'TOMAN'")));
    expect(source, isNot(contains(" : wallet.currency")));
  });

  test('activity states keep the same page identity', () {
    final source = _read('lib/features/transactions/transactions_page.dart');
    expect(
      RegExp(r'PremiumHeader\(\n(?!\s*page:)').allMatches(source).length,
      0,
    );
    expect(
      RegExp(r'PremiumPageFrame\(\n(?!\s*page:)').allMatches(source).length,
      0,
    );
  });

  test('opportunity detail exposes back action', () {
    final source = _read('lib/features/marketplace/job_detail_page.dart');
    expect(source, contains('PremiumIconButton'));
    expect(source, contains('بازگشت'));
  });

  test('opportunity agent uses intelligence visual language', () {
    final source = _read('lib/features/home/opportunity_agent_panel.dart');
    expect(source, contains('HopeProductDomain.intelligence'));
    expect(source, contains('PremiumDomainMarker'));
  });

  test('home places active work before discovery feed', () {
    final source = _read('lib/features/home/premium_home_feed.dart');
    final active = source.indexOf('_activeWork(context)');
    final discovery = source.indexOf('_opportunitySections(context, jobs, settings)');
    expect(active, greaterThanOrEqualTo(0));
    expect(discovery, greaterThan(active));
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
    const screens = <String, String>{
      'lib/features/home/premium_home_feed.dart': 'HopePageId.home',
      'lib/features/auth/login_page.dart': 'HopePageId.login',
      'lib/features/auth/register_page.dart': 'HopePageId.register',
      'lib/features/auth/password_reset_page.dart': 'HopePageId.passwordReset',
      'lib/features/jobs/jobs_page.dart': 'HopePageId.explore',
      'lib/features/applications/my_applications_page.dart': 'HopePageId.myApplications',
      'lib/features/offers/offers_page.dart': 'HopePageId.offers',
      'lib/features/transactions/transactions_page.dart': 'HopePageId.activity',
      'lib/features/wallet/wallet_page.dart': 'HopePageId.wallet',
      'lib/features/profile/profile_page.dart': 'HopePageId.profile',
      'lib/features/notifications/notifications_page.dart': 'HopePageId.notifications',
      'lib/features/chat/chat_page.dart': 'HopePageId.chat',
      'lib/features/jobs/job_satisfaction_page.dart': 'HopePageId.satisfaction',
      'lib/features/financial/financial_insights_page.dart': 'HopePageId.financialInsights',
      'lib/features/admin/admin_page.dart': 'HopePageId.admin',
      'lib/features/admin/admin_operations_page.dart': 'HopePageId.adminOperations',
      'lib/features/admin/admin_disputes_page.dart': 'HopePageId.adminDisputes',
      'lib/features/recommendation/recommendation_onboarding_page.dart': 'HopePageId.recommendation',
      'lib/features/marketplace/create_job_page.dart': 'HopePageId.createOpportunity',
      'lib/features/jobs/saved_searches_page.dart': 'HopePageId.savedSearches',
      'lib/features/notifications/notification_devices_page.dart': 'HopePageId.notificationDevices',
      'lib/features/privacy/privacy_center_page.dart': 'HopePageId.privacy',
      'lib/features/admin/admin_access_page.dart': 'HopePageId.adminAccess',
      'lib/features/marketplace/job_detail_page.dart': 'HopePageId.opportunityDetail',
      'lib/features/marketplace/employer_candidate_matches_page.dart': 'HopePageId.candidateMatches',
      'lib/features/transactions/transaction_widgets.part.dart': 'HopePageId.transactionDetail',
      'lib/features/about/about_page.dart': 'HopePageId.about',
    };
    for (final entry in screens.entries) {
      expect(_read(entry.key), contains(entry.value), reason: entry.key);
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

  test('profile exposes trust separately from account settings', () {
    final source = _read('lib/features/profile/profile_page.dart');
    expect(source, contains('domain: HopeProductDomain.trust'));
    expect(source, contains('اعتماد و پروفایل حرفه‌ای'));
  });

  test('profile has a single work hub header', () {
    final source = _read('lib/features/profile/profile_page.dart');
    expect(
      RegExp(r"title: _t\(context, 'مرکز کار', 'Work center'\),").allMatches(source).length,
      1,
    );
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
