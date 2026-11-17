import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/ui/hope_feedback.dart';

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
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });
}
