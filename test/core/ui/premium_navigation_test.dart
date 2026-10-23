import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(HopeV2Icons.home, size: 24),
      selectedIcon: Icon(HopeV2Icons.homeSelected, size: 24),
      label: 'خانه',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.search, size: 24),
      selectedIcon: Icon(HopeV2Icons.search, size: 24),
      label: 'کاوش',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.workshop, size: 24),
      selectedIcon: Icon(HopeV2Icons.workshopSelected, size: 24),
      label: 'کارگاه',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.wallet, size: 24),
      selectedIcon: Icon(HopeV2Icons.walletSelected, size: 24),
      label: 'کیف پول',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.profile, size: 24),
      selectedIcon: Icon(HopeV2Icons.profileSelected, size: 24),
      label: 'پروفایل',
    ),
  ];

  testWidgets('premium navigation preserves the five-tab shell contract',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PremiumNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('hope-navigation-dock')), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('کاوش'), findsOneWidget);
    expect(find.text('کارگاه'), findsOneWidget);
    expect(find.text('کیف پول'), findsOneWidget);
    expect(find.text('پروفایل'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('hope-navigation-dock'))).height,
        greaterThanOrEqualTo(64));
  });

  testWidgets('premium mobile navigation uses an anchored editorial rail shape',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PremiumNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
          ),
        ),
      ),
    );

    final dock = tester.widget<Container>(
      find.byKey(const ValueKey('hope-navigation-dock')),
    );
    final decoration = dock.decoration! as BoxDecoration;
    expect(
      decoration.borderRadius,
      const BorderRadiusDirectional.only(
        topStart: Radius.circular(14),
        topEnd: Radius.circular(14),
      ),
    );
    expect(find.byKey(const ValueKey('hope-navigation-selection-plate')), findsOneWidget);
    final activeRail = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('hope-navigation-selection-accent')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final railDecoration = activeRail.decoration as BoxDecoration;
    expect(
      railDecoration.color,
      HopeV2TonalPalettes.forest.shade700.withValues(alpha: .86),
      reason: 'The green identity accent should complement, not replace, the indigo selection plate.',
    );
  });

  testWidgets('default dark premium panels use the canonical opaque surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: PremiumPanel(child: SizedBox(width: 48, height: 48)),
        ),
      ),
    );

    final panel = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(PremiumPanel),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = panel.decoration as BoxDecoration;
    expect(decoration.color, HopeV2Colors.panelDark);
  });

  testWidgets('quick action strip uses flat command controls without a wrapper panel',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: PremiumQuickActionStrip(
            title: 'Quick access',
            actions: [
              PremiumQuickAction(
                label: 'Applications',
                icon: HopeV2Icons.mission,
                primary: true,
                primaryActionColor: HopeV2Colors.markedPrimaryActionDarkGreen,
              ),
              PremiumQuickAction(
                label: 'Offers',
                icon: HopeV2Icons.featured,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PremiumQuickActionStrip), findsOneWidget);
    expect(find.byType(PremiumPanel), findsNothing);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    final actionInk = find.ancestor(
      of: find.text('Applications'),
      matching: find.byType(Ink),
    ).first;
    final decoration = tester.widget<Ink>(actionInk).decoration as BoxDecoration;
    expect(
      decoration.color,
      HopeV2Colors.markedPrimaryActionDarkGreen.withValues(alpha: .92),
    );
  });

  testWidgets('highlighted premium panels expose a restrained gradient layer',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: PremiumPanel(
            highlight: true,
            child: SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );

    final panel = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(PremiumPanel),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = panel.decoration as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
  });

  testWidgets('premium desktop navigation rail preserves the shell contract',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PremiumNavigationRail(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
            extended: true,
          ),
        ),
      ),
    );

    final rail = tester.widget<NavigationRail>(
      find.byType(NavigationRail),
    );
    expect(rail.destinations, hasLength(5));
    expect(
      rail.selectedIconTheme?.color,
      HopeV2TonalPalettes.forest.shade700,
      reason: 'Desktop navigation should expose the green identity accent without recoloring labels.',
    );
    expect(
      rail.selectedLabelTextStyle?.color,
      HopeV2SemanticColors.textPrimary(tester.element(find.byType(NavigationRail))),
    );
    expect(
      tester.getSize(find.byType(PremiumNavigationRail)).width,
      greaterThanOrEqualTo(210),
    );
  });

  testWidgets('premium desktop navigation rail uses a direction-aware divider',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PremiumNavigationRail(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: destinations,
            ),
          ),
        ),
      ),
    );

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(PremiumNavigationRail),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(decorated.decoration, isA<BoxDecoration>());
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.border, isA<BorderDirectional>());
  });

  testWidgets('premium icon button exposes a stable semantic identifier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PremiumIconButton(
            icon: HopeV2Icons.refresh,
            tooltip: 'Refresh',
            semanticsIdentifier: 'home-refresh-action',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsIdentifier('home-refresh-action'),
      findsOneWidget,
    );
  });

  testWidgets('premium icon button keeps a 48dp target with a quiet surface',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PremiumIconButton(
            icon: HopeV2Icons.refresh,
            tooltip: 'Refresh',
            onPressed: () {},
          ),
        ),
      ),
    );

    final button = find.byType(PremiumIconButton);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(find.byIcon(HopeV2Icons.refresh), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('quick action strip keeps secondary destinations visible',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: PremiumQuickActionStrip(
            title: 'Quick access',
            actions: [
              PremiumQuickAction(
                label: 'Applications',
                icon: HopeV2Icons.mission,
              ),
              PremiumQuickAction(
                label: 'Offers',
                icon: HopeV2Icons.featured,
              ),
              PremiumQuickAction(
                label: 'Notifications',
                icon: HopeV2Icons.notifications,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PremiumQuickActionStrip), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
  });


  testWidgets('primary navigation shell uses one shared dock on compact screens',
      (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: PremiumPrimaryNavigationScaffold(
          selectedIndex: 2,
          onDestinationSelected: taps.add,
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('hope-navigation-dock')), findsOneWidget);
    expect(find.text('خانه'), findsOneWidget);
    expect(find.text('کاوش'), findsOneWidget);
    expect(find.text('کارگاه'), findsOneWidget);
    expect(find.text('کیف پول'), findsOneWidget);
    expect(find.text('پروفایل'), findsOneWidget);
    final workshopSemantics = find.ancestor(
      of: find.text('کارگاه'),
      matching: find.byType(Semantics),
    ).first;
    final workshopGlyph = tester.widget<HopeNavigationGlyph>(
      find.descendant(
        of: workshopSemantics,
        matching: find.byType(HopeNavigationGlyph),
      ),
    );
    expect(workshopGlyph.icon, HopeV2NavigationIcons.workshopSelected);

    await tester.tap(find.text('کیف پول'));
    await tester.pump();
    expect(taps, [3]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary navigation shell switches to rail on wide screens',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('fa'),
        home: PremiumPrimaryNavigationScaffold(
          selectedIndex: 1,
          onDestinationSelected: (_) {},
          child: const SizedBox.expand(),
        ),
      ),
    );

    expect(find.byType(PremiumNavigationRail), findsOneWidget);
    expect(find.byKey(const ValueKey('hope-navigation-dock')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wave 24 primary dock satisfies Android target sizing and labels',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('fa'),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PremiumNavigationBar(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                destinations: destinations,
              ),
            ),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Wave 29 keeps every navigation label visible at 320x640dp', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('fa'),
        home: Scaffold(
          body: PremiumNavigationBar(
            selectedIndex: 2,
            onDestinationSelected: (_) {},
            destinations: destinations,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('hope-navigation-dock')), findsOneWidget);
    for (final label in ['خانه', 'کاوش', 'کارگاه', 'کیف پول', 'پروفایل']) {
      expect(find.text(label), findsOneWidget, reason: 'Missing compact nav label: $label');
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Compact navigation painted a clipped label: $label',
      );
    }
    expect(tester.takeException(), isNull);
  });



  testWidgets(
    'Wave30 English navigation dock expands vertically at 1.5x without label overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: TextScaler.linear(1.5),
            ),
            child: PremiumPrimaryNavigationScaffold(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dock = find.byKey(const ValueKey('hope-navigation-dock'));
      expect(dock, findsOneWidget);
      expect(tester.getSize(dock).height, greaterThan(68));
      for (final label in ['Home', 'Explore', 'Workshop', 'Wallet', 'Profile']) {
        expect(find.text(label), findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'Large-text navigation painted a clipped label: $label',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Wave 27 scroll tail includes unconsumed system bottom inset',
      (tester) async {
    EdgeInsets? resolvedPadding;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 24),
          ),
          child: Builder(
            builder: (context) {
              resolvedPadding = HopeV2Navigation.scrollEndPadding(context);
              return const SizedBox(
                key: ValueKey('wave27-scroll-end-padding'),
                width: 10,
                height: 1,
              );
            },
          ),
        ),
      ),
    );

    expect(resolvedPadding?.bottom, 36);
  });

  testWidgets(
    'editorial folio plate follows all five logical destinations in RTL and LTR',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final languageCode in ['fa', 'en']) {
        var selectedIndex = 0;
        final selectedCallbacks = <int>[];
        final labels = languageCode == 'fa'
            ? ['خانه', 'کاوش', 'کارگاه', 'کیف پول', 'پروفایل']
            : ['Home', 'Explore', 'Workshop', 'Wallet', 'Profile'];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            locale: Locale(languageCode),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: StatefulBuilder(
              builder: (context, setState) => PremiumPrimaryNavigationScaffold(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  selectedCallbacks.add(index);
                  setState(() => selectedIndex = index);
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final plate = find.byKey(const ValueKey('hope-navigation-selection-plate'));
        expect(plate, findsOneWidget);
        var previousRect = tester.getRect(plate);
        for (var index = 1; index < labels.length; index++) {
          await tester.tap(find.text(labels[index]));
          await tester.pumpAndSettle();
          final currentRect = tester.getRect(plate);
          if (languageCode == 'fa') {
            expect(
              currentRect.center.dx,
              lessThan(previousRect.center.dx),
              reason: 'RTL logical destination $index must move left',
            );
          } else {
            expect(
              currentRect.center.dx,
              greaterThan(previousRect.center.dx),
              reason: 'LTR logical destination $index must move right',
            );
          }
          expect(selectedCallbacks.last, index);
          final selectedLabel = tester.widget<Text>(find.text(labels[index]));
          expect(
            selectedLabel.style?.color,
            HopeV2SemanticColors.navigationLabel(
              tester.element(find.text(labels[index])),
              selected: true,
            ),
            reason: 'Selected label must remain high-contrast neutral',
          );
          previousRect = currentRect;
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reduced-motion preference moves the folio plate without animation',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selectedIndex = 0;
    final selectedCallbacks = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData.fromView(tester.view).copyWith(
            disableAnimations: true,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => PremiumPrimaryNavigationScaffold(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                selectedCallbacks.add(index);
                setState(() => selectedIndex = index);
              },
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    final plate = find.byKey(const ValueKey('hope-navigation-selection-plate'));
    final before = tester.getRect(plate);
    await tester.tap(find.text('کیف پول'));
    await tester.pump();
    final after = tester.getRect(plate);
    expect(after.center.dx, lessThan(before.center.dx));
    expect(selectedCallbacks, [3]);
    expect(tester.takeException(), isNull);
  });


  testWidgets(
    '360dp fa-RTL dock fits Workshop and keeps navigation copy achromatic',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PremiumPrimaryNavigationScaffold(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['خانه', 'کاوش', 'کارگاه', 'کیف پول', 'پروفایل']) {
        expect(find.text(label), findsOneWidget);
        final text = find.text(label);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '360dp navigation must not truncate the rendered label: $label',
        );
        expect(
          find.ancestor(of: text, matching: find.byType(FittedBox)),
          findsNothing,
          reason: 'Navigation labels must reflow rather than scale below the 12sp floor: $label',
        );
        expect(
          tester.widget<Text>(text).style?.fontSize,
          greaterThanOrEqualTo(12),
          reason: 'Navigation labels must preserve the canonical readable type scale: $label',
        );
        final selected = label == 'خانه';
        expect(
          tester.widget<Text>(text).style?.color,
          HopeV2SemanticColors.navigationLabel(
            tester.element(text),
            selected: selected,
          ),
          reason: 'Navigation copy must use the neutral navigation color role.',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'meaningful navigation labels retain a 12sp floor without FittedBox shrinkage',
    (tester) async {
      final scenarios = [
        (width: 320.0, locale: 'fa', scale: 1.0, dark: false),
        (width: 360.0, locale: 'en', scale: 1.5, dark: true),
        (width: 360.0, locale: 'fa', scale: 2.0, dark: false),
      ];

      for (final scenario in scenarios) {
        tester.view.physicalSize = Size(scenario.width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final labels = scenario.locale == 'fa'
            ? ['خانه', 'کاوش', 'کارگاه', 'کیف پول', 'پروفایل']
            : ['Home', 'Explore', 'Workshop', 'Wallet', 'Profile'];
        final destinationsForLocale = labels
            .map(
              (label) => NavigationDestination(
                icon: const Icon(HopeV2Icons.home, size: 24),
                selectedIcon: const Icon(HopeV2Icons.homeSelected, size: 24),
                label: label,
              ),
            )
            .toList(growable: false);

        await tester.pumpWidget(
          MaterialApp(
            theme: scenario.dark ? AppTheme.dark() : AppTheme.light(),
            locale: Locale(scenario.locale),
            supportedLocales: const [Locale('fa'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: MediaQuery(
              data: MediaQueryData.fromView(tester.view).copyWith(
                textScaler: TextScaler.linear(scenario.scale),
              ),
              child: Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: PremiumNavigationBar(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  destinations: destinationsForLocale,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final label in labels) {
          final target = find.text(label);
          expect(target, findsOneWidget);
          expect(
            tester.widget<Text>(target).style?.fontSize,
            greaterThanOrEqualTo(12),
            reason: 'Meaningful dock label "$label" must use at least 12sp.',
          );
          expect(
            find.ancestor(of: target, matching: find.byType(FittedBox)),
            findsNothing,
            reason: 'The dock must reflow meaningful labels rather than scale them below 12sp.',
          );
          expect(
            tester.renderObject<RenderParagraph>(target).didExceedMaxLines,
            isFalse,
            reason: 'The dock must display the complete label "$label".',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'primary navigation uses a coherent Cupertino glyph family and neutral labels',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: PremiumPrimaryNavigationScaffold(
            selectedIndex: 2,
            onDestinationSelected: (_) {},
            child: const SizedBox.expand(),
          ),
        ),
      );

      final workshopSemantics = find.ancestor(
        of: find.text('کارگاه'),
        matching: find.byType(Semantics),
      ).first;
      final glyph = tester.widget<HopeNavigationGlyph>(
        find.descendant(
          of: workshopSemantics,
          matching: find.byType(HopeNavigationGlyph),
        ),
      );
      expect(glyph.icon, CupertinoIcons.briefcase_fill);
      expect(find.text('۰۳'), findsNothing);

      final label = tester.widget<Text>(find.text('کارگاه'));
      expect(
        label.style?.color,
        HopeV2SemanticColors.navigationLabel(
          tester.element(find.text('کارگاه')),
          selected: true,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

}