import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('PremiumIconButton satisfies Android target-size and label gates',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        PremiumIconButton(
          icon: HopeV2Icons.refresh,
          tooltip: 'Refresh',
          semanticsIdentifier: 'quality-refresh-action',
          onPressed: () {},
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('quality-refresh-action'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('Premium navigation destinations remain labeled and tappable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PremiumNavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(
                icon: HugeIcon(icon: HopeV2Icons.home, size: 24),
                selectedIcon:
                    HugeIcon(icon: HopeV2Icons.homeSelected, size: 24),
                label: 'خانه',
              ),
              NavigationDestination(
                icon: HugeIcon(icon: HopeV2Icons.workshop, size: 24),
                selectedIcon:
                    HugeIcon(icon: HopeV2Icons.workshopSelected, size: 24),
                label: 'کارگاه',
              ),
              NavigationDestination(
                icon: HugeIcon(icon: HopeV2Icons.activity, size: 24),
                selectedIcon:
                    HugeIcon(icon: HopeV2Icons.activitySelected, size: 24),
                label: 'فعالیت',
              ),
              NavigationDestination(
                icon: HugeIcon(icon: HopeV2Icons.wallet, size: 24),
                selectedIcon:
                    HugeIcon(icon: HopeV2Icons.walletSelected, size: 24),
                label: 'کیف پول',
              ),
              NavigationDestination(
                icon: HugeIcon(icon: HopeV2Icons.profile, size: 24),
                selectedIcon:
                    HugeIcon(icon: HopeV2Icons.profileSelected, size: 24),
                label: 'پروفایل',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('خانه'), findsOneWidget);
    expect(find.bySemanticsLabel('کیف پول'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });
}
