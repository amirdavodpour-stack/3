import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/ui/hope_l10n.dart';
import 'package:hope_mobile/features/jobs/jobs_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('refinement controls wrap without horizontal clipping on narrow RTL screens',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: HopeL10n.localizationsDelegates,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HopeOpportunityRefinementGroup(
                kind: 'ALL',
                visibility: 'PUBLIC',
                onKindChanged: (_) {},
                onVisibilityChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const ['همه', 'ماموریت‌ها', 'شغل‌ها', 'عمومی', 'تخصصی']) {
      expect(find.text(label), findsOneWidget);
    }

    for (final chip in tester.widgetList<Widget>(
      find.byType(PremiumFilterChip),
    )) {
      final rect = tester.getRect(find.byWidget(chip));
      expect(rect.left, greaterThanOrEqualTo(-0.1));
      expect(rect.right, lessThanOrEqualTo(360.1));
    }
    expect(tester.takeException(), isNull);
  });
}
