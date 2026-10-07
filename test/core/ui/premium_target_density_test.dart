import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/premium_lifecycle.dart';
import 'package:hope_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('dense mobile headers use a low-noise editorial eyebrow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
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
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PremiumHeader(
              dense: true,
              eyebrow: 'کاوش',
              title: 'فرصت بعدی خود را پیدا کنید',
              subtitle: 'کار و مأموریت‌های متناسب با مسیر کاری شما.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final eyebrow = find.text('کاوش');
    expect(eyebrow, findsOneWidget);
    final style = tester.widget<Text>(eyebrow).style;
    expect(style?.fontWeight, isNotNull);
    expect(style?.fontSize, lessThanOrEqualTo(11));
  });

  testWidgets('compact lifecycle remains vertically compact for six payment stages', (tester) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const steps = [
      PremiumLifecycleStep(label: 'تأمین وجه', icon: Icons.account_balance_wallet, active: true),
      PremiumLifecycleStep(label: 'در امانت', icon: Icons.lock_outline, active: false),
      PremiumLifecycleStep(label: 'در حال انجام', icon: Icons.work_outline, active: false),
      PremiumLifecycleStep(label: 'تحویل', icon: Icons.upload_outlined, active: false),
      PremiumLifecycleStep(label: 'تأیید', icon: Icons.verified_outlined, active: false),
      PremiumLifecycleStep(label: 'تسویه', icon: Icons.payments_outlined, active: false),
    ];

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
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PremiumLifecycle(
              compact: true,
              title: 'مسیر مالی و انجام کار',
              subtitle: 'وضعیت چرخه',
              steps: steps,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(PremiumLifecycle)).height,
      lessThan(285),
    );
  });


  testWidgets('dense header title uses the premium compact type scale',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
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
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: PremiumHeader(
            dense: true,
            eyebrow: 'کاوش',
            title: 'فرصت بعدی خود را پیدا کنید',
            subtitle: 'کار و مأموریت‌های متناسب با مسیر کاری شما.',
          ),
        ),
      ),
    );
    await tester.pump();

    final title = find.text('فرصت بعدی خود را پیدا کنید');
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).style?.fontSize, 19);
  });

  testWidgets('compact PremiumPanel default padding stays at the density baseline',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: PremiumPanel(
            child: SizedBox(width: 48, height: 48),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(PremiumPanel)),
      const Size(78, 78),
    );
  });

}
