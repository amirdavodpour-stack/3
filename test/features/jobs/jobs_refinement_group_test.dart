import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
  testWidgets('refinement launcher keeps secondary filters out of the first viewport',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: HopeOpportunityRefinementLauncher(
            activeCount: 2,
            kind: 'MISSION',
            visibility: 'PUBLIC',
            cityLabel: 'Tehran',
            categoryLabel: 'Design',
            categoryError: null,
            onKindChanged: (_) {},
            onVisibilityChanged: (_) {},
            onPickCity: () {},
            onPickCategory: () {},
            onRetryCategories: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Missions'), findsNothing);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Refine results'), findsOneWidget);
    expect(find.text('Missions'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Tehran'), findsOneWidget);
    expect(find.text('Design'), findsOneWidget);
  });

}
