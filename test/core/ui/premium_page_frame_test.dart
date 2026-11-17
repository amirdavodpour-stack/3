import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  testWidgets(
    'premium app canvas fills the available viewport and paints an opaque base',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: PremiumAppCanvas(
            child: const Center(
              child: SizedBox(
                width: 120,
                height: 160,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(find.byType(PremiumAppCanvas)),
        const Size(360, 640),
      );

      final canvas = find.descendant(
        of: find.byType(PremiumAppCanvas),
        matching: find.byWidgetPredicate(
          (widget) => widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color != null,
        ),
      );
      expect(canvas, findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(canvas).decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.color!.a, 1);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
  testWidgets(
    'premium page frame keeps an opaque canvas under a refresh indicator',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SizedBox(
            width: 360,
            height: 640,
            child: RefreshIndicator(
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
      );
      await tester.pump();

      final canvas = find.descendant(
        of: find.byType(PremiumPageFrame),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material &&
              widget.type == MaterialType.canvas,
        ),
      );
      expect(canvas, findsOneWidget);

      final material = tester.widget<Material>(canvas);
      expect(material.color, isNotNull);
      expect(material.color!.a, 1);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'premium page frame preserves its opaque canvas when rendered directly',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: PremiumPageFrame(
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();

      final canvas = find.descendant(
        of: find.byType(PremiumPageFrame),
        matching: find.byWidgetPredicate(
          (widget) => widget is Material &&
              widget.type == MaterialType.canvas,
        ),
      );
      expect(canvas, findsOneWidget);
      final material = tester.widget<Material>(canvas);
      expect(material.color, isNotNull);
      expect(material.color!.a, 1);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

}
