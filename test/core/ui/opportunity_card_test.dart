import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'category fallback uses distinct icons and artwork for supported and unknown categories',
    (tester) async {
      const categories = <({String slug, Object icon})>[
        (slug: 'software', icon: HopeV2Icons.web),
        (slug: 'design', icon: HopeV2Icons.featured),
        (slug: 'marketing', icon: HopeV2Icons.activity),
        (slug: 'content', icon: HopeV2Icons.description),
        (slug: 'finance', icon: HopeV2Icons.payments),
        (slug: 'education', icon: HopeV2Icons.skills),
        (slug: 'support', icon: HopeV2Icons.message),
        (slug: 'construction', icon: HopeV2Icons.workshop),
        (slug: 'video', icon: HopeV2Icons.device),
        (slug: 'data', icon: HopeV2Icons.insights),
        (slug: 'sales', icon: HopeV2Icons.activitySelected),
        (slug: 'other-category', icon: HopeV2Icons.category),
      ];
      final resolvedIcons = <Object>[];

      for (final category in categories) {
        final job = HopeJob.fromMap({
          'id': 'category-fallback-${category.slug}',
          'title': 'Opportunity ${category.slug}',
          'categoryId': category.slug,
          'kind': 'JOB',
          'status': 'OPEN',
          'visibility': 'PUBLIC',
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
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: OpportunityCard(
                  job: job,
                  variant: OpportunityCardVariant.compact,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fallback = find.byKey(
          const ValueKey('opportunity-fallback-icon-container'),
        );
        expect(fallback, findsOneWidget, reason: category.slug);

        final artwork = find.byKey(
          ValueKey('opportunity-fallback-category-artwork-${category.slug}'),
        );
        expect(
          artwork,
          findsOneWidget,
          reason: '${category.slug} needs its deterministic vector cover artwork.',
        );
        expect(
          tester.widget<CustomPaint>(artwork).painter,
          isA<CustomPainter>(),
          reason: '${category.slug} artwork must be rendered by a stable painter.',
        );

        final iconFinder = find.descendant(
          of: fallback,
          matching: find.byType(HopeIcon),
        );
        expect(iconFinder, findsOneWidget, reason: category.slug);
        final actualIcon = tester.widget<HopeIcon>(iconFinder).icon;
        expect(actualIcon, category.icon, reason: category.slug);
        resolvedIcons.add(actualIcon);
        expect(tester.takeException(), isNull, reason: category.slug);
      }

      expect(
        resolvedIcons.toSet(),
        hasLength(categories.length),
        reason: 'Each supported category needs a distinct fallback icon.',
      );
    },
  );

  testWidgets(
    'opportunity scan location metadata wraps fully at 1.5x text scale',
    (tester) async {
      const longCity =
          'Greater Metropolitan District North-East Administrative Corridor';
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'scan-long-city-large-text',
        'title': 'Senior product designer for a multilingual platform',
        'description': 'Long location metadata regression.',
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'MISSION',
        'jobType': 'FIXED',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1500000',
        'budgetMax': '2500000',
        'recommendationScore': 0.94,
        'city': longCity,
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
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

      final cityFinder = find.text(longCity);
      expect(cityFinder, findsOneWidget);
      final cityText = tester.widget<Text>(cityFinder);
      expect(
        cityText.maxLines,
        isNull,
        reason:
            'Opportunity location metadata must not remain one-line ellipsized when text is enlarged.',
      );
      expect(cityText.overflow, TextOverflow.visible);
      expect(
        tester.renderObject<RenderParagraph>(cityFinder).didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'featured scan tags keep complete labels on one line at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'featured-scan-tags-large-text',
        'title': 'Senior software designer opportunity',
        'description': 'Large-text tag wrapping regression.',
        'categoryId': 'software',
        'category': 'Software',
        'jobType': 'FIXED',
        'budgetMin': '1000000',
        'budgetMax': '1500000',
        'kind': 'MISSION',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'city': 'Tehran',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: child!,
          ),
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: OpportunityCard(
                job: job,
                variant: OpportunityCardVariant.featuredScan,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['Mission', 'Software', '94% match']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: '$label must remain available.');
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        final lineBoxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: label.length),
        );
        expect(
          lineBoxes,
          hasLength(1),
          reason: '$label must not split across multiple lines at 1.5x.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
      'featured scan opportunity cards prioritize real category, match and budget in a compact composition',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final job = HopeJob.fromMap({
      'id': 'featured-scan-opportunity',
      'title': 'طراحی محصول برای بازار کار',
      'description': 'Real opportunity card fixture.',
      'categoryId': 'design',
      'category': 'Design',
      'kind': 'MISSION',
      'jobType': 'FIXED',
      'status': 'OPEN',
      'visibility': 'PUBLIC',
      'budgetMin': '1000000',
      'budgetMax': '1500000',
      'recommendationScore': 0.94,
      'city': 'تهران',
    });
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('opportunity-featured-scan-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-featured-scan-media')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-featured-scan-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-featured-scan-budget')), findsOneWidget);
    expect(find.text('۹۴٪ تطابق'), findsOneWidget);
    expect(find.text('طراحی'), findsOneWidget);
    expect(find.textContaining('تومان'), findsOneWidget);
    final budget = tester.widget<Text>(
      find.byKey(const ValueKey('opportunity-featured-scan-budget')),
    );
    expect(budget.style?.color, HopeV2Colors.moneyTextDark);
    expect(budget.style?.color, isNot(HopeV2Colors.primaryDark));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact opportunity keeps city beside the full budget on a darker, shorter card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final job = HopeJob.fromMap({
        'id': 'compact-city-budget-inline',
        'title': 'توسعه Flutter برای محصول جدید',
        'category': 'نرم‌افزار',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '15000000',
        'budgetMax': '25000000',
        'city': 'تهران',
      });

      await tester.pumpWidget(MaterialApp(
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
      ));
      await tester.pumpAndSettle();

      final cityFinder = find.byKey(
        const ValueKey('opportunity-card-compact-location'),
      );
      final budgetFinder = find.byKey(
        const ValueKey('opportunity-card-compact-budget'),
      );
      final cityRect = tester.getRect(cityFinder);
      final budgetRect = tester.getRect(budgetFinder);
      expect(find.text('تهران'), findsOneWidget);
      expect(
        cityRect.top < budgetRect.bottom && budgetRect.top < cityRect.bottom,
        isTrue,
        reason:
            'At default text scale a short city must share the budget metadata row instead of adding a separate line.',
      );

      final media = tester.getSize(
        find.byKey(const ValueKey('opportunity-compact-media')),
      );
      expect(media.width, 64);
      expect(media.height, 64);

      final surface = tester.widget<Container>(
        find.byKey(const ValueKey('opportunity-card-surface')),
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.color, HopeV2Colors.darkSurface);
      final renderedBudget = tester.widget<Text>(budgetFinder).data!;
      expect(renderedBudget, contains('۱۵٬۰۰۰٬۰۰۰'));
      expect(renderedBudget, contains('۲۵٬۰۰۰٬۰۰۰'));
      expect(renderedBudget, contains('تومان'));
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(media.width, 64);
    expect(media.height, 64);
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
    expect(find.text('۹۱٪ تطابق'), findsOneWidget);
    expect(find.text('دورکاری'), findsOneWidget);
    expect(find.text('تهران'), findsOneWidget);
    expect(
      find.text('1.5 km'),
      findsNothing,
      reason: 'Backend distance is measured to the city centre, not to this opportunity.',
    );
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
      const Size(56, 56),
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
      expect(find.text('۹۴٪ تطابق'), findsOneWidget);
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
    'compact budget semantics use one localized currency unit for ranges and single values',
    (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      HopeJob budgetJob(String minimum, String maximum) => HopeJob.fromMap({
            'id': 'compact-semantic-budget',
            'title': 'Opportunity range',
            'description': 'Compact currency semantics contract.',
            'kind': 'MISSION',
            'visibility': 'PUBLIC',
            'status': 'OPEN',
            'city': 'Tehran',
            'budgetMin': minimum,
            'budgetMax': maximum,
          });

      Future<String> semanticSummary(Locale locale, HopeJob job) async {
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
                variant: OpportunityCardVariant.compact,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSemantics(find.byType(OpportunityCard)).label;
      }

      try {
        final faSummary = await semanticSummary(
          const Locale('fa'),
          budgetJob('1200000', '2500000'),
        );
        expect(faSummary, contains('۱٬۲۰۰٬۰۰۰ تا ۲٬۵۰۰٬۰۰۰ تومان'));
        expect(faSummary.split('تومان').length - 1, 1);

        final enSummary = await semanticSummary(
          const Locale('en'),
          budgetJob('1200000', '2500000'),
        );
        expect(enSummary, contains('1,200,000 – 2,500,000 TOMAN'));
        expect(enSummary.split('TOMAN').length - 1, 1);

        final singleValueSummary = await semanticSummary(
          const Locale('en'),
          budgetJob('1200000', '1200000'),
        );
        expect(singleValueSummary, contains('1,200,000 TOMAN'));
        expect(singleValueSummary.split('TOMAN').length - 1, 1);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    },
  );

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
    final matchTagFinder = find.ancestor(
      of: find.text('94% match'),
      matching: find.byType(PremiumTag),
    );
    expect(matchTagFinder, findsOneWidget);
    final matchTag = tester.widget<PremiumTag>(matchTagFinder);
    expect(
      matchTag.color,
      HopeV2SemanticColors.info(tester.element(find.text('94% match'))),
      reason: 'Match is an informational signal, not a successful lifecycle state.',
    );
  });

  testWidgets('featured job opportunity uses the warm-neutral focal accent',
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

    const primary = HopeV2Colors.primaryDark;
    final focalGradientFound = tester.widgetList<Container>(
      find.byType(Container),
    ).any((container) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration) return false;
      final gradient = decoration.gradient;
      if (gradient is! LinearGradient || gradient.colors.isEmpty) {
        return false;
      }
      return gradient.colors.first == primary.withValues(alpha: .12);
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


  testWidgets(
    'featured opportunity exposes one localized model-backed match rationale only when known',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'featured-match-rationale',
        'title': 'طراحی محصول برای بازار کار',
        'description': 'Real opportunity fixture.',
        'categoryId': 'design',
        'category': 'Design',
        'jobType': 'FIXED',
        'budgetMin': '1000000',
        'budgetMax': '1500000',
        'kind': 'MISSION',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'recommendationScore': 0.94,
        'recommendationReasons': ['SKILL_MATCH', 'CATEGORY_MATCH'],
      });

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
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: OpportunityCard(
                  job: job,
                  variant: OpportunityCardVariant.featured,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final matchReasonFinder = find.byKey(
          const ValueKey('opportunity-card-match-reason'),
        );
        expect(matchReasonFinder, findsOneWidget);
        final matchReasonTag = tester.widget<PremiumTag>(matchReasonFinder);
        expect(
          matchReasonTag.color,
          HopeV2SemanticColors.info(tester.element(matchReasonFinder)),
          reason: 'Match rationale uses the theme-aware informational color role.',
        );
        expect(
          find.text(locale.languageCode == 'fa' ? 'مهارت مرتبط' : 'Skill match'),
          findsOneWidget,
        );
        expect(
          find.text(locale.languageCode == 'fa' ? 'دسته‌بندی مرتبط' : 'Category match'),
          findsNothing,
          reason: 'The compact featured card should expose only one rationale.',
        );
        expect(tester.takeException(), isNull);
      }

      final unknownReasonJob = HopeJob.fromMap({
        'id': 'featured-unknown-match-rationale',
        'title': 'Opportunity with an unknown reason',
        'kind': 'MISSION',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'recommendationScore': 0.88,
        'recommendationReasons': ['FUTURE_SIGNAL_CODE'],
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
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: OpportunityCard(
                job: unknownReasonJob,
                variant: OpportunityCardVariant.featured,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('opportunity-card-match-reason')),
        findsNothing,
        reason: 'Unknown backend reason codes must not leak into product UI.',
      );
      expect(find.text('FUTURE_SIGNAL_CODE'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded opportunity omits unknown match reason values',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'expanded-unknown-match-rationale',
        'title': 'Opportunity with an unknown reason',
        'description': 'Expanded reason hygiene regression.',
        'kind': 'MISSION',
        'visibility': 'SPECIALIZED',
        'status': 'OPEN',
        'recommendationReasons': ['FUTURE_SIGNAL_CODE'],
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
          home: Scaffold(
            body: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.expanded,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FUTURE_SIGNAL_CODE'), findsNothing);
      expect(find.text('Match signals'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
        'تطابق مکانی',
        'مکان مشخص نشده',
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
        'Location match',
        'Location not specified',
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
        final artwork = find.byKey(
          const ValueKey('opportunity-fallback-category-artwork-software'),
        );
        expect(artwork, findsOneWidget, reason: 'artwork must exist for $variant');
        expect(
          tester.widget<CustomPaint>(artwork).painter,
          isA<CustomPainter>(),
          reason: 'artwork must keep its stable painter for $variant',
        );
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
      final wideArtwork = find.byKey(
        const ValueKey('opportunity-fallback-category-artwork-software'),
      );
      expect(wideArtwork, findsOneWidget);
      expect(tester.widget<CustomPaint>(wideArtwork).painter, isA<CustomPainter>());
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
        HopeV2OpportunityAccents.software.withValues(alpha: .13),
        reason: 'Fallback artwork and the card frame share the muted software-category identity.',
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
    'image-less fallback artwork uses stable categoryId over a display label',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'category-artwork-stable-id',
        'title': 'توسعه‌دهنده Flutter',
        'categoryId': 'software',
        'category': 'توسعه نرم‌افزار',
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

      final artwork = find.byKey(
        const ValueKey('opportunity-fallback-category-artwork-software'),
      );
      expect(artwork, findsOneWidget);
      final icon = find.descendant(
        of: find.byKey(
          const ValueKey('opportunity-fallback-icon-container'),
        ),
        matching: find.byType(HopeIcon),
      );
      expect(tester.widget<HopeIcon>(icon).icon, HopeV2Icons.web);
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
        find.descendant(
          of: header,
          matching: find.text('۹۳٪ تطابق'),
        ),
        findsOneWidget,
        reason: 'Featured match tag must localize Persian digits and percent glyph.',
      );
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
    'standard, featured, featured-scan and expanded cards preserve full titles at 1.5x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const title =
          'Senior product design lead responsible for editorial systems, accessible financial workflows, multilingual experience strategy, component governance, and cross-functional delivery';
      final job = HopeJob.fromMap({
        'id': 'all-card-variants-long-title',
        'title': title,
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'MISSION',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1200000',
        'budgetMax': '2400000',
        'city': 'Frankfurt am Main',
      });
      const variants = [
        OpportunityCardVariant.standard,
        OpportunityCardVariant.featured,
        OpportunityCardVariant.featuredScan,
        OpportunityCardVariant.expanded,
      ];
      final clippedVariants = <String>[];

      for (final variant in variants) {
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: OpportunityCard(job: job, variant: variant),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.text(title);
        if (titleFinder.evaluate().isEmpty) {
          clippedVariants.add('${variant.name}: title missing');
        } else if (tester
            .renderObject<RenderParagraph>(titleFinder.first)
            .didExceedMaxLines) {
          clippedVariants.add(variant.name);
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '${variant.name} should reflow without layout overflow at 1.5x.',
        );
      }

      expect(
        clippedVariants,
        isEmpty,
        reason: 'Large-text titles must not be silently truncated in card variants: ${clippedVariants.join(', ')}',
      );
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

      final cityFinder =
          find.byKey(const ValueKey('opportunity-card-compact-grid-location'));
      final cityText = tester.widget<Text>(cityFinder);
      final cityRect = tester.getRect(cityFinder);
      final budgetFinder =
          find.byKey(const ValueKey('opportunity-card-compact-grid-budget'));
      final budgetText = tester.widget<Text>(budgetFinder);
      final budgetRect = tester.getRect(budgetFinder);
      expect(cityText.style?.fontSize, greaterThanOrEqualTo(12));
      expect(budgetText.style?.fontSize, greaterThanOrEqualTo(12));
      final kindText = tester.widget<Text>(
        find.byKey(const ValueKey('opportunity-card-compact-grid-kind')),
      );
      expect(
        kindText.style?.fontSize,
        greaterThanOrEqualTo(12),
        reason: 'The opportunity kind is meaningful content even in the compact-grid text mode.',
      );
      expect(find.byKey(const ValueKey('opportunity-card-compact-grid-category')), findsOneWidget);
      expect(
        budgetRect.top - cityRect.bottom,
        lessThan(28),
        reason: 'Compact grid cards should keep the real amount in the metadata scan path, not pin it to the card bottom.',
      );
      expect(find.text('طراحی رابط کاربری حرفه‌ای'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact-grid long financial ranges stay fully visible at 1.5x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'compact-grid-long-range',
        'title': 'طراحی رابط کاربری حرفه‌ای',
        'categoryId': 'design',
        'category': 'طراحی',
        'kind': 'MISSION',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '123456789012',
        'budgetMax': '987654321098',
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

      final budget = find.byKey(
        const ValueKey('opportunity-card-compact-grid-budget'),
      );
      expect(budget, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(budget);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Long financial ranges must retain the upper bound and TOMAN unit in compact grid cards.',
      );
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

  testWidgets(
    'large financial ranges remain fully visible at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'long-budget-range',
        'title': 'طراحی محصول',
        'description': 'Long-value rendering regression.',
        'categoryId': 'design',
        'category': 'Design',
        'jobType': 'FIXED',
        'budgetMin': '123456789012',
        'budgetMax': '987654321098',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 224,
                child: OpportunityCard(
                  job: job,
                  variant: OpportunityCardVariant.standard,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The default standard variant intentionally renders the compact scan
      // surface on this viewport; assert against that real amount paragraph.
      final amount = find.byKey(
        const ValueKey('opportunity-card-budget-amount'),
      );
      expect(amount, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(amount);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'The complete financial range must remain visible at 2x text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'featured scan tags wrap within the compact metadata rail without changing row count by visibility',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      HopeJob jobWithVisibility(String visibility) => HopeJob.fromMap({
            'id': 'featured-scan-tag-density',
            'title': 'طراحی رابط کاربری',
            'categoryId': 'design',
            'category': 'طراحی',
            'jobType': 'FIXED',
            'budgetMin': '1500000',
            'budgetMax': '2500000',
            'kind': 'JOB',
            'visibility': visibility,
            'status': 'OPEN',
            'city': 'تهران',
            'recommendationScore': 0.94,
            'workMode': 'REMOTE',
          });

      Widget host(String visibility) => MaterialApp(
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
                  job: jobWithVisibility(visibility),
                  variant: OpportunityCardVariant.featuredScan,
                ),
              ),
            ),
          );

      await tester.pumpWidget(host('PUBLIC'));
      await tester.pumpAndSettle();
      final publicHeight = tester.getSize(find.byType(OpportunityCard)).height;
      final rail = find.byKey(
        const ValueKey('opportunity-featured-scan-tag-rail'),
      );
      expect(rail, findsOneWidget);
      expect(tester.widget<Wrap>(rail), isA<Wrap>());
      final tags = find.descendant(
        of: rail,
        matching: find.byType(PremiumTag),
      );
      expect(tags, findsNWidgets(3));
      final railRect = tester.getRect(rail);
      for (var index = 0; index < tags.evaluate().length; index++) {
        final tagRect = tester.getRect(tags.at(index));
        expect(tagRect.left, greaterThanOrEqualTo(railRect.left));
        expect(tagRect.right, lessThanOrEqualTo(railRect.right));
      }

      await tester.pumpWidget(host('SPECIALIZED'));
      await tester.pumpAndSettle();
      final specializedHeight =
          tester.getSize(find.byType(OpportunityCard)).height;
      expect(specializedHeight, closeTo(publicHeight, 1.0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'featured mobile tags stay on one rail when a match reason is added',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      HopeJob jobWithReasons(List<String> reasons) => HopeJob.fromMap({
            'id': 'featured-tag-rail-density',
            'title': 'طراحی رابط کاربری',
            'categoryId': 'design',
            'category': 'طراحی',
            'jobType': 'FIXED',
            'budgetMin': '1500000',
            'budgetMax': '2500000',
            'kind': 'JOB',
            'visibility': 'PUBLIC',
            'status': 'OPEN',
            'city': 'تهران',
            'recommendationScore': 0.94,
            'recommendationReasons': reasons,
          });

      Widget host(List<String> reasons) => MaterialApp(
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
                  job: jobWithReasons(reasons),
                  variant: OpportunityCardVariant.featured,
                ),
              ),
            ),
          );

      await tester.pumpWidget(host(const []));
      await tester.pumpAndSettle();
      final baseHeight = tester.getSize(find.byType(OpportunityCard)).height;

      await tester.pumpWidget(host(const ['SKILL_MATCH']));
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('opportunity-scan-tag-rail'));
      expect(rail, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(rail).scrollDirection,
        Axis.horizontal,
      );
      expect(
        tester.getSize(find.byType(OpportunityCard)).height,
        closeTo(baseHeight, 1.0),
      );
      expect(find.byKey(const ValueKey('opportunity-card-match-reason')), findsOneWidget);
      final amount = tester.widget<Text>(
        find.byKey(const ValueKey('opportunity-card-budget-amount')),
      );
      expect(amount.style?.color, HopeV2Colors.moneyTextDark);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opportunity cards carry a category-specific accent rail in light and dark themes',
    (tester) async {
      HopeJob jobFor(String category) => HopeJob.fromMap({
            'id': 'card-accent-$category',
            'title': 'A considered product experience',
            'categoryId': category,
            'category': category,
            'kind': 'JOB',
            'status': 'OPEN',
            'visibility': 'PUBLIC',
            'budgetMin': '1200000',
            'city': 'Tehran',
          });

      Future<Color> accentFor(String category, Brightness brightness) async {
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
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: OpportunityCard(job: jobFor(category)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rail = find.byKey(
          const ValueKey('opportunity-card-accent-rail'),
        );
        expect(rail, findsOneWidget);
        expect(tester.getSize(rail).width, greaterThan(0));

        final decoration = tester.widget<Container>(rail).decoration;
        expect(decoration, isA<BoxDecoration>());
        final gradient = (decoration! as BoxDecoration).gradient;
        expect(gradient, isA<LinearGradient>());
        expect(tester.takeException(), isNull);
        return (gradient! as LinearGradient).colors[1];
      }

      for (final brightness in [Brightness.light, Brightness.dark]) {
        final designAccent = await accentFor('design', brightness);
        final softwareAccent = await accentFor('software', brightness);
        expect(
          designAccent,
          isNot(softwareAccent),
          reason: 'Category artwork should carry the same unique identity into the card frame.',
        );
      }
    },
  );


  testWidgets(
    'opportunity card action cue stays compact and follows RTL/LTR across shared layouts',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'opportunity-card-action-affordance',
        'title': 'Design a better product',
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1200000',
        'budgetMax': '2400000',
        'city': 'Tehran',
      });

      const variants = [
        OpportunityCardVariant.compact,
        OpportunityCardVariant.standard,
        OpportunityCardVariant.featured,
        OpportunityCardVariant.featuredScan,
        OpportunityCardVariant.expanded,
      ];
      for (final locale in const [Locale('fa'), Locale('en')]) {
        for (final variant in variants) {
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
              theme: ThemeData(brightness: Brightness.light),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OpportunityCard(job: job, variant: variant),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final affordance = find.byKey(
            const ValueKey('opportunity-card-action-affordance'),
          );
          expect(
            affordance,
            findsOneWidget,
            reason: 'Missing action cue for $variant in ${locale.languageCode}.',
          );
          expect(
            tester.getSize(affordance),
            const Size(30, 30),
            reason: 'The decorative cue must stay compact; the card owns the tap target.',
          );
          final arrow = tester.widget<HopeIcon>(
            find.descendant(of: affordance, matching: find.byType(HopeIcon)),
          );
          expect(
            arrow.icon,
            locale.languageCode == 'fa'
                ? HopeV2Icons.arrowLeft
                : HopeV2Icons.arrowRight,
            reason: 'The detail affordance must follow text direction.',
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );


  testWidgets(
    'repeated opportunity cards stay quiet while featured cards own surface depth',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'opportunity-card-surface-hierarchy',
        'title': 'A useful opportunity, clearly presented',
        'categoryId': 'software',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '800000',
        'city': 'Tehran',
      });

      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final variant in [
          OpportunityCardVariant.standard,
          OpportunityCardVariant.featured,
          OpportunityCardVariant.featuredScan,
        ]) {
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
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OpportunityCard(job: job, variant: variant),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final surfaceFinder = find.byKey(
            const ValueKey('opportunity-card-surface'),
          );
          expect(surfaceFinder, findsOneWidget);
          final decoration =
              tester.widget<Container>(surfaceFinder).decoration;
          expect(decoration, isA<BoxDecoration>());
          final box = decoration! as BoxDecoration;
          final focal = variant == OpportunityCardVariant.featured ||
              variant == OpportunityCardVariant.featuredScan;

          expect(
            box.boxShadow,
            focal ? isNotEmpty : isEmpty,
            reason: 'Only focal cards should carry elevation: $variant / $brightness.',
          );
          expect(
            box.gradient != null,
            focal,
            reason: 'Only focal cards should use the stronger hero gradient.',
          );
          if (!focal) {
            expect(
              box.color,
              isNotNull,
              reason: 'Repeated results need a calm, readable surface.',
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );


  testWidgets(
    'Persian media category label shares the canonical accent across the card and fallback artwork',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'persian-media-category-accent',
        'title': 'تولید ویدیو برای برند',
        'category': 'تولید ویدیو و صدا',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
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
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OpportunityCard(job: job),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rail = tester.widget<Container>(
        find.byKey(const ValueKey('opportunity-card-accent-rail')),
      );
      final railGradient = (rail.decoration! as BoxDecoration).gradient!
          as LinearGradient;
      expect(
        railGradient.colors[1],
        HopeV2OpportunityAccents.media.withValues(alpha: .88),
      );

      final fallback = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('opportunity-fallback-media-surface')),
      );
      final fallbackDecoration = fallback.decoration as BoxDecoration;
      final fallbackGradient =
          fallbackDecoration.gradient! as LinearGradient;
      expect(
        fallbackGradient.colors.first,
        HopeV2OpportunityAccents.media.withValues(alpha: .13),
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'standard dark opportunity cards preserve the intended low-opacity neutral border',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'subtle-dark-card-border',
        'title': 'طراحی محصول',
        'categoryId': 'design',
        'category': 'طراحی',
        'kind': 'MISSION',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1000000',
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
            body: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.compact,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surface = tester.widget<Container>(
        find.byKey(const ValueKey('opportunity-card-surface')),
      );
      final decoration = surface.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(
        border.top.color,
        HopeV2Colors.darkBorder,
        reason: 'withValues must not replace a deliberately low-opacity neutral border with a 55%-opaque white outline.',
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'expanded opportunity budget keeps the full range at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'expanded-budget-range-large-text',
        'title': 'طراحی محصول',
        'description': 'Expanded card large-budget regression.',
        'categoryId': 'design',
        'category': 'Design',
        'jobType': 'FIXED',
        'budgetMin': '123456789012',
        'budgetMax': '987654321098',
        'kind': 'MISSION',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 224,
                  child: OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.expanded,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final amount = find.byKey(
        const ValueKey('opportunity-card-expanded-budget'),
      );
      expect(amount, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(amount);
      expect(
        paragraph.maxLines,
        isNull,
        reason: 'Expanded financial ranges must wrap naturally at enlarged text scales.',
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'The full Toman range must remain visible without a line cap.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'featured opportunity budget wraps fully at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'featured-budget-range-large-text',
        'title': 'طراحی محصول',
        'description': 'Featured card large-budget regression.',
        'categoryId': 'design',
        'category': 'Design',
        'jobType': 'FIXED',
        'budgetMin': '123456789012',
        'budgetMax': '987654321098',
        'kind': 'MISSION',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
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
        ),
      );
      await tester.pumpAndSettle();

      final amount = find.byKey(
        const ValueKey('opportunity-card-standard-budget'),
      );
      expect(amount, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(amount);
      expect(
        paragraph.maxLines,
        isNull,
        reason: 'Featured financial ranges must wrap naturally at enlarged text scales.',
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'The complete featured Toman range must remain visible at 2x text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standard opportunity CTA wraps fully at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'standard-cta-large-text',
        'title': 'طراحی محصول',
        'description': 'CTA wrapping regression.',
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'MISSION',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1234567',
        'budgetMax': '7654321',
        'city': 'تهران',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 224,
                  child: OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.standard,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cta = find.byKey(const ValueKey('opportunity-card-cta'));
      expect(cta, findsOneWidget);
      final ctaText = find.descendant(of: cta, matching: find.byType(Text));
      expect(ctaText, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(ctaText);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'The mission CTA must remain fully readable at enlarged text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standard opportunity company metadata wraps fully at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const company =
          'International Product Design and Engineering Consortium';
      final job = HopeJob.fromMap({
        'id': 'standard-company-large-text',
        'title': 'Product designer',
        'description': 'Company metadata wrapping regression.',
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1200000',
        'budgetMax': '2400000',
        'city': 'Tehran',
        'companyName': company,
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 224,
                  child: OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.standard,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final companyFinder = find.text(company);
      expect(companyFinder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(companyFinder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Company identity must remain readable instead of ellipsized at enlarged text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'featured scan match score tag remains fully readable at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'featured-scan-rationale-large-text',
        'title': 'Product designer',
        'description': 'Recommendation rationale wrapping regression.',
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1200000',
        'budgetMax': '2400000',
        'city': 'Tehran',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
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

      final matchScore = find.text('94% match');
      expect(matchScore, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(matchScore);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Large-text users must be able to read the complete match score tag.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standard opportunity match score tag wraps fully at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'standard-match-score-large-text',
        'title': 'Product designer',
        'description': 'Standard match-score tag wrapping regression.',
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1200000',
        'budgetMax': '2400000',
        'city': 'Tehran',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 224,
                  child: OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.standard,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final matchScore = find.text('94% match');
      expect(matchScore, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(matchScore);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Standard scan cards must preserve the complete match-score tag at enlarged text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded opportunity match score tag wraps fully at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'expanded-match-score-large-text',
        'title': 'Product designer',
        'description': 'Expanded match-score tag wrapping regression.',
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1200000',
        'budgetMax': '2400000',
        'city': 'Tehran',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 224,
                  child: OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.expanded,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scoreTag = find.byKey(
        const ValueKey('opportunity-card-expanded-match-score'),
      );
      expect(scoreTag, findsOneWidget);
      final matchScore = find.descendant(
        of: scoreTag,
        matching: find.byType(Text),
      );
      expect(matchScore, findsOneWidget);
      expect(tester.widget<Text>(matchScore).data, '94% match');
      final paragraph = tester.renderObject<RenderParagraph>(matchScore);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Expanded cards must keep the full match score visible at enlarged text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'expanded opportunity description remains fully readable at 2x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const description =
          'This opportunity needs a product designer to shape accessible financial workflows, define a multilingual editorial system, collaborate with engineering and research, document reusable components, review responsive layouts across compact and large screens, and deliver a complete implementation with clear rationale, acceptance criteria, and handoff notes for the product team.';

      final job = HopeJob.fromMap({
        'id': 'expanded-description-large-text',
        'title': 'Product designer',
        'description': description,
        'categoryId': 'design',
        'category': 'Design',
        'kind': 'JOB',
        'status': 'OPEN',
        'visibility': 'PUBLIC',
        'budgetMin': '1200000',
        'budgetMax': '2400000',
        'city': 'Tehran',
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2.0),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: 224,
                  child: OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.expanded,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionFinder = find.text(description);
      expect(descriptionFinder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(descriptionFinder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Expanded opportunity descriptions must not be silently truncated at 2x text scale.',
      );
      expect(tester.takeException(), isNull);
    },
  );

}
