import 'package:flutter/material.dart';

import '../theme/hope_v2_design.dart';

/// The product-level domains that define HOPE's page and visual vocabulary.
///
/// A page can contain many widgets, but its primary domain should remain clear:
/// discovery, work, finance, account, trust, control, communication,
/// collaboration, intelligence, or overview.
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
