import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/transactions/wallet.dart';

import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/hope_signature_components.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  testWidgets(
    'live preview eyebrow uses a neutral readable foreground, not brand indigo',
    (tester) async {
      final title = TextEditingController(text: 'Opportunity title');
      final description = TextEditingController(text: 'Opportunity description');
      final minBudget = TextEditingController(text: '100000');
      final maxBudget = TextEditingController(text: '200000');
      final salary = TextEditingController(text: '500000');

      addTearDown(title.dispose);
      addTearDown(description.dispose);
      addTearDown(minBudget.dispose);
      addTearDown(maxBudget.dispose);
      addTearDown(salary.dispose);

      const brandIndigo = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: brandIndigo),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HopeOpportunityLivePreview(
                kind: 'MISSION',
                visibility: 'PUBLIC',
                schedule: 'FLEXIBLE',
                city: 'Remote',
                titleController: title,
                descriptionController: description,
                minBudgetController: minBudget,
                maxBudgetController: maxBudget,
                salaryController: salary,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final eyebrow = find.text('LIVE PREVIEW');
      expect(eyebrow, findsOneWidget);
      final text = tester.widget<Text>(eyebrow);
      final context = tester.element(eyebrow);

      expect(
        text.style?.color,
        HopeV2SemanticColors.textPrimary(context),
        reason: 'Readable preview labels must use a semantic neutral foreground.',
      );
      expect(
        text.style?.color,
        isNot(Theme.of(context).colorScheme.primary),
        reason: 'The indigo brand-action color is not a readable text color.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected navigation label uses the dedicated neutral navigation foreground',
    (tester) async {
      const brandIndigo = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: brandIndigo),
          ),
          home: Scaffold(
            bottomNavigationBar: PremiumNavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text('Home');
      expect(label, findsOneWidget);
      final text = tester.widget<Text>(label);
      final context = tester.element(label);
      expect(
        text.style?.color,
        HopeV2SemanticColors.navigationLabel(
          context,
          selected: true,
        ),
        reason: 'Selected navigation text must resolve through readable semantic colors.',
      );
      expect(
        text.style?.color,
        isNot(Theme.of(context).colorScheme.primary),
        reason: 'Selected navigation text must not reuse the raw indigo action color.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generic page header eyebrow does not render in the raw brand foreground',
    (tester) async {
      const brandIndigo = Color(0xFF6750A4);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: brandIndigo),
          ),
          home: const Scaffold(
            body: PremiumHeader(
              eyebrow: 'SECTION',
              title: 'Profile',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text('SECTION');
      expect(label, findsOneWidget);
      final text = tester.widget<Text>(label);
      final context = tester.element(label);
      expect(
        text.style?.color,
        HopeV2SemanticColors.readableAccent(
          context,
          Theme.of(context).colorScheme.primary,
        ),
        reason: 'Header eyebrow text must resolve through readable semantic colors.',
      );
      expect(
        text.style?.color,
        isNot(Theme.of(context).colorScheme.primary),
        reason: 'Header eyebrow text must not reuse the raw indigo action color.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hero domain label uses a neutral high-contrast foreground on the dark hero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6750A4)),
          ),
          home: const Scaffold(
            body: PremiumHero(
              eyebrow: 'WELCOME',
              title: 'Home',
              message: 'A real welcome surface',
              domain: HopeProductDomain.overview,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text('Overview');
      expect(label, findsOneWidget);
      final text = tester.widget<Text>(label);
      expect(
        text.style?.color,
        HopeV2Colors.darkText,
        reason: 'Hero domain text sits on a dark gradient and must use a neutral, high-contrast foreground.',
      );
      expect(
        text.style?.color,
        isNot(Theme.of(tester.element(label)).colorScheme.primary),
        reason: 'Readable text on the hero may not use the purple domain accent.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wallet flow signature uses customer-facing copy without accounting implementation terms',
    (tester) async {
      const wallet = HopeWallet(
        id: 'wallet-1',
        userId: 'user-1',
        currency: 'TOMAN',
        availableBalance: 125000,
        lockedBalance: 25000,
        status: 'ACTIVE',
      );

      Widget render(Locale locale) => MaterialApp(
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('fa')],
            home: Scaffold(
              body: SingleChildScrollView(
                child: HopeWalletFlowSignature(wallet: wallet),
              ),
            ),
          );

      await tester.pumpWidget(render(const Locale('en')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          RegExp(r'ledger|internal toman|دفترکل|دفتر\s*کل|لجر', caseSensitive: false),
        ),
        findsNothing,
      );
      expect(find.text('Money flow'), findsOneWidget);
      expect(find.text('Transaction'), findsOneWidget);
      expect(find.text('Toman'), findsOneWidget);
      expect(
        find.text('Reserved funds are released after work approval.'),
        findsOneWidget,
      );

      await tester.pumpWidget(render(const Locale('fa')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          RegExp(r'ledger|internal toman|دفترکل|دفتر\s*کل|لجر', caseSensitive: false),
        ),
        findsNothing,
      );
      expect(find.text('گردش وجه'), findsOneWidget);
      expect(find.text('ثبت تراکنش'), findsOneWidget);
      expect(find.text('تومان'), findsOneWidget);
      expect(
        find.text('وجه رزروشده پس از تأیید کار آزاد می‌شود.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

}
