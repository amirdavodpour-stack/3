import 'package:flutter/material.dart';
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
      label: 'کارگاه',
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

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(tester.getSize(find.byType(NavigationBar)).height,
        greaterThanOrEqualTo(80));
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

    expect(find.byType(ClipRRect), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PremiumNavigationBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.type, MaterialType.transparency);
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
}
