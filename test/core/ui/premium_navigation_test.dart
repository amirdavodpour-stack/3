import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: HugeIcon(icon: HopeV2Icons.home, size: 24),
      selectedIcon: HugeIcon(icon: HopeV2Icons.homeSelected, size: 24),
      label: 'خانه',
    ),
    NavigationDestination(
      icon: HugeIcon(icon: HopeV2Icons.workshop, size: 24),
      selectedIcon: HugeIcon(icon: HopeV2Icons.workshopSelected, size: 24),
      label: 'کاوش',
    ),
    NavigationDestination(
      icon: HugeIcon(icon: HopeV2Icons.activity, size: 24),
      selectedIcon: HugeIcon(icon: HopeV2Icons.activitySelected, size: 24),
      label: 'فعالیت',
    ),
    NavigationDestination(
      icon: HugeIcon(icon: HopeV2Icons.wallet, size: 24),
      selectedIcon: HugeIcon(icon: HopeV2Icons.walletSelected, size: 24),
      label: 'کیف پول',
    ),
    NavigationDestination(
      icon: HugeIcon(icon: HopeV2Icons.profile, size: 24),
      selectedIcon: HugeIcon(icon: HopeV2Icons.profileSelected, size: 24),
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
    expect(find.text('فعالیت'), findsOneWidget);
    expect(find.text('کیف پول'), findsOneWidget);
    expect(find.text('پروفایل'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('hope-navigation-dock'))).height,
        greaterThanOrEqualTo(64));
  });

  testWidgets('premium mobile navigation is a floating rounded surface',
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
    expect(decoration.borderRadius, BorderRadius.circular(HopeV2Navigation.dockRadius));
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
    expect(find.byType(HugeIcon), findsOneWidget);
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
    expect(find.text('کار'), findsOneWidget);
    expect(find.text('کیف پول'), findsOneWidget);
    expect(find.text('پروفایل'), findsOneWidget);

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
    for (final label in ['خانه', 'کاوش', 'فعالیت', 'کیف پول', 'پروفایل']) {
      expect(find.text(label), findsOneWidget, reason: 'Missing compact nav label: $label');
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
      for (final label in ['Home', 'Explore', 'Work', 'Wallet', 'Profile']) {
        expect(find.text(label), findsOneWidget);
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
}
