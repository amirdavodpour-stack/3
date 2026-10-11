import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/testing/runtime_render_settle.dart';

void main() {
  testWidgets(
    'only indeterminate progress indicators block runtime screenshot settling',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              CircularProgressIndicator(value: 0.94),
              CircularProgressIndicator(
                key: ValueKey('indeterminate'),
              ),
            ],
          ),
        ),
      );

      final determinate =
          tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator).first,
      );
      final indeterminate =
          tester.widget<CircularProgressIndicator>(
        find.byKey(const ValueKey('indeterminate')),
      );

      expect(isBlockingRuntimeProgressIndicator(determinate), isFalse);
      expect(isBlockingRuntimeProgressIndicator(indeterminate), isTrue);
    },
  );
}
