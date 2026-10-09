import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/hope_signature_components.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('Wave 18 grouped responsive visual contracts',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const job = HopeJob(
      id: 'wave15-opportunity',
      title: 'طراحی رابط موبایل حرفه‌ای',
      description: 'طراحی تجربه و رابط کاربری محصول موبایل',
      categoryId: 'design',
      category: 'طراحی',
      jobType: 'FIXED',
      budgetType: 'FIXED',
      budgetMin: '1500000',
      budgetMax: '2500000',
      duration: null,
      acceptanceCriteria: null,
      status: 'OPEN',
      ownerId: 'owner',
      providerId: null,
      city: 'تهران',
      kind: 'MISSION',
      visibility: 'PUBLIC',
      schedule: null,
      monthlySalary: null,
      applicationDeadline: null,
      offerCount: 0,
      isOwner: false,
      distanceKm: null,
      raw: <String, dynamic>{'recommendationScore': 94},
    );

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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PremiumHero(
                  eyebrow: 'ماموریت',
                  title: 'طراحی رابط موبایل حرفه‌ای',
                  message: 'تهران • طراحی محصول',
                  height: 184,
                  compactHero: true,
                ),
                const SizedBox(height: 12),
                const HopeOpportunityDecisionStrip(
                  matchScore: 92,
                  kind: 'ماموریت',
                  budget: '۱٬۵۰۰٬۰۰۰ تا ۲٬۵۰۰٬۰۰۰ تومان',
                  category: 'نرم‌افزار',
                  location: 'تهران',
                  breakdown: {
                    'skills': 96,
                    'category': 88,
                    'location': 72,
                    'salary': 84,
                  },
                ),
                const SizedBox(height: 12),
                const HopeOpportunityDnaSignature(
                  job: job,
                  includeBudget: false,
                  includeMatch: false,
                ),
                const SizedBox(height: 12),
                OpportunityCard(
                  job: job,
                  variant: OpportunityCardVariant.featured,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final value in ['92%', '96%', '88%', '72%', '84%']) {
      expect(find.text(value), findsOneWidget,
          reason: 'Wave 15 must render the real numeric score $value');
    }
    expect(find.textContaining(r'${score}'), findsNothing);
    expect(find.textContaining(r'${(value'), findsNothing);
    expect(find.byKey(const ValueKey('opportunity-dna-signature')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-card-cta')), findsOneWidget);
    expect(tester.widget<PremiumHero>(find.byType(PremiumHero)).compactHero,
        isTrue);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 720);
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
            padding: const EdgeInsets.all(12),
            child: PremiumEmptyState(
              key: const ValueKey('wave16-empty-state'),
              icon: HopeV2Icons.savedSearches,
              title: 'هنوز جست‌وجویی ذخیره نشده است',
              message: 'برای شروع، یک جست‌وجو ذخیره کنید.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wave16-empty-state')), findsOneWidget);
    expect(find.text('هنوز جست‌وجویی ذخیره نشده است'), findsOneWidget);
    expect(find.text('برای شروع، یک جست‌وجو ذخیره کنید.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Wave 17: scrollables must occupy the body above the dock even when
    // their slivers contain little content. Narrow navigation keeps the
    // selected label readable and accessible names remain available.
    tester.view.physicalSize = const Size(280, 720);
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
        home: PremiumPrimaryNavigationScaffold(
          selectedIndex: 3,
          onDestinationSelected: (_) {},
          child: PremiumPageFrame(
            padding: const EdgeInsets.all(12),
            child: CustomScrollView(
              key: const ValueKey('wave17-filled-scroll-viewport'),
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hope-navigation-dock')), findsOneWidget);
    expect(find.text('کیف پول'), findsOneWidget);
    expect(find.text('پروفایل'), findsNothing);
    expect(find.bySemanticsLabel('پروفایل'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('wave17-filled-scroll-viewport'))).height,
      greaterThan(550),
      reason: 'The page frame must fill available scroll height instead of shrink-wrapping its slivers.',
    );
    expect(tester.takeException(), isNull);

    // Wave 18: compact-height pages must not reserve a desktop-sized dead band
    // below the scroll viewport. The one consolidated test covers the 360×640dp
    // target used by the calibrated Android responsive capture.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
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
          body: PremiumPageFrame(
            child: ListView(
              key: const ValueKey('wave18-compact-scroll-viewport'),
              children: const [SizedBox(height: 900)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final framePadding = tester.widget<Padding>(
      find.byKey(const ValueKey('premium-page-frame-content-padding')),
    );
    expect(framePadding.padding.bottom, 40);
    expect(
      tester.getSize(find.byKey(const ValueKey('wave18-compact-scroll-viewport'))).height,
      greaterThan(480),
    );
    expect(tester.takeException(), isNull);
  });
}
