import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/ui/hope_l10n.dart';
import 'package:hope_mobile/core/ui/copy.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('both locales load and expose non-empty product copy',
      (tester) async {
    for (final locale in const [Locale('en'), Locale('fa')]) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            final copy = HopeCopy.of(context);
            return Column(children: [
              Text(copy.copy_about_hope_f8ee86b),
              Text(copy.copy_opportunity_published_81a9fd1),
              Text(copy.copy_operation_failed_eb38c4c),
              Text(copy.copy_connection_failed_1b34bc9),
            ]);
          },
        ),
      ));
      await tester.pumpAndSettle();
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data, isNotNull);
        expect(text.data!.trim().isNotEmpty, isTrue,
            reason: 'empty copy for ${locale.languageCode}');
      }
      expect(find.byType(Text), findsNWidgets(4));
    }
  });

  testWidgets('moneyLabel groups internal Toman amounts consistently across locales',
      (tester) async {
    for (final locale in const [Locale('en'), Locale('fa')]) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(moneyLabel(context, '2000000.0')),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.text(
          locale.languageCode == 'en' ? '2,000,000 TOMAN' : '2,000,000 تومان',
        ),
        findsOneWidget,
      );
    }
  });

  test('generated localization delegates load without exceptions', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final fa = await AppLocalizations.delegate.load(const Locale('fa'));
    expect(en.copy_about_hope_f8ee86b.trim(), isNotEmpty);
    expect(fa.copy_about_hope_f8ee86b.trim(), isNotEmpty);
  });
}
