import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/marketplace/employer_candidate_matching_repository.dart';
import 'package:hope_mobile/features/marketplace/employer_candidate_matches_page.dart';
import 'package:hope_mobile/core/ui/premium_lifecycle.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('dense mobile headers use a low-noise editorial eyebrow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            padding: EdgeInsets.all(16),
            child: PremiumHeader(
              dense: true,
              eyebrow: 'کاوش',
              title: 'فرصت بعدی خود را پیدا کنید',
              subtitle: 'کار و مأموریت‌های متناسب با مسیر کاری شما.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final eyebrow = find.text('کاوش');
    expect(eyebrow, findsOneWidget);
    final style = tester.widget<Text>(eyebrow).style;
    expect(style?.fontWeight, isNotNull);
    expect(style?.fontSize, lessThanOrEqualTo(11));
  });

  testWidgets('compact lifecycle remains vertically compact for six payment stages', (tester) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const steps = [
      PremiumLifecycleStep(label: 'تأمین وجه', icon: Icons.account_balance_wallet, active: true),
      PremiumLifecycleStep(label: 'در امانت', icon: Icons.lock_outline, active: false),
      PremiumLifecycleStep(label: 'در حال انجام', icon: Icons.work_outline, active: false),
      PremiumLifecycleStep(label: 'تحویل', icon: Icons.upload_outlined, active: false),
      PremiumLifecycleStep(label: 'تأیید', icon: Icons.verified_outlined, active: false),
      PremiumLifecycleStep(label: 'تسویه', icon: Icons.payments_outlined, active: false),
    ];

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
            padding: EdgeInsets.all(16),
            child: PremiumLifecycle(
              compact: true,
              title: 'مسیر مالی و انجام کار',
              subtitle: 'وضعیت چرخه',
              steps: steps,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(PremiumLifecycle)).height,
      lessThan(285),
    );
  });


  testWidgets('dense header title uses the premium compact type scale',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          body: PremiumHeader(
            dense: true,
            eyebrow: 'کاوش',
            title: 'فرصت بعدی خود را پیدا کنید',
            subtitle: 'کار و مأموریت‌های متناسب با مسیر کاری شما.',
          ),
        ),
      ),
    );
    await tester.pump();

    final title = find.text('فرصت بعدی خود را پیدا کنید');
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).style?.fontSize, 21.5);
  });

  testWidgets('compact PremiumPanel default padding stays at the density baseline',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: PremiumPanel(
            child: SizedBox(width: 48, height: 48),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(PremiumPanel)),
      const Size(78, 78),
    );
  });

  testWidgets('wave 7 keeps support surfaces quiet and primary commands focal',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: Column(
            children: [
              PremiumStatCard(
                label: 'فعال',
                value: '12',
                icon: Icons.work_outline,
              ),
              PremiumQuickActionStrip(
                title: 'دسترسی سریع',
                actions: [
                  PremiumQuickAction(
                    label: 'ادامه',
                    icon: Icons.arrow_forward,
                    primary: true,
                  ),
                  PremiumQuickAction(
                    label: 'تاریخچه',
                    icon: Icons.history,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final statPanel = tester.widget<PremiumPanel>(
      find.descendant(
        of: find.byType(PremiumStatCard),
        matching: find.byType(PremiumPanel),
      ),
    );
    expect(statPanel.quiet, isTrue);
    expect(statPanel.highlight, isFalse);

    final panelClip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
    final panelSurface = panelClip.child as Container;
    final panelDecoration = panelSurface.decoration! as BoxDecoration;
    expect(panelDecoration.color, HopeV2Colors.panelSoftDark);

    final actionInks = tester.widgetList<Ink>(find.byType(Ink)).toList();
    expect(actionInks.length, greaterThanOrEqualTo(2));
    final primaryDecoration = actionInks
        .map((ink) => ink.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.color != null);
    expect(primaryDecoration.color, isNot(Colors.transparent));
  });

  testWidgets('wave 8 keeps mobile navigation visually compact',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: PremiumNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'خانه',
              ),
              NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.search),
                label: 'کاوش',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final dock = tester.widget<Container>(
      find.byKey(const ValueKey('hope-navigation-dock')),
    );
    final decoration = dock.decoration! as BoxDecoration;
    expect(
      tester.getSize(find.byKey(const ValueKey('hope-navigation-dock'))).height,
      HopeV2Navigation.barHeight,
    );
    expect(decoration.borderRadius, BorderRadius.circular(HopeV2Navigation.dockRadius));
  });



  testWidgets('wave 12 decision, trust and creation primitives preserve first-fold hierarchy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            child: Column(
              children: [
                const HopeCreationProgress(activeIndex: 0),
                HopeOpportunityDecisionStrip(
                  matchScore: 94,
                  budget: '۱,۵۰۰,۰۰۰ تا ۲,۵۰۰,۰۰۰ تومان',
                  category: 'نرم‌افزار',
                  location: 'تهران',
                  kind: 'ماموریت',
                ),
                const SizedBox(height: 8),
                HopeTrustSignalRail(
                  signals: [
                    (
                      icon: Icons.verified_outlined,
                      label: 'اعتماد',
                      value: 'تأییدشده',
                      color: HopeV2Colors.primary,
                    ),
                    (
                      icon: Icons.task_alt_outlined,
                      label: 'تکمیل‌شده',
                      value: '27',
                      color: HopeV2Colors.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('create-opportunity-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-decision-strip')), findsOneWidget);
    expect(find.byType(HopeTrustSignalRail), findsOneWidget);
    expect(find.text('۱,۵۰۰,۰۰۰ تا ۲,۵۰۰,۰۰۰ تومان'), findsOneWidget);
  });

  testWidgets('wave 12 featured opportunity cards become compact decision scans on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final job = HopeJob.fromMap({
      'id': 'wave12-job',
      'title': 'طراحی رابط موبایل حرفه‌ای',
      'category': 'Software',
      'city': 'تهران',
      'kind': 'MISSION',
      'budgetMin': '1500000',
      'budgetMax': '2500000',
      'recommendationScore': 94,
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
            padding: const EdgeInsets.all(12),
            child: OpportunityCard(
              job: job,
              variant: OpportunityCardVariant.featured,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('opportunity-card-cta')), findsOneWidget);
    expect(tester.getSize(find.byType(OpportunityCard)).height, lessThan(260));
  });


  testWidgets('wave 13 compact lifecycle rail compresses the mobile decision spine',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
            padding: EdgeInsets.all(12),
            child: HopeLifecycleRail(
              labels: ['تأمین وجه', 'در امانت', 'در حال انجام', 'تحویل', 'تأیید', 'تسویه'],
              icons: [
                Icons.account_balance_wallet_outlined,
                Icons.lock_outline,
                Icons.work_outline,
                Icons.upload_outlined,
                Icons.verified_outlined,
                Icons.payments_outlined,
              ],
              current: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HopeLifecycleRail), findsOneWidget);
    expect(tester.getSize(find.byType(HopeLifecycleRail)).height, lessThan(125));
    expect(find.text('تأمین وجه'), findsOneWidget);
    expect(find.text('تسویه'), findsOneWidget);
  });


  testWidgets('wave 14 decision surface keeps real match signals inside one panel',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(
          body: HopeOpportunityDecisionStrip(
            matchScore: 94,
            budget: '۱,۵۰۰,۰۰۰ تومان',
            category: 'نرم‌افزار',
            location: 'تهران',
            kind: 'ماموریت',
            breakdown: const {
              'skills': .94,
              'category': .90,
              'location': .88,
              'salary': .92,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('opportunity-decision-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-decision-breakdown-skills')), findsOneWidget);
    expect(find.byKey(const ValueKey('opportunity-decision-breakdown-salary')), findsOneWidget);
    expect(find.byType(PremiumPanel), findsOneWidget);
  });


  testWidgets('wave 14 candidate comparison renders unique component signals',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const candidate = HopeEmployerCandidateMatch(
      rank: 1,
      userId: 'candidate-1',
      displayName: 'کاربر نمونه',
      score: 94,
      components: {
        'skills': .94,
        'experience': .91,
        'location': .88,
        'salary': .92,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(brightness: Brightness.dark),
        home: EmployerCandidateMatchesPage(
          data: const HopeEmployerCandidateMatchList(
            jobId: 'wave14-job',
            kind: 'JOB',
            candidates: [candidate],
          ),
          onRetry: () {},
        ),
      ),
    );
    await tester.pump();

    for (final key in const ['skills', 'experience', 'location', 'salary']) {
      expect(
        find.byKey(ValueKey('candidate-signal-$key')),
        findsOneWidget,
      );
    }
    expect(find.text('94%'), findsOneWidget);
  });

}