import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
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

  testWidgets(
    'dark editorial hero fallback uses the canonical navy gradient',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: PremiumHero(
              eyebrow: 'Opportunity',
              title: 'A focused editorial title',
              message: 'A concise supporting description.',
              compactHero: true,
              height: 176,
            ),
          ),
        ),
      );

      final fallback = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('premium-hero-compact-fallback')),
      );
      final decoration = fallback.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors, HopeV2Gradients.heroDark.colors);
      expect(gradient.stops, HopeV2Gradients.heroDark.stops);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'full dark editorial hero fallback uses the canonical navy gradient',
    (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: PremiumHero(
              eyebrow: 'Opportunity',
              title: 'A focused editorial title',
              message: 'A concise supporting description.',
              compactHero: false,
              height: 200,
            ),
          ),
        ),
      );

      final decorations = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(PremiumHero),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradients = decorations
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>()
          .toList();
      final canonical = HopeV2Gradients.heroDark.colors;
      expect(
        gradients.any(
          (gradient) =>
              gradient.colors.length == canonical.length &&
              List<int>.generate(canonical.length, (index) => index).every(
                (index) => gradient.colors[index] == canonical[index],
              ),
        ),
        isTrue,
        reason: 'The full-size fallback must use slate/navy as its base and reserve domain colors for small accents.',
      );
      expect(tester.takeException(), isNull);
    },
  );

}
