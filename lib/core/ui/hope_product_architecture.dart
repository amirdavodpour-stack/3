import 'package:flutter/material.dart';

import '../theme/hope_v2_design.dart';

/// The product-level domains that define HOPE's page and visual vocabulary.
///
/// A page can contain many widgets, but its primary domain should remain clear:
/// discovery, work, finance, account, trust, control, communication,
/// collaboration, intelligence, or overview.

enum HopePageId {
  home,
  explore,
  myApplications,
  offers,
  activity,
  wallet,
  profile,
  notifications,
  chat,
  satisfaction,
  financialInsights,
  admin,
  adminOperations,
  adminDisputes,
  recommendation,
  createOpportunity,
  savedSearches,
  notificationDevices,
  privacy,
  adminAccess,
  opportunityDetail,
  candidateMatches,
  transactionDetail,
  about,
  login,
  register,
  passwordReset,
}

class HopePageSpec {
  const HopePageSpec({
    required this.domain,
    required this.titleFa,
    required this.titleEn,
    required this.purposeFa,
    required this.purposeEn,
    required this.primaryActionFa,
    required this.primaryActionEn,
  });

  final HopeProductDomain domain;
  final String titleFa;
  final String titleEn;
  final String purposeFa;
  final String purposeEn;
  final String primaryActionFa;
  final String primaryActionEn;

