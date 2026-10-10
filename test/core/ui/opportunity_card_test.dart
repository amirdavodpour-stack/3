import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('compact opportunity cards give media and value a non-competing editorial stack', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = HopeJob.fromMap({
      'id': 'compact-editorial-card', 'title': 'طراحی محصول برای اپلیکیشن',
      'category': 'طراحی', 'kind': 'MISSION', 'status': 'OPEN',
      'visibility': 'PUBLIC', 'budgetMin': '1000000', 'budgetMax': '1500000',
      'city': 'تهران',
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(body: Padding(
        padding: const EdgeInsets.all(16),
        child: OpportunityCard(job: job, variant: OpportunityCardVariant.compact),
      )),
    ));
    await tester.pumpAndSettle();
    final media = tester.getSize(find.byKey(const ValueKey('opportunity-compact-media')));
    expect(media.width, 72);
    expect(media.height, 72);
    expect(find.text('طراحی محصول برای اپلیکیشن'), findsOneWidget);
    expect(find.textContaining('تومان'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'standard opportunity cards expose the Wave F 2.0 decision anatomy',
      (tester) async {
    final job = HopeJob.fromMap({
      'id': 'job-standard-v2',
      'title': 'طراحی اپ محصول',
      'description': 'این توضیح در کارت اسکن نمایش داده نمی‌شود.',
      'categoryId': 'design',
      'category': 'طراحی محصول',
      'jobType': 'FIXED',
      'budgetMin': '1000000',
      'budgetMax': '1500000',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
      'city': 'تهران',
      'recommendationScore': 0.91,
      'distanceKm': 1.5,
      'companyName': 'استودیو هُپ',
      'workMode': 'REMOTE',
      'imageUrl': 'https://example.com/opportunity.jpg',
      'recommendationReasons': ['SKILL_MATCH', 'CATEGORY_MATCH'],
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('طراحی اپ محصول'), findsOneWidget);
    expect(find.text('استودیو هُپ'), findsOneWidget);
    expect(find.text('91% تطابق'), findsOneWidget);
    expect(find.text('دورکاری'), findsOneWidget);
    expect(find.text('تهران'), findsOneWidget);
    expect(find.text('1.5 km'), findsOneWidget);
    expect(find.text('۱٬۰۰۰٬۰۰۰ تومان تا ۱٬۵۰۰٬۰۰۰ تومان'), findsOneWidget);
    expect(find.text('طراحی محصول'), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-card-cta')), findsOneWidget);
    expect(find.text('دلایل تطابق'), findsNothing);
    expect(find.text('این توضیح در کارت اسکن نمایش داده نمی‌شود.'), findsNothing);
    expect(
      tester.getSize(find.byType(OpportunityCard)).height,
      lessThan(280),
    );
  });

  testWidgets('featured opportunity renders real media from the opportunity payload',
      (tester) async {
    const imageUrl = 'https://example.com/editorial-real.jpg';
    final job = HopeJob.fromMap({
      'id': 'job-real-media',
      'title': 'فرصت با تصویر واقعی',
      'description': 'Real media contract.',
      'categoryId': 'design',
      'category': 'Design',
      'jobType': 'FIXED',
      'budgetMin': '1500000',
      'budgetMax': '2500000',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
      'recommendationScore': 0.94,
      'imageUrl': imageUrl,
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(body: OpportunityCard(
          job: job,
          variant: OpportunityCardVariant.featured,
        )),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('opportunity-media-image')),
    );
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, imageUrl);
  });

  testWidgets('featured opportunity keeps the compact scan media on mobile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final job = HopeJob.fromMap({
      'id': 'job-featured-editorial',
      'title': 'طراحی رابط کاربری',
      'description': 'Editorial focal surface contract.',
      'categoryId': 'design',
      'category': 'Design',
      'jobType': 'FIXED',
      'budgetMin': '1500000',
      'budgetMax': '2500000',
      'kind': 'JOB',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
      'city': 'تهران',
      'recommendationScore': 0.94,
      'imageUrl': 'https://example.com/editorial.jpg',
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.featured,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('opportunity-scan-media'))),
      const Size(64, 64),
    );
    expect(
      find.byKey(const ValueKey('opportunity-media-header')),
      findsNothing,
    );
  });

  testWidgets('featured opportunity metadata stays overflow-safe at narrow card width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final job = HopeJob.fromMap({
      'id': 'job-featured-narrow',
      'title': 'طراحی رابط موبایل حرفه‌ای',
      'description': 'Narrow featured metadata regression.',
      'categoryId': 'design',
      'category': 'Design',
      'jobType': 'FIXED',
      'budgetMin': '1500000',
      'budgetMax': '2500000',
      'kind': 'MISSION',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
      'city': 'تهران',
      'recommendationScore': 0.94,
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 224,
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.featured,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'discovery featured scan card keeps the focal accent without expanding first-fold height',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'job-featured-scan',
        'title': 'توسعه‌دهنده Flutter',
        'description': 'Discovery featured scan contract.',
        'categoryId': 'software',
        'category': 'Software',
        'jobType': 'FIXED',
        'budgetMin': '1500000',
        'budgetMax': '2500000',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'تهران',
        'recommendationScore': 0.94,
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.featuredScan,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('توسعه‌دهنده Flutter'), findsOneWidget);
      expect(find.text('94% تطابق'), findsOneWidget);
      expect(
        tester.getSize(find.byType(OpportunityCard)).height,
        lessThan(280),
      );
    },
  );

  testWidgets('standard opportunity metadata stays overflow-safe at narrow card width',
      (tester) async {
    tester.view.physicalSize = const Size(440, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final job = HopeJob.fromMap({
      'id': 'job-standard-narrow',
      'title': 'توسعه Flutter برای محصول جدید',
      'description': 'Narrow standard metadata regression.',
      'categoryId': 'software',
      'category': 'نرم افزار',
      'jobType': 'FIXED',
      'budgetMin': '1500000',
      'budgetMax': '2500000',
      'kind': 'JOB',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
      'city': 'تهران',
      'recommendationScore': 0.87,
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: OpportunityCard(job: job),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Wave 37 Opportunity Card exposes type, localized category, amount and match score to semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final job = HopeJob.fromMap({
        'id': 'semantic-opportunity-card',
        'title': 'Flutter developer',
        'description': 'Accessible marketplace summary.',
        'categoryId': 'software',
        'category': 'Software',
        'kind': 'JOB',
        'jobType': 'HOURLY',
        'monthlySalary': '12000000',
        'budgetMin': '12000000',
        'city': 'تهران',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'recommendationScore': 0.94,
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
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
      final summary = tester.getSemantics(find.byType(OpportunityCard)).label;
      expect(summary, contains('فرصت شغلی'));
      expect(summary, contains('نرم‌افزار'));
      expect(summary, contains('تهران'));
      expect(summary, contains('۱۲٬۰۰۰٬۰۰۰ تومان'));
      expect(summary, contains('۹۴٪ تطابق'));
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('recommended opportunity exposes its real match score signal',
      (tester) async {
    final job = HopeJob.fromMap({
      'id': 'job-match-score',
      'title': 'Product designer',
      'description': 'A real recommendation signal test.',
      'categoryId': 'design',
      'category': 'Design',
      'jobType': 'HOURLY',
      'budgetMin': '1000000',
      'kind': 'JOB',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
      'recommendationScore': 0.94,
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
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

    expect(find.text('94% match'), findsOneWidget);
  });

  testWidgets('featured job opportunity uses the HOPE purple focal accent',
      (tester) async {
    final job = HopeJob.fromMap({
      'id': 'job-featured-job-accent',
      'title': 'Product designer',
      'description': 'Featured accent contract.',
      'categoryId': 'design',
      'category': 'Design',
      'jobType': 'FIXED',
      'budgetMin': '1500000',
      'kind': 'JOB',
      'visibility': 'PUBLIC',
      'status': 'OPEN',
      'recommendationScore': 0.94,
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: OpportunityCard(
            job: job,
            variant: OpportunityCardVariant.featured,
          ),
        ),
      ),
    );

    const primary = Color(0xFF6366F1);
    final focalGradientFound = tester.widgetList<Container>(
      find.byType(Container),
    ).any((container) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration) return false;
      final gradient = decoration.gradient;
      if (gradient is! LinearGradient || gradient.colors.isEmpty) {
        return false;
      }
      return gradient.colors.first == primary.withValues(alpha: .18);
    });

    expect(focalGradientFound, isTrue);
  });
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
    expect(amountTexts, contains('۱٬۰۰۰٬۰۰۰ تومان تا ۱٬۵۰۰٬۰۰۰ تومان'));
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
        'آنلاین',
        'مشاهده و اقدام برای ماموریت',
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
        'Remote',
        'View and act on mission',
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
          home: Scaffold(
            body: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.expanded,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in expected[locale.languageCode]!) {
        expect(find.text(label), findsOneWidget,
            reason: 'missing ${locale.languageCode} localization: $label');
      }

      expect(
        find.textContaining(
          locale.languageCode == 'fa' ? 'تومان' : 'TOMAN',
        ),
        findsOneWidget,
        reason: 'missing ${locale.languageCode} currency label',
      );

    }
  });
  testWidgets(
    'featured scan card compresses secondary metadata into one compact row on phone widths',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'job-featured-scan-compact-density',
        'title': 'طراحی رابط موبایل حرفه‌ای',
        'description': 'Compact discovery density contract.',
        'categoryId': 'design',
        'category': 'Software',
        'jobType': 'FIXED',
        'budgetMin': '1500000',
        'budgetMax': '2500000',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'تهران',
        'recommendationScore': 0.94,
        'workMode': 'REMOTE',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.featuredScan,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('۱٬۵۰۰٬۰۰۰ تومان تا ۲٬۵۰۰٬۰۰۰ تومان'), findsOneWidget);
      expect(find.text('تهران'), findsOneWidget);
      expect(
        tester.getSize(find.byType(OpportunityCard)).height,
        lessThan(235),
      );
    },
  );

  testWidgets(
    'image-less opportunity cards keep their fallback subordinate across shared variants',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'wave33-no-media',
        'title': 'توسعه‌دهنده Flutter',
        'description': 'Missing-media fallback hierarchy contract.',
        'categoryId': 'software',
        'category': 'Software',
        'jobType': 'FIXED',
        'budgetMin': '1500000',
        'budgetMax': '2500000',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'تهران',
        'recommendationScore': 0.94,
      });

      Widget cardHost(OpportunityCardVariant variant) => MaterialApp(
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: 260,
                    child: OpportunityCard(job: job, variant: variant),
                  ),
                ),
              ),
            ),
          );

      const variants = <OpportunityCardVariant>[
        OpportunityCardVariant.compact,
        OpportunityCardVariant.compactGrid,
        OpportunityCardVariant.standard,
        OpportunityCardVariant.featured,
        OpportunityCardVariant.featuredScan,
      ];

      for (final variant in variants) {
        await tester.pumpWidget(cardHost(variant));
        await tester.pumpAndSettle();

        final fallback = find.byKey(
          const ValueKey('opportunity-fallback-icon-container'),
        );
        expect(fallback, findsOneWidget, reason: 'missing-media placeholder must exist');
        final size = tester.getSize(fallback);
        expect(
          size.width,
          lessThanOrEqualTo(32),
          reason: 'fallback icon container must remain at most 32dp wide',
        );
        expect(
          size.height,
          lessThanOrEqualTo(32),
          reason: 'fallback icon container must remain at most 32dp high',
        );
        expect(find.text('توسعه‌دهنده Flutter'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      // Also cover the non-compact featured-media header on a wider viewport.
      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpWidget(cardHost(OpportunityCardVariant.featured));
      await tester.pumpAndSettle();
      final featuredFallback = find.byKey(
        const ValueKey('opportunity-fallback-icon-container'),
      );
      expect(featuredFallback, findsOneWidget);
      final featuredSize = tester.getSize(featuredFallback);
      expect(featuredSize.width, lessThanOrEqualTo(32));
      expect(featuredSize.height, lessThanOrEqualTo(32));
      expect(find.byKey(const ValueKey('opportunity-media-header')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'image-less fallback resolves categoryId and rejects non-web media URLs',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'wave36-category-id-fallback',
        'title': 'توسعه‌دهنده Flutter',
        'categoryId': 'software',
        'imageUrl': 'file:///tmp/not-a-network-image.png',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'تهران',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.compact,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final categorySemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').contains('نرم‌افزار'),
      );
      expect(categorySemantics, findsOneWidget);
      final fallbackSurface = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('opportunity-fallback-media-surface')),
      );
      final fallbackDecoration = fallbackSurface.decoration as BoxDecoration;
      final fallbackGradient = fallbackDecoration.gradient! as LinearGradient;
      expect(
        fallbackGradient.colors.first,
        HopeV2Colors.primary.withValues(alpha: .09),
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is NetworkImage,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'featured no-media opportunity uses a shorter hero with a separate title',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const title = 'طراحی محصول برای بازار خدمات';
      final job = HopeJob.fromMap({
        'id': 'wave36-featured-no-media',
        'title': title,
        'categoryId': 'design',
        'kind': 'MISSION',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'تهران',
        'budgetMin': '1500000',
        'budgetMax': '2500000',
        'recommendationScore': 0.93,
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.featured,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final header = find.byKey(
        const ValueKey('opportunity-media-header'),
      );
      final fallbackTitle = find.byKey(
        const ValueKey('opportunity-featured-fallback-title'),
      );
      expect(header, findsOneWidget);
      expect(tester.getSize(header).height, lessThanOrEqualTo(80));
      expect(fallbackTitle, findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(
        tester.getRect(fallbackTitle).top,
        greaterThanOrEqualTo(tester.getRect(header).bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 34 compact opportunity city uses a theme-aware readable foreground in light mode',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const city = 'تهران';
      final theme = ThemeData.light();
      final job = HopeJob.fromMap({
        'id': 'compact-light-city',
        'title': 'طراحی محصول',
        'category': 'طراحی',
        'kind': 'MISSION',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1000000',
        'budgetMax': '1500000',
        'city': city,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.compact,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cityText = tester.widget<Text>(
        find.byKey(const ValueKey('opportunity-card-compact-location')),
      );
      expect(cityText.data, city);
      expect(cityText.style?.color, theme.colorScheme.onSurfaceVariant);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 34 compact-grid card remains usable at 1.5x text scale with legible key metadata',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'compact-grid-large-text',
        'title': 'طراحی رابط کاربری حرفه‌ای',
        'category': 'طراحی',
        'kind': 'MISSION',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1000000',
        'budgetMax': '1500000',
        'city': 'تهران',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 156,
                height: 270,
                child: OpportunityCard(
                  job: job,
                  variant: OpportunityCardVariant.compactGrid,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cityText = tester.widget<Text>(
        find.byKey(const ValueKey('opportunity-card-compact-grid-location')),
      );
      final budgetText = tester.widget<Text>(
        find.byKey(const ValueKey('opportunity-card-compact-grid-budget')),
      );
      expect(cityText.style?.fontSize, greaterThanOrEqualTo(11.5));
      expect(budgetText.style?.fontSize, greaterThanOrEqualTo(10.5));
      expect(find.text('طراحی رابط کاربری حرفه‌ای'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 35 recognized opportunity categories use the active locale',
    (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'localized-software-category',
        'title': 'Flutter developer',
        'categoryId': 'software',
        'category': 'Software',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'PUBLISHED',
        'city': 'Tehran',
        'monthlySalary': '12000000',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.standard,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نرم‌افزار'), findsOneWidget);
      expect(find.text('Software'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'standard opportunity card visibly localizes categoryId when category label is absent',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'category-id-visible-standard',
        'title': 'توسعه‌دهنده Flutter',
        'categoryId': 'software',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'تهران',
        'monthlySalary': '12000000',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.standard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نرم‌افزار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded opportunity card visibly localizes categoryId when category label is absent',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'category-id-visible-expanded',
        'title': 'توسعه‌دهنده Flutter',
        'description': 'جزئیات فرصت توسعه نرم‌افزار',
        'categoryId': 'software',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'تهران',
        'monthlySalary': '12000000',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.expanded,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نرم‌افزار'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opportunity card does not infer remote work from a missing city',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'no-city-no-work-mode',
        'title': 'توسعه‌دهنده Flutter',
        'categoryId': 'software',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'monthlySalary': '12000000',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(body: OpportunityCard(job: job)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مکان مشخص نشده'), findsOneWidget);
      expect(find.text('آنلاین'), findsNothing);
      final summary = tester.getSemantics(find.byType(OpportunityCard)).label;
      expect(summary, contains('مکان مشخص نشده'));
      expect(summary, isNot(contains('آنلاین')));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opportunity card shows remote only when work mode explicitly says REMOTE',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'remote-mode-no-city',
        'title': 'Flutter developer',
        'categoryId': 'software',
        'workMode': 'REMOTE',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'monthlySalary': '12000000',
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(body: OpportunityCard(job: job)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('دورکاری'), findsOneWidget);
      expect(find.text('مکان مشخص نشده'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
