import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('opportunity card groups large Toman amounts for readability',
      (tester) async {
    final job = HopeJob.fromMap({
      'id': 'job-2',
      'title': 'طراحی اپ',
      'description': 'یک توضیح کافی برای نمایش فرصت.',
      'categoryId': 'design',
      'category': 'طراحی',
      'jobType': 'FIXED',
      'budgetMin': '1000000',
      'budgetMax': '1500000',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: OpportunityCard(job: job),
        ),
      ),
    );

    final amountTexts = find
        .byWidgetPredicate(
          (widget) =>
              widget is Text && (widget.data?.contains('تومان') ?? false),
        )
        .evaluate()
        .map((element) => (element.widget as Text).data)
        .whereType<String>()
        .toList();
    expect(amountTexts, contains('1,000,000 – 1,500,000 تومان'));
  });

  testWidgets('opportunity card labels mission budget in Toman',
      (tester) async {
    final job = HopeJob.fromMap({
      'id': 'job-1',
      'title': 'طراحی صفحه',
      'description': 'یک توضیح کافی برای نمایش فرصت.',
      'categoryId': 'design',
      'category': 'طراحی',
      'jobType': 'FIXED',
      'budgetMin': '100000',
      'budgetMax': '200000',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: OpportunityCard(job: job),
        ),
      ),
    );

    expect(find.textContaining('تومان'), findsOneWidget);
  });


  testWidgets('opportunity card localizes canonical labels in both locales',
      (tester) async {
    final job = HopeJob.fromMap({
      'id': 'job-localized-card',
      'title': '',
      'description': 'Localized card test.',
      'categoryId': 'design',
      'category': 'Design',
      'jobType': 'FIXED',
      'budgetMin': '100000',
      'budgetMax': '200000',
      'kind': 'MISSION',
      'visibility': 'SPECIALIZED',
      'status': 'OPEN',
      'recommendationReasons': [
        'SKILL_MATCH',
        'CATEGORY_MATCH',
        'VERY_NEAR',
        'NEARBY',
        'REMOTE',
        'WORK_MODE_MATCH',
        'SALARY_FIT',
        'BEHAVIOR_MATCH',
        'GENERAL_MATCH',
      ],
    });

    final expected = {
      'fa': const [
        'بدون عنوان',
        'ماموریت',
        'تخصصی',
        'بودجه ماموریت',
        'دلایل تطابق',
        'مهارت مرتبط',
        'دسته‌بندی مرتبط',
        'خیلی نزدیک',
        'نزدیک',
        'آنلاین',
        'نوع همکاری مناسب',
        'تناسب درآمد',
        'متناسب با ترجیحات',
        'تناسب کلی',
        'مشاهده و اقدام برای ماموریت',
        'مشاهده جزئیات',
      ],
      'en': const [
        'Untitled',
        'Mission',
        'Specialized',
        'Mission budget',
        'Match signals',
        'Skill match',
        'Category match',
        'Very near',
        'Near',
        'Remote',
        'Work mode fit',
        'Salary fit',
        'Preference fit',
        'General fit',
        'View and act on mission',
        'View details',
      ],
    };

    for (final locale in const [Locale('fa'), Locale('en')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: OpportunityCard(job: job)),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in expected[locale.languageCode]!) {
        expect(find.text(label), findsOneWidget,
            reason: 'missing ${locale.languageCode} localization: $label');
      }

      expect(
        find.textContaining(
          locale.languageCode == 'fa' ? 'تومان' : 'Toman',
        ),
        findsOneWidget,
        reason: 'missing ${locale.languageCode} currency label',
      );
    }
  });
}
