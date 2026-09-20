import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'خانه',
    ),
    NavigationDestination(
      icon: Icon(Icons.explore_outlined),
      selectedIcon: Icon(Icons.explore_rounded),
      label: 'کاوش',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox_rounded),
      label: 'فعالیت',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet_rounded),
      label: 'کیف پول',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
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
}
