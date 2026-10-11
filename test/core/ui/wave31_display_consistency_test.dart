import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/marketplace/job.dart';
import 'package:hope_mobile/core/ui/opportunity_card.dart';
import 'package:hope_mobile/core/ui/hope_signature_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'compact-grid opportunity displays equal min/max budget as one Persian amount',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'equal-budget-opportunity',
        'title': 'فرصت با بودجه ثابت',
        'description': 'Budget display consistency regression.',
        'kind': 'MISSION',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'budgetMin': '2500000',
        'budgetMax': '2500000',
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
                variant: OpportunityCardVariant.compactGrid,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final budget = tester.widget<Text>(
        find.byKey(
          const ValueKey('opportunity-card-compact-grid-budget'),
        ),
      );
      expect(budget.data, '۲٬۵۰۰٬۰۰۰ تومان');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Opportunity DNA localizes match percentage and collapses equal Toman budget',
    (tester) async {
      final job = HopeJob.fromMap({
        'id': 'wave32-dna-formatting',
        'title': 'فرصت با بودجه ثابت',
        'description': 'Display formatter regression.',
        'kind': 'MISSION',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'budgetMin': '2500000',
        'budgetMax': '2500000',
        'recommendationScore': 92,
        'city': 'تهران',
        'category': 'software',
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
            body: ListView(
              children: [HopeOpportunityDnaSignature(job: job)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final signature = find.byKey(
        const ValueKey('opportunity-dna-signature'),
      );
      expect(
        find.descendant(of: signature, matching: find.text('۹۲٪')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: signature,
          matching: find.text('۲٬۵۰۰٬۰۰۰ تومان'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: signature,
          matching: find.text('2500000 – 2500000'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'image-less opportunity variants stay readable at 390dp in English LTR at 1.5x',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final job = HopeJob.fromMap({
        'id': 'wave1-en-ltr-no-media',
        'title': 'Flutter developer opportunity',
        'description': 'No-media English LTR and large-text regression.',
        'kind': 'JOB',
        'visibility': 'PUBLIC',
        'status': 'OPEN',
        'categoryId': 'software',
        'category': 'Software',
        'city': 'Berlin',
        'monthlySalary': '2500000',
        'recommendationScore': 0.94,
      });

      const variants = <OpportunityCardVariant>[
        OpportunityCardVariant.compact,
        OpportunityCardVariant.compactGrid,
        OpportunityCardVariant.standard,
        OpportunityCardVariant.featured,
        OpportunityCardVariant.featuredScan,
      ];

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
            theme: ThemeData(brightness: Brightness.dark),
            home: MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: 300,
                      child: OpportunityCard(job: job, variant: variant),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fallback = find.byKey(
          const ValueKey('opportunity-fallback-icon-container'),
        );
        expect(fallback, findsOneWidget, reason: 'variant: $variant');
        final fallbackSize = tester.getSize(fallback);
        expect(fallbackSize.width, lessThanOrEqualTo(32));
        expect(fallbackSize.height, lessThanOrEqualTo(32));
        expect(find.text('Flutter developer opportunity'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(r'Flutter developer opportunity.*Berlin', dotAll: true),
          ),
          findsOneWidget,
          reason: 'semantic title and true location must survive for $variant',
        );
        expect(tester.takeException(), isNull, reason: 'variant: $variant');
      }
    },
  );

}
