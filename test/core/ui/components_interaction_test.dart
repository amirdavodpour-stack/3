import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/components.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

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

    expect(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(TextField))).clearButtonTooltip), findsNothing);

    await tester.enterText(find.byType(TextField), 'کار');
    await tester.pump();

    expect(values.last, 'کار');
    expect(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(TextField))).clearButtonTooltip), findsOneWidget);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(tester.element(find.byType(TextField))).clearButtonTooltip));
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

  testWidgets('SearchField preserves text-field semantics and current value',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SearchField(
            hint: 'Search',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'work');
    await tester.pump();

    final semantics = tester.getSemantics(find.byType(EditableText));
    expect(semantics.flagsCollection.isTextField, isTrue);
    expect(semantics.value, 'work');
  });

  testWidgets('compact PremiumHeader keeps trailing action in the same visual row',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PremiumHeader(
              eyebrow: 'FINANCE',
              title: 'Wallet',
              subtitle: 'Balance and activity',
              trailing: PremiumIconButton(
                key: const ValueKey('header-action'),
                icon: HopeV2Icons.insights,
                tooltip: 'Financial insights',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.byType(PremiumHeader);
    expect(header, findsOneWidget);
    expect(tester.getSize(header).height, lessThan(160));
    expect(
      tester.getSize(find.byKey(const ValueKey('header-action'))),
      const Size(48, 48),
    );
  });

  testWidgets('PressableScale preserves child semantics when no override label is provided',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PressableScale(
            onTap: () {},
            child: const Text('Visible action'),
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PressableScale));
    expect(semantics.label, 'Visible action');
  });

  testWidgets('AppTheme uses canonical geometry tokens',
      (tester) async {
    final theme = AppTheme.light();

    final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(HopeV2Radii.lg));

    final inputShape =
        theme.inputDecorationTheme.border as OutlineInputBorder;
    expect(inputShape.borderRadius, BorderRadius.circular(HopeV2Radii.input));

    final buttonShape =
        theme.filledButtonTheme.style?.shape?.resolve(<WidgetState>{})
            as RoundedRectangleBorder;
    expect(buttonShape.borderRadius, BorderRadius.circular(HopeV2Radii.button));
    expect(theme.inputDecorationTheme.fillColor, HopeV2Colors.panelSoftLight);
    expect(theme.chipTheme.backgroundColor, HopeV2Colors.chipLight);
    expect(
      theme.navigationBarTheme.backgroundColor,
      HopeV2Colors.navigationLight,
    );
  });

  testWidgets('shared navigation geometry uses canonical tokens',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: PremiumNavigationRail(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
              PremiumNavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    label: 'Profile',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.minWidth, HopeV2Navigation.railMinWidth);
    expect(rail.minExtendedWidth, HopeV2Navigation.railExtendedWidth);

    final bar = tester.widget<Container>(
      find.byKey(const ValueKey('hope-navigation-dock')),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('hope-navigation-dock'))).height,
      HopeV2Navigation.barHeight,
    );
    expect(bar.decoration, isA<BoxDecoration>());
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

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.binding.focusManager.primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 2);
  });
}
