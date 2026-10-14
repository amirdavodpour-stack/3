import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hope_mobile/core/theme/app_theme.dart';
import 'package:hope_mobile/core/theme/hope_v2_design.dart';
import 'package:hope_mobile/core/ui/premium_components.dart';
import 'package:hope_mobile/core/ui/components.dart';

double _contrastRatio(Color foreground, Color background) {
  final luminances = [
    foreground.computeLuminance(),
    background.computeLuminance(),
  ]..sort();
  return (luminances.last + 0.05) / (luminances.first + 0.05);
}

void main() {
  test('HOPE theme compatibility facade resolves from the token source', () {
    expect(AppColors.primary, HopeV2Colors.primary);
    expect(AppColors.secondary, HopeV2Colors.secondary);
    expect(AppColors.warning, HopeV2Colors.warning);
    expect(HopeV2Touch.minimum, 48.0);
    expect(HopeV2Motion.standard, const Duration(milliseconds: 240));
  });

  test('FilledButton theme roles meet WCAG AA contrast in light and dark modes', () {
    final light = AppTheme.light().colorScheme;
    expect(light.primary, AppColors.primaryAction);
    expect(light.onPrimary, Colors.white);
    expect(
      _contrastRatio(light.onPrimary, light.primary),
      greaterThanOrEqualTo(4.5),
    );

    final dark = AppTheme.dark().colorScheme;
    expect(dark.primary, AppColors.primaryDark);
    expect(dark.onPrimary, AppColors.ink);
    expect(
      _contrastRatio(dark.onPrimary, dark.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('HOPE palette restores navy-charcoal surfaces, indigo actions, and restrained forest accents', () {
    expect(HopeV2Colors.primary, const Color(0xFF6366F1));
    expect(HopeV2Colors.primaryAction, const Color(0xFF4F46E5));
    expect(HopeV2Colors.primaryDark, const Color(0xFF818CF8));
    expect(HopeV2Colors.secondaryAction, const Color(0xFF0F766E));
    expect(HopeV2Colors.secondary, const Color(0xFF14B8A6));
    expect(HopeV2Colors.success, const Color(0xFF27764C));
    expect(HopeV2Colors.darkGreenGlow, const Color(0xFF264C36));
    expect(HopeV2Colors.darkSurface, const Color(0xFF0F111A));
    expect(HopeV2Colors.darkCard, const Color(0xFF111827));
    expect(HopeV2Colors.darkText, const Color(0xFFF1F3EC));
    expect(HopeV2Gradients.hero.colors, isNot(contains(const Color(0xFF5D43E8))));
    expect(HopeV2Gradients.heroDark.colors, isNot(contains(const Color(0xFF37318C))));
  });

  test('wallet balance hero palette is centralized without visual drift', () {
    expect(HopeV2Colors.walletBalanceHeroStart, const Color(0xFF121726));
    expect(HopeV2Colors.walletBalanceHeroMiddle, const Color(0xFF1B2748));
    expect(HopeV2Colors.walletBalanceHeroEnd, const Color(0xFF0E131E));
    expect(HopeV2Colors.walletBalanceOnHero, const Color(0xFFFFFFFF));
    expect(HopeV2Colors.walletBalanceOnHeroMuted, const Color(0xB3FFFFFF));
    expect(HopeV2Colors.walletBalanceOnHeroSubtle, const Color(0x99FFFFFF));
    expect(HopeV2Colors.walletBalanceMetricFill, const Color(0x0BFFFFFF));
    expect(HopeV2Colors.walletBalanceMetricBorder, const Color(0x0FFFFFFF));
    expect(HopeV2Colors.walletBalanceMetricBorderEmphasized, const Color(0x3DFFFFFF));
  });

  testWidgets('domain accents adapt to the active light or dark theme',
      (tester) async {
    late Color lightPrimary;
    late Color lightSecondary;
    late Color darkPrimary;
    late Color darkSecondary;

    await tester.pumpWidget(
      Theme(
        data: AppTheme.light(),
        child: Builder(
          builder: (context) {
            lightPrimary = HopeProductDomain.work.spec.accentFor(context);
            lightSecondary = HopeProductDomain.discovery.spec.accentFor(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      Theme(
        data: AppTheme.dark(),
        child: Builder(
          builder: (context) {
            darkPrimary = HopeProductDomain.work.spec.accentFor(context);
            darkSecondary = HopeProductDomain.discovery.spec.accentFor(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(lightPrimary, HopeV2Colors.primary);
    expect(darkPrimary, HopeV2Colors.primaryDark);
    expect(lightSecondary, HopeV2Colors.secondary);
    expect(darkSecondary, HopeV2Colors.secondaryDark);
  });

  testWidgets('semantic facade resolves error, border and surface from the active theme',
      (tester) async {
    late Color semanticError;
    late Color themeError;
    late Color semanticBorder;
    late Color surfaceBorder;
    late Color semanticSurface;
    late Color themeSurface;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            themeError = Theme.of(context).colorScheme.error;
            semanticError = HopeV2SemanticColors.error(context);
            surfaceBorder = HopeV2Surfaces.border(context);
            semanticBorder = HopeV2SemanticColors.border(context);
            themeSurface = Theme.of(context).colorScheme.surface;
            semanticSurface = HopeV2SemanticColors.surface(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(semanticError, themeError);
    expect(semanticBorder, surfaceBorder);
    expect(semanticSurface, themeSurface);
  });

  test('HOPE light surfaces use restrained warm neutrals', () {
    expect(HopeV2Colors.backgroundWarm, const Color(0xFFF5F3EA));
    expect(HopeV2Colors.pageLight, const Color(0xFFF2F0E8));
    expect(HopeV2Colors.panelSoftLight, const Color(0xFFFAF9F4));
    expect(HopeV2Colors.navigationLight, const Color(0xFFF9F8F3));
    expect(HopeV2Colors.navigationIndicatorLight, const Color(0xFFE9E1D0));
  });

  test('HOPE typography keeps font selection behind a single design-system token', () {
    expect(HopeV2Typography.primaryFontFamily, 'Vazirmatn');
    expect(HopeV2Typography.fontFamilyFallback, contains('Roboto'));
  });

  test('HOPE warm-brown accent is a light accent token, not the page base', () {
    expect(HopeV2Colors.warmHalo, const Color(0xFFC2A487));
  });

  test('HOPE hero geometry stays intentionally more expressive than standard cards', () {
    expect(HopeV2Radii.hero, 28.0);
    expect(HopeV2Radii.hero, greaterThan(HopeV2Radii.lg));
  });

  testWidgets('premium hero renders with the shared expressive surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: PremiumHero(
            eyebrow: 'FEATURED',
            title: 'فرصت پیشنهادی',
            message: 'جزئیات فرصت',
            icon: HopeV2Icons.featured,
          ),
        ),
      ),
    );

    expect(find.byType(PremiumHero), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
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
    expect((halo.colors.first.a * 255.0).round().clamp(0, 255), lessThanOrEqualTo(13));
    expect(halo.colors.last, Colors.transparent);
  });

  test('HOPE dark surfaces stay navy-charcoal with a subdued forest-green halo token', () {
    expect(HopeV2Colors.pageDark, HopeV2Colors.darkBackground);
    expect(HopeV2Colors.darkBackground, const Color(0xFF070A12));
    expect(HopeV2Colors.darkSurface, const Color(0xFF0F111A));
    expect(HopeV2Colors.darkCard, const Color(0xFF111827));
    expect(HopeV2Colors.panelDark, const Color(0xFF101522));
    expect(HopeV2Colors.panelSoftDark, const Color(0xFF121726));
    expect(HopeV2Colors.inputDark, const Color(0xFF0F111A));
    expect(HopeV2Colors.navigationIndicatorDark, const Color(0x2B6366F1));
    expect(HopeV2Colors.darkGreenGlow, const Color(0xFF264C36));
  });

  test('dropdown and popup options use readable theme text instead of black defaults', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    expect(light.dropdownMenuTheme.textStyle?.color, light.colorScheme.onSurface);
    expect(light.popupMenuTheme.textStyle?.color, light.colorScheme.onSurface);
    expect(dark.dropdownMenuTheme.textStyle?.color, dark.colorScheme.onSurface);
    expect(dark.popupMenuTheme.textStyle?.color, dark.colorScheme.onSurface);
    expect(light.listTileTheme.textColor, light.colorScheme.onSurface);
    expect(dark.listTileTheme.textColor, dark.colorScheme.onSurface);
    expect(light.dropdownMenuTheme.textStyle?.color, isNot(Colors.black));
    expect(dark.dropdownMenuTheme.textStyle?.color, isNot(Colors.black));
    expect(light.listTileTheme.textColor, isNot(Colors.black));
    expect(dark.listTileTheme.textColor, isNot(Colors.black));
  });

  testWidgets('premium tags stay on one line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: PremiumTag(
            label: 'برچسب طولانی نمونه',
            color: HopeV2Colors.secondary,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('برچسب طولانی نمونه'));
    expect(text.maxLines, 1);
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
  testWidgets('compatibility status and empty-state primitives accept canonical icons',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              StatusPill(
                'Done',
                icon: HopeV2Icons.completed,
              ),
              EmptyState(
                icon: HopeV2Icons.secure,
                title: 'Private',
                message: 'Sign in to continue',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(HugeIcon), findsWidgets);
  });

}
