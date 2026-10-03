import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  testWidgets(
    'premium page frame fills the available viewport under loose parent constraints',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: SizedBox(
            width: 360,
            height: 640,
            child: Center(
              child: PremiumPageFrame(
                child: const SizedBox(
                  width: 120,
                  height: 160,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(PremiumPageFrame)),
        const Size(360, 640),
      );
    },
  );
}
