import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/ui/premium_lifecycle.dart';

void main() {
  testWidgets('compact lifecycle fits narrow work-center cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(width: 240, child: PremiumLifecycle(compact: true, steps: [PremiumLifecycleStep(label: 'Published', icon: Icons.campaign_rounded, active: true), PremiumLifecycleStep(label: 'Completed', icon: Icons.check_rounded, active: false)],)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });
}
