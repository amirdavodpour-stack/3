import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/transactions/wallet.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/hope_signature_components.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('Wave 22 grouped responsive visual and localization contracts',
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
                  icon: HopeV2Icons.login,
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

    // Match score remains a headline score; per-dimension values follow
    // the active fa-RTL locale and use Persian digits plus the Persian percent sign.
    for (final value in ['92%', '۹۶٪', '۸۸٪', '۷۲٪', '۸۴٪']) {
      expect(find.text(value), findsOneWidget,
          reason: 'Wave 15 must render the real localized numeric score $value');
    }
    expect(find.textContaining(r'${score}'), findsNothing);
    expect(find.textContaining(r'${(value'), findsNothing);
    expect(find.byKey(const ValueKey('opportunity-dna-signature')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-card-cta')), findsOneWidget);
    expect(tester.widget<PremiumHero>(find.byType(PremiumHero)).compactHero,
        isTrue);
    expect(
      find.descendant(
        of: find.byType(PremiumHero),
        matching: find.byType(HopeIcon),
      ),
      findsNothing,
      reason: 'Compact editorial fallback icons must never overlap the hero title.',
    );
    expect(
      find.byKey(const ValueKey('premium-hero-compact-fallback')),
      findsOneWidget,
      reason: 'Compact Auth heroes must use the quiet fallback without ornamental strokes.',
    );
    expect(
      find.byKey(const ValueKey('opportunity-match-score-ring')),
      findsOneWidget,
      reason: 'Compact opportunity screens use the score ring from the target design.',
    );
    final breakdownSkills =
        find.byKey(const ValueKey('opportunity-decision-breakdown-skills'));
    final breakdownCategory =
        find.byKey(const ValueKey('opportunity-decision-breakdown-category'));
    final breakdownLocation =
        find.byKey(const ValueKey('opportunity-decision-breakdown-location'));
    final breakdownSalary =
        find.byKey(const ValueKey('opportunity-decision-breakdown-salary'));
    expect(breakdownSkills, findsOneWidget);
    expect(breakdownCategory, findsOneWidget);
    expect(breakdownLocation, findsOneWidget);
    expect(breakdownSalary, findsOneWidget);
    expect(tester.getSize(breakdownSkills).width, lessThan(200));
    expect(
      (tester.getTopLeft(breakdownCategory).dy -
              tester.getTopLeft(breakdownSkills).dy)
          .abs(),
      lessThan(8),
      reason: 'Compact score bars should form two columns, not four full-width rows.',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('opportunity-dna-signature'))).height,
      lessThan(180),
      reason: 'Compact opportunity trait cards must preserve first-fold space.',
    );

    final budgetAmount = find.byKey(
      const ValueKey('opportunity-card-budget-amount'),
    );
    expect(budgetAmount, findsOneWidget);
    final budgetText = tester.widget<Text>(budgetAmount);
    expect(budgetText.maxLines, 3);
    expect(budgetText.softWrap, isTrue);
    expect(budgetText.data, contains('۲٬۵۰۰٬۰۰۰ تومان'));
    expect(
      tester.renderObject<RenderParagraph>(budgetAmount).didExceedMaxLines,
      isFalse,
      reason: 'The featured card must expose the complete financial range, not an ellipsis.',
    );
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
    expect(
      find.text('پروفایل'),
      findsOneWidget,
      reason: 'Wave26 keeps all five Persian navigation labels visible at narrow widths.',
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'پروفایل',
      ),
      findsOneWidget,
      reason: 'The dock item exposes its localized accessible name through Semantics.',
    );
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
    expect(framePadding.padding.resolve(TextDirection.rtl).bottom, 16);
    expect(
      tester.getSize(find.byKey(const ValueKey('wave18-compact-scroll-viewport'))).height,
      greaterThan(480),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Superwave compact Money Flow keeps a heading and every lifecycle step',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const wallet = HopeWallet(
        id: 'superwave-wallet',
        userId: 'u1',
        currency: 'TOMAN',
        availableBalance: 2500000,
        lockedBalance: 1000000,
        escrowBalance: 0,
        status: 'ACTIVE',
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
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(8),
              child: HopeWalletFlowSignature(wallet: wallet),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('گردش وجه'), findsOneWidget);
      expect(find.text('دفترکل'), findsOneWidget);
      expect(find.text('رزرو'), findsOneWidget);
      expect(find.text('آزادسازی'), findsOneWidget);
      expect(
        find.textContaining('۱٬۰۰۰٬۰۰۰ تومان'),
        findsNothing,
        reason: 'The lifecycle must not duplicate or invent numeric wallet amounts.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Wave 26 compact-grid cards expose the complete Toman range without ellipsis',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'wave26-compact-grid-budget',
        'title': 'طراحی رابط کاربری',
        'description': 'Compact grid financial disclosure contract.',
        'categoryId': 'design',
        'category': 'طراحی',
        'jobType': 'FIXED',
        'budgetMin': '1000000',
        'budgetMax': '1500000',
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
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.86,
                children: [
                  OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.compactGrid,
                  ),
                  OpportunityCard(
                    job: job,
                    variant: OpportunityCardVariant.compactGrid,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final amountFinder = find.byKey(
        const ValueKey('opportunity-card-compact-grid-budget'),
      ).first;
      expect(amountFinder, findsOneWidget);
      final amount = tester.widget<Text>(amountFinder);
      expect(amount.data, contains('۱٬۰۰۰٬۰۰۰'));
      expect(amount.data, contains('۱٬۵۰۰٬۰۰۰'));
      expect(amount.data!.split('تومان').length - 1, 1);
      expect(
        amount.data,
        isNot(contains(r'\n')),
        reason: 'Compact amount ranges must render real line breaks, not the visible \\n escape sequence.',
      );
      expect(amount.maxLines, 3);
      expect(amount.overflow, TextOverflow.clip);
      expect(
        tester.renderObject<RenderParagraph>(amountFinder).didExceedMaxLines,
        isFalse,
        reason: 'The complete Toman range must remain visible in compact discovery cards.',
      );
      expect(tester.takeException(), isNull);
    },
  );

}