  String title(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en' ? titleEn : titleFa;

  String purpose(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en'
          ? purposeEn
          : purposeFa;

  String primaryAction(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en'
          ? primaryActionEn
          : primaryActionFa;
}

extension HopePageIdX on HopePageId {
  HopePageSpec get spec => switch (this) {
        HopePageId.home => const HopePageSpec(
            domain: HopeProductDomain.overview,
            titleFa: 'خانه',
            titleEn: 'Home',
            purposeFa: 'نمای کلی وضعیت و مسیر بعدی.',
            purposeEn: 'Overview of status and the next path.',
            primaryActionFa: 'ادامه',
            primaryActionEn: 'Continue',
          ),
        HopePageId.explore => const HopePageSpec(
            domain: HopeProductDomain.discovery,
            titleFa: 'کاوش فرصت‌ها',
            titleEn: 'Explore opportunities',
            purposeFa: 'جست‌وجو و ارزیابی فرصت‌های کاری.',
            purposeEn: 'Search and evaluate work opportunities.',
            primaryActionFa: 'مشاهده فرصت',
            primaryActionEn: 'Open opportunity',
          ),
        HopePageId.myApplications => const HopePageSpec(
            domain: HopeProductDomain.work,
            titleFa: 'درخواست‌های من',
            titleEn: 'My applications',
            purposeFa: 'پیگیری چرخه درخواست‌های کاری.',
            purposeEn: 'Track the work-application lifecycle.',
            primaryActionFa: 'پیگیری درخواست',
            primaryActionEn: 'Track application',
          ),
        HopePageId.offers => const HopePageSpec(
            domain: HopeProductDomain.work,
            titleFa: 'پیشنهادها',
            titleEn: 'Offers',
            purposeFa: 'مدیریت پیشنهادهای همکاری.',
            purposeEn: 'Manage collaboration offers.',
            primaryActionFa: 'بررسی پیشنهاد',
            primaryActionEn: 'Review offer',
          ),
        HopePageId.activity => const HopePageSpec(
            domain: HopeProductDomain.work,
            titleFa: 'فعالیت',
            titleEn: 'Activity',
            purposeFa: 'مرکز رویدادها و پیگیری اجرای همکاری.',
            purposeEn: 'Track events and active work execution.',
            primaryActionFa: 'باز کردن فعالیت',
            primaryActionEn: 'Open activity',
          ),
        HopePageId.wallet => const HopePageSpec(
            domain: HopeProductDomain.finance,
            titleFa: 'کیف پول',
            titleEn: 'Wallet',
            purposeFa: 'موجودی، وجه محافظت‌شده و تراکنش‌ها.',
            purposeEn: 'Balance, protected funds, and transactions.',
            primaryActionFa: 'مدیریت وجه',
            primaryActionEn: 'Manage funds',
          ),
        HopePageId.profile => const HopePageSpec(
            domain: HopeProductDomain.account,
            titleFa: 'پروفایل',
            titleEn: 'Profile',
            purposeFa: 'هویت و تنظیمات حساب.',
            purposeEn: 'Account identity and settings.',
            primaryActionFa: 'ویرایش حساب',
            primaryActionEn: 'Edit account',
          ),
        HopePageId.notifications => const HopePageSpec(
            domain: HopeProductDomain.communication,
            titleFa: 'اعلان‌ها',
            titleEn: 'Notifications',
            purposeFa: 'پیگیری پیام‌ها و رخدادهای سیستمی.',
            purposeEn: 'Track system messages and events.',
            primaryActionFa: 'بررسی اعلان',
            primaryActionEn: 'Review notification',
          ),
        HopePageId.chat => const HopePageSpec(
            domain: HopeProductDomain.collaboration,
            titleFa: 'گفتگو',
            titleEn: 'Chat',
            purposeFa: 'ارتباط انسانی در بستر همکاری.',
            purposeEn: 'Human communication inside a collaboration.',
            primaryActionFa: 'ارسال پیام',
            primaryActionEn: 'Send message',
          ),
        HopePageId.satisfaction => const HopePageSpec(
            domain: HopeProductDomain.trust,
            titleFa: 'رضایت همکاری',
            titleEn: 'Work satisfaction',
            purposeFa: 'ثبت بازخورد و سیگنال‌های اعتماد پس از کار.',
            purposeEn: 'Capture post-work feedback and trust signals.',
            primaryActionFa: 'ثبت رضایت',
            primaryActionEn: 'Submit feedback',
          ),
        HopePageId.financialInsights => const HopePageSpec(
            domain: HopeProductDomain.finance,
            titleFa: 'بینش مالی',
            titleEn: 'Financial insights',
            purposeFa: 'تحلیل روندهای مالی حساب.',
            purposeEn: 'Analyze account financial trends.',
            primaryActionFa: 'بررسی روند',
            primaryActionEn: 'Review trends',
          ),
        HopePageId.admin => const HopePageSpec(
            domain: HopeProductDomain.control,
            titleFa: 'مرکز مدیریت',
            titleEn: 'Admin center',
            purposeFa: 'کنترل و عملیات محافظت‌شده سامانه.',
            purposeEn: 'Protected system control and operations.',
            primaryActionFa: 'باز کردن عملیات',
            primaryActionEn: 'Open operations',
          ),
        HopePageId.adminOperations => const HopePageSpec(
            domain: HopeProductDomain.control,
            titleFa: 'مرکز عملیات',
            titleEn: 'Operations center',
            purposeFa: 'بررسی مستقل مالی، اعتماد و خطاهای عملیاتی.',
            purposeEn: 'Review finance, trust, and operational failures separately.',
            primaryActionFa: 'رسیدگی',
            primaryActionEn: 'Review case',
          ),
        HopePageId.adminDisputes => const HopePageSpec(
            domain: HopeProductDomain.control,
            titleFa: 'اختلاف‌های همکاری',
            titleEn: 'Work disputes',
            purposeFa: 'بررسی اختلاف و اجرای اقدام مجاز.',
            purposeEn: 'Review disputes and execute permitted actions.',
            primaryActionFa: 'بررسی پرونده',
            primaryActionEn: 'Review case',
          ),
        HopePageId.recommendation => const HopePageSpec(
            domain: HopeProductDomain.intelligence,
            titleFa: 'پروفایل هوشمند کاری',
            titleEn: 'AI work profile',
            purposeFa: 'ساخت سیگنال‌های شخصی‌سازی و تطبیق.',
            purposeEn: 'Build personalization and matching signals.',
            primaryActionFa: 'تکمیل پروفایل',
            primaryActionEn: 'Complete profile',
          ),
        HopePageId.createOpportunity => const HopePageSpec(
            domain: HopeProductDomain.work,
            titleFa: 'ثبت فرصت',
            titleEn: 'Create opportunity',
            purposeFa: 'تعریف یک همکاری با شرایط روشن.',
            purposeEn: 'Define a collaboration with clear terms.',
            primaryActionFa: 'ثبت فرصت',
            primaryActionEn: 'Create opportunity',
          ),
        HopePageId.savedSearches => const HopePageSpec(
            domain: HopeProductDomain.discovery,
            titleFa: 'جست‌وجوهای ذخیره‌شده',
            titleEn: 'Saved searches',
            purposeFa: 'مدیریت فیلترهای دائمی کاوش.',
            purposeEn: 'Manage persistent discovery filters.',
            primaryActionFa: 'ایجاد جست‌وجو',
            primaryActionEn: 'Create search',
          ),
        HopePageId.notificationDevices => const HopePageSpec(
            domain: HopeProductDomain.communication,
            titleFa: 'دستگاه‌های اعلان',
            titleEn: 'Notification devices',
            purposeFa: 'مدیریت دستگاه‌های دریافت Push.',
            purposeEn: 'Manage devices registered for Push.',
            primaryActionFa: 'مدیریت دستگاه',
            primaryActionEn: 'Manage device',
          ),
        HopePageId.privacy => const HopePageSpec(
            domain: HopeProductDomain.account,
            titleFa: 'حریم خصوصی',
            titleEn: 'Privacy',
            purposeFa: 'کنترل داده و چرخه عمر حساب.',
            purposeEn: 'Control account data and lifecycle.',
            primaryActionFa: 'مدیریت داده',
            primaryActionEn: 'Manage data',
          ),
        HopePageId.adminAccess => const HopePageSpec(
            domain: HopeProductDomain.control,
            titleFa: 'احراز هویت مدیریت',
            titleEn: 'Admin access',
            purposeFa: 'ورود کنترل‌شده به مرکز مدیریت.',
            purposeEn: 'Controlled entry to admin operations.',
            primaryActionFa: 'باز کردن پنل',
            primaryActionEn: 'Unlock panel',
          ),
        HopePageId.opportunityDetail => const HopePageSpec(
            domain: HopeProductDomain.discovery,
            titleFa: 'جزئیات فرصت',
            titleEn: 'Opportunity detail',
            purposeFa: 'ارزیابی شرایط و شروع همکاری.',
            purposeEn: 'Evaluate terms and start a collaboration.',
            primaryActionFa: 'اقدام روی فرصت',
            primaryActionEn: 'Act on opportunity',
          ),
        HopePageId.candidateMatches => const HopePageSpec(
            domain: HopeProductDomain.intelligence,
            titleFa: 'انطباق متقاضیان',
            titleEn: 'Candidate matches',
            purposeFa: 'ارزیابی و مقایسه افراد بر اساس سیگنال‌های انطباق.',
            purposeEn: 'Evaluate and compare candidates by compatibility signals.',
            primaryActionFa: 'بررسی انطباق',
            primaryActionEn: 'Review match',
          ),
        HopePageId.transactionDetail => const HopePageSpec(
            domain: HopeProductDomain.finance,
            titleFa: 'جزئیات تراکنش',
            titleEn: 'Transaction detail',
            purposeFa: 'اجرای و مشاهده چرخه مالی همکاری.',
            purposeEn: 'Execute and observe the collaboration financial lifecycle.',
            primaryActionFa: 'اقدام مالی بعدی',
            primaryActionEn: 'Next financial action',
          ),
        HopePageId.login => const HopePageSpec(
            domain: HopeProductDomain.account,
            titleFa: 'ورود',
            titleEn: 'Sign in',
            purposeFa: 'ورود امن به حساب HOPE.',
            purposeEn: 'Secure entry to a HOPE account.',
            primaryActionFa: 'ورود به حساب',
            primaryActionEn: 'Sign in',
          ),
        HopePageId.register => const HopePageSpec(
            domain: HopeProductDomain.account,
            titleFa: 'ثبت‌نام',
            titleEn: 'Create account',
            purposeFa: 'ساخت حساب و آغاز مسیر HOPE.',
            purposeEn: 'Create an account and start using HOPE.',
            primaryActionFa: 'ساخت حساب',
            primaryActionEn: 'Create account',
          ),
        HopePageId.passwordReset => const HopePageSpec(
            domain: HopeProductDomain.account,
            titleFa: 'بازیابی رمز',
            titleEn: 'Password reset',
            purposeFa: 'بازیابی کنترل امن حساب.',
            purposeEn: 'Restore secure account access.',
            primaryActionFa: 'بازیابی دسترسی',
            primaryActionEn: 'Restore access',
          ),
        HopePageId.about => const HopePageSpec(
            domain: HopeProductDomain.overview,
            titleFa: 'درباره HOPE',
            titleEn: 'About HOPE',
            purposeFa: 'فهم محصول، مدل همکاری و اصول اعتماد.',
            purposeEn: 'Understand the product, work model, and trust principles.',
            primaryActionFa: 'شناخت HOPE',
            primaryActionEn: 'Understand HOPE',
          ),
      };

  HopeProductDomain get domain => spec.domain;
}

enum HopeProductDomain {
  overview,
  discovery,
  work,
  finance,
  account,
  trust,
  control,
  communication,
  collaboration,
  intelligence,
}

class HopeDomainSpec {
  const HopeDomainSpec({
    required this.labelFa,
    required this.labelEn,
    required this.icon,
    required this.accent,
    required this.descriptionFa,
    required this.descriptionEn,
  });

  final String labelFa;
  final String labelEn;
  final Object icon;
  final Color accent;
  final String descriptionFa;
  final String descriptionEn;

  String label(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en'
          ? labelEn
          : labelFa;

  String description(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'en'
          ? descriptionEn
          : descriptionFa;
}

extension HopeProductDomainX on HopeProductDomain {
  HopeDomainSpec get spec => switch (this) {
        HopeProductDomain.overview => const HopeDomainSpec(
            labelFa: 'نمای کلی',
            labelEn: 'Overview',
            icon: HopeV2Icons.home,
            accent: HopeV2Colors.primary,
            descriptionFa: 'نمای کلی و نقطه شروع HOPE.',
            descriptionEn: 'HOPE overview and starting point.',
          ),
        HopeProductDomain.discovery => const HopeDomainSpec(
            labelFa: 'کاوش',
            labelEn: 'Discovery',
            icon: HopeV2Icons.workshop,
            accent: HopeV2Colors.secondary,
            descriptionFa: 'پیدا کردن، جست‌وجو و ارزیابی فرصت‌ها.',
            descriptionEn: 'Find, search, and evaluate opportunities.',
          ),
        HopeProductDomain.work => const HopeDomainSpec(
            labelFa: 'کار',
            labelEn: 'Work',
            icon: HopeV2Icons.mission,
            accent: HopeV2Colors.primary,
            descriptionFa: 'چرخه اجرایی همکاری، درخواست و پیشنهاد.',
            descriptionEn: 'The operational work, application, and offer lifecycle.',
          ),
        HopeProductDomain.finance => const HopeDomainSpec(
            labelFa: 'مالی',
            labelEn: 'Finance',
            icon: HopeV2Icons.wallet,
            accent: HopeV2Colors.success,
            descriptionFa: 'موجودی، تراکنش، رزرو وجه و تسویه.',
            descriptionEn: 'Balance, transactions, protected funds, and settlement.',
          ),
        HopeProductDomain.account => const HopeDomainSpec(
            labelFa: 'حساب',
            labelEn: 'Account',
            icon: HopeV2Icons.profile,
            accent: HopeV2Colors.secondary,
            descriptionFa: 'هویت، تنظیمات و اطلاعات حرفه‌ای کاربر.',
            descriptionEn: 'Identity, preferences, and professional profile.',
          ),
        HopeProductDomain.trust => const HopeDomainSpec(
            labelFa: 'اعتماد',
            labelEn: 'Trust',
            icon: HopeV2Icons.verified,
            accent: HopeV2Colors.warning,
            descriptionFa: 'تأیید، رضایت، شواهد و وضعیت اعتماد.',
            descriptionEn: 'Verification, satisfaction, evidence, and trust state.',
          ),
        HopeProductDomain.control => const HopeDomainSpec(
            labelFa: 'کنترل',
            labelEn: 'Control',
            icon: HopeV2Icons.secure,
            accent: HopeV2Colors.primary,
            descriptionFa: 'مدیریت، نظارت، عملیات و تصمیم‌های محافظت‌شده.',
            descriptionEn: 'Administration, moderation, operations, and protected decisions.',
          ),
        HopeProductDomain.communication => const HopeDomainSpec(
            labelFa: 'ارتباطات',
            labelEn: 'Communication',
            icon: HopeV2Icons.notifications,
            accent: HopeV2Colors.secondary,
            descriptionFa: 'اعلان‌ها و پیام‌های سیستمی قابل پیگیری.',
            descriptionEn: 'Trackable system notifications and updates.',
          ),
        HopeProductDomain.collaboration => const HopeDomainSpec(
            labelFa: 'همکاری',
            labelEn: 'Collaboration',
            icon: HopeV2Icons.message,
            accent: HopeV2Colors.secondaryDark,
            descriptionFa: 'گفت‌وگوی انسانی در بستر همکاری.',
            descriptionEn: 'Human conversation inside a collaboration context.',
          ),
        HopeProductDomain.intelligence => const HopeDomainSpec(
            labelFa: 'هوشمندی',
            labelEn: 'Intelligence',
            icon: HopeV2Icons.insights,
            accent: HopeV2Colors.primaryDark,
            descriptionFa: 'پروفایل هوشمند، تطبیق و توصیه‌های هدفمند.',
            descriptionEn: 'Smart profiles, matching, and targeted recommendations.',
          ),
      };
}
