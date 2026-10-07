import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  testWidgets(
    'premium app canvas fills the available viewport and exposes an opaque base',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const SizedBox(
            width: 360,
            height: 640,
            child: const RepaintBoundary(
              child: const PremiumAppCanvas(
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(PremiumAppCanvas),
            matching: find.byType(SizedBox),
          ).last,
        ),
        const Size(360, 640),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PremiumAppCanvas),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = decoratedBox.decoration;
      expect(decoration, isA<BoxDecoration>());
      final boxDecoration = decoration as BoxDecoration;
      expect(boxDecoration.color, isNotNull);
      expect((boxDecoration.color!.a * 255.0).round().clamp(0, 255), 255);
      expect(boxDecoration.gradient, isNotNull);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'premium page frame stays opaque when wrapped by a refresh indicator',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SizedBox(
            width: 360,
            height: 640,
            child: RepaintBoundary(
              child: RefreshIndicator.noSpinner(
                onRefresh: () async {},
                child: PremiumPageFrame(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final canvasMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(PremiumPageFrame),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material && widget.type == MaterialType.canvas,
          ),
        ),
      );
      expect(canvasMaterial.color, isNotNull);
      expect(canvasMaterial.color!.alpha, 255);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'premium page frame exposes an opaque viewport when captured directly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const SizedBox(
            width: 360,
            height: 640,
            child: const RepaintBoundary(
              child: const PremiumPageFrame(
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final canvasMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(PremiumPageFrame),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material && widget.type == MaterialType.canvas,
          ),
        ),
      );
      expect(canvasMaterial.color, isNotNull);
      expect(canvasMaterial.color!.alpha, 255);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
