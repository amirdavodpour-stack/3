import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/hope_signature_components.dart';

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
}
