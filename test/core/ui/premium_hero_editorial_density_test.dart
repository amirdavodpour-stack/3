import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('editorial hero caps content-only desktop height', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PremiumHero(
            eyebrow: 'Opportunity',
            title: 'A focused editorial title',
            message: 'A concise supporting description for the current opportunity.',
            height: 480,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PremiumHero)).height, 192);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editorial hero preserves extra room when an action is present', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumHero(
            eyebrow: 'Opportunity',
            title: 'A focused editorial title',
            message: 'A concise supporting description for the current opportunity.',
            height: 480,
            action: FilledButton(onPressed: () {}, child: const Text('Continue')),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PremiumHero)).height, 216);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact editorial hero stays within the compact height budget', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PremiumHero(
            eyebrow: 'Opportunity',
            title: 'A focused editorial title',
            message: 'A concise supporting description for the current opportunity.',
            height: 480,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PremiumHero)).height, 176);
    expect(tester.takeException(), isNull);
  });
}
