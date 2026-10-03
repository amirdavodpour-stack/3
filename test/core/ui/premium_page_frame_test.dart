import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  testWidgets(
    'premium app canvas fills the available viewport and paints an opaque base',
    (tester) async {
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SizedBox(
            width: 360,
            height: 640,
            child: PremiumAppCanvas(
              child: RepaintBoundary(
                key: boundaryKey,
                child: const Center(
                  child: SizedBox(
                    width: 120,
                    height: 160,
                  ),
                ),
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

      final boundary =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      expect(bytes.getUint8(3), 255);
    },
  );
}
