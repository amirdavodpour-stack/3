import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';

void main() {
  test('HOPE theme compatibility facade resolves from the token source', () {
    expect(AppColors.primary, HopeV2Colors.primary);
    expect(AppColors.secondary, HopeV2Colors.secondary);
    expect(AppColors.warning, HopeV2Colors.warning);
    expect(HopeV2Touch.minimum, 48.0);
    expect(HopeV2Motion.standard, const Duration(milliseconds: 240));
  });

  test('HOPE warm background tokens use the premium warm-neutral palette', () {
    expect(HopeV2Colors.backgroundWarm, const Color(0xFFF4F0FB));
    expect(HopeV2Colors.pageLight, const Color(0xFFF1EDF8));
    expect(HopeV2Colors.panelSoftLight, const Color(0xFFFBF9FE));
  });


  test('HOPE page background keeps lavender base and warm-brown halo', () {
    expect(HopeV2Colors.warmHalo, const Color(0x7A9A7658));
  });

  test('HOPE action icon vocabulary is backed by Hugeicons data', () {
    expect(HopeV2Icons.search, isA<List<List>>());
    expect(HopeV2Icons.menu, isA<List<List>>());
    expect(HopeV2Icons.refresh, isA<List<List>>());
    expect(HopeV2Icons.add, isA<List<List>>());
    expect(HopeV2Icons.notifications, isA<List<List>>());
  });

  testWidgets('premium filter chip exposes disabled and loading states',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: PremiumFilterChip(
              label: 'فیلتر',
              selected: false,
              enabled: false,
              loading: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final chip = find.byType(PremiumFilterChip);
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final semantics = tester.getSemantics(chip);
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isEnabled, isNot(ui.Tristate.none));
    expect(semantics.flagsCollection.isEnabled, ui.Tristate.isFalse);
  });

  testWidgets('HopeIconTile renders canonical Hugeicons action tokens',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: HopeIconTile(
              HopeV2Icons.search,
              filled: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(HugeIcon), findsOneWidget);
  });
}
