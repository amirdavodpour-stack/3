import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/hope_async_state.dart';

void main() {
  testWidgets('pending async state uses the canonical warning semantic token',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.pending,
            title: 'در انتظار',
            message: 'در حال پردازش',
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.schedule_rounded));
    expect(icon.color, HopeV2Colors.warning);
  });

  testWidgets('async state exposes a single live semantic announcement',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.error,
            title: 'خطا',
            message: 'دوباره تلاش کنید',
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(HopeAsyncState));
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
    expect(semantics.label, 'خطا. دوباره تلاش کنید');
  });

  testWidgets('async state action is constrained to the shared touch minimum',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HopeAsyncState(
            kind: HopeStateKind.error,
            title: 'خطا',
            message: 'دوباره تلاش کنید',
            action: FilledButton(
              onPressed: () {},
              child: const Text('تلاش دوباره'),
            ),
          ),
        ),
      ),
    );

    final button = find.byType(FilledButton);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(HopeV2Touch.minimum));
  });
}
