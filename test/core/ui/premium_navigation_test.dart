import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(HopeV2Icons.home),
      selectedIcon: Icon(HopeV2Icons.homeSelected),
      label: 'خانه',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.workshop),
      selectedIcon: Icon(HopeV2Icons.workshopSelected),
      label: 'کارگاه',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.activity),
      selectedIcon: Icon(HopeV2Icons.activitySelected),
      label: 'فعالیت',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.wallet),
      selectedIcon: Icon(HopeV2Icons.walletSelected),
      label: 'کیف پول',
    ),
    NavigationDestination(
      icon: Icon(HopeV2Icons.profile),
      selectedIcon: Icon(HopeV2Icons.profileSelected),
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
