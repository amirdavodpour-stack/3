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

}
