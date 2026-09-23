import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/features/about/about_page.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

Widget _app(Locale locale) => MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AboutHopePage(),
    );

void main() {
  testWidgets('About page renders the mission and job distinction in Persian',
      (tester) async {
    await tester.pumpWidget(_app(const Locale('fa')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumHero), findsOneWidget);
    final listView = find.byType(ListView);
    final missionText = find.text('ماموریت');
    final jobText = find.text('شغل');
    var attempts = 0;
    while (attempts < 8 &&
        (missionText.evaluate().isEmpty || jobText.evaluate().isEmpty)) {
      await tester.drag(listView, const Offset(0, -240));
      await tester.pump();
      attempts++;
    }
    expect(missionText, findsWidgets);
    expect(jobText, findsWidgets);
  });

  testWidgets('About page switches its main explanatory content to English',
      (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumHero), findsOneWidget);
    expect(find.textContaining('work marketplace'), findsOneWidget);
  });
}
