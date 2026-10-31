import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/ui/hope_feedback.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';

void main() {
  testWidgets('HopeFeedback uses the canonical floating acknowledgement surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => HopeFeedback.show(
                context,
                'پیام تست',
                tone: HopeFeedbackTone.error,
              ),
              child: const Text('نمایش'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('نمایش'));
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(find.text('پیام تست'), findsOneWidget);
    expect(find.byIcon(HopeV2Icons.error), findsOneWidget);
  });

  testWidgets(
    'HopeFeedback reserves requested clearance above a screen-local action dock',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => HopeFeedback.show(
                  context,
                  'Recoverable validation error',
                  tone: HopeFeedbackTone.warning,
                  bottomClearance: 112,
                ),
                child: const Text('Show dock-safe feedback'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show dock-safe feedback'));
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 128));
      expect(find.text('Recoverable validation error'), findsOneWidget);
    },
  );

}
