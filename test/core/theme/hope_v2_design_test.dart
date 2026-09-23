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

  test('HOPE light surfaces stay lavender-led', () {
    expect(HopeV2Colors.backgroundWarm, const Color(0xFFF4F0FB));
    expect(HopeV2Colors.pageLight, const Color(0xFFF1EDF8));
    expect(HopeV2Colors.panelSoftLight, const Color(0xFFFBF9FE));
    expect(HopeV2Colors.navigationLight, const Color(0xFFF7F4FC));
    expect(HopeV2Colors.navigationIndicatorLight, const Color(0xFFE5DFFF));
  });

  test('HOPE warm-brown accent is a light accent token, not the page base', () {
    expect(HopeV2Colors.warmHalo, const Color(0xFFC2A487));
  });

  test('HOPE hero geometry stays intentionally more expressive than standard cards', () {
    expect(HopeV2Radii.hero, 28.0);
    expect(HopeV2Radii.hero, greaterThan(HopeV2Radii.lg));
  });

  testWidgets('HOPE page halo stays subtle over the lavender base', (tester) async {
    late Gradient halo;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            halo = HopeV2Surfaces.pageHalo(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(halo.colors.length, 3);
    expect(halo.colors.first.alpha, lessThanOrEqualTo(13));
    expect(halo.colors.last, Colors.transparent);
  });

  test('HOPE dark surfaces stay cool and avoid the warm-brown palette', () {
    expect(HopeV2Colors.pageDark, HopeV2Colors.darkBackground);
    expect(HopeV2Colors.darkBackground, const Color(0xFF090811));
    expect(HopeV2Colors.darkSurface, const Color(0xFF15131D));
    expect(HopeV2Colors.darkCard, const Color(0xFF1C1925));
    expect(HopeV2Colors.panelSoftDark, const Color(0xFF121A2A));
    expect(HopeV2Colors.inputDark, const Color(0xFF12111A));
    expect(HopeV2Colors.navigationIndicatorDark, const Color(0x3D8B7CFF));
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
