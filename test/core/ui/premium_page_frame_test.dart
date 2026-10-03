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
            child: RepaintBoundary(
              key: boundaryKey,
              child: PremiumAppCanvas(
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
  testWidgets(
    'premium page frame stays opaque when wrapped by a refresh indicator',
    (tester) async {
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SizedBox(
            width: 360,
            height: 640,
            child: RepaintBoundary(
              key: boundaryKey,
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
        ),
      );
      await tester.pump();

      final boundary =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      final width = image.width;
      final height = image.height;
      for (final offset in <int>[
        0,
        (width - 1) * 4,
        (height - 1) * width * 4,
        ((height - 1) * width + (width - 1)) * 4,
      ]) {
        expect(bytes.getUint8(offset + 3), 255);
      }
    },
  );

  testWidgets(
    'premium page frame paints an opaque viewport when captured directly',
    (tester) async {
      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SizedBox(
            width: 360,
            height: 640,
            child: RepaintBoundary(
              key: boundaryKey,
              child: PremiumPageFrame(
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final boundary =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      expect(bytes.getUint8(3), 255);
    },
  );

}
