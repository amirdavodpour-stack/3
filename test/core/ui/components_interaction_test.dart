import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/components.dart';

void main() {
  testWidgets('SearchField exposes a clear action after text is entered',
      (tester) async {
    final values = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SearchField(
            hint: 'جست‌وجو',
            onChanged: values.add,
          ),
        ),
      ),
    );

    expect(find.byTooltip('پاک کردن جست‌وجو'), findsNothing);

    await tester.enterText(find.byType(TextField), 'کار');
    await tester.pump();

    expect(values.last, 'کار');
    expect(find.byTooltip('پاک کردن جست‌وجو'), findsOneWidget);

    await tester.tap(find.byTooltip('پاک کردن جست‌وجو'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
        '');
    expect(values.last, '');
  });

  testWidgets('semantic warning color uses the canonical warning token',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Text(
            'Warning',
            style: TextStyle(color: HopeV2SemanticColors.warning(context)),
          ),
        ),
      ),
    );

    final style = tester.widget<Text>(find.text('Warning')).style!;
    expect(style.color, HopeV2Colors.warning);
  });

  testWidgets('PressableScale is keyboard-focusable and exposes button semantics',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PressableScale(
            semanticLabel: 'Open opportunity',
            onTap: () => taps++,
            child: const Text('Open'),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PressableScale));
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.label, 'Open opportunity');

    await tester.tap(find.text('Open'));
    expect(taps, 1);
  });
}
