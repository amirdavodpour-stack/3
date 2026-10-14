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


  test('money and information text roles are separate from indigo actions', () {
    expect(HopeV2Colors.moneyTextLight, HopeV2Colors.ink);
    expect(HopeV2Colors.moneyTextDark, HopeV2Colors.darkText);
    expect(HopeV2Colors.infoTextLight, HopeV2Colors.secondaryAction);
    expect(HopeV2Colors.infoTextDark, HopeV2Colors.secondaryDark);

    final indigoActions = {
      HopeV2Colors.primary,
      HopeV2Colors.primaryAction,
      HopeV2Colors.primaryDark,
      HopeV2Colors.primaryActionHoverLight,
      HopeV2Colors.primaryActionPressedLight,
    };
    for (final readable in [
      HopeV2Colors.moneyTextLight,
      HopeV2Colors.moneyTextDark,
      HopeV2Colors.infoTextLight,
      HopeV2Colors.infoTextDark,
    ]) {
      expect(indigoActions.contains(readable), isFalse);
    }

    final lightSurfaces = [
      HopeV2Colors.surface,
      HopeV2Colors.backgroundWarm,
      HopeV2Colors.pageLight,
      HopeV2Colors.panelSoftLight,
      HopeV2Colors.navigationLight,
      HopeV2Colors.chipLight,
    ];
    final darkSurfaces = [
      HopeV2Colors.darkBackground,
      HopeV2Colors.darkSurface,
      HopeV2Colors.darkCard,
      HopeV2Colors.panelDark,
      HopeV2Colors.panelSoftDark,
      HopeV2Colors.inputDark,
    ];
    for (final surface in lightSurfaces) {
      expect(_contrastRatio(HopeV2Colors.moneyTextLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.infoTextLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.successOnLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.warningOnLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.dangerOnLight, surface), greaterThanOrEqualTo(4.5));
    }
    for (final surface in darkSurfaces) {
      expect(_contrastRatio(HopeV2Colors.moneyTextDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.infoTextDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.successDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.warningDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.dangerDark, surface), greaterThanOrEqualTo(4.5));
    }
  });

  test('HOPE color genome provides six complete 50–950 tonal scales', () {
    const expectedSteps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];
    final palettes = <HopeV2TonalPalette>[
      HopeV2TonalPalettes.brand,
      HopeV2TonalPalettes.neutral,
      HopeV2TonalPalettes.info,
      HopeV2TonalPalettes.success,
      HopeV2TonalPalettes.warning,
      HopeV2TonalPalettes.danger,
    ];
    const expectedValues = <List<Color>>[
      [
        Color(0xFFEEF2FF), Color(0xFFE0E7FF), Color(0xFFC7D2FE),
        Color(0xFFA5B4FC), Color(0xFF818CF8), Color(0xFF6366F1),
        Color(0xFF4F46E5), Color(0xFF4338CA), Color(0xFF3730A3),
        Color(0xFF312E81), Color(0xFF1E1B4B),
      ],
      [
        Color(0xFFFAF9F4), Color(0xFFF2F0E8), Color(0xFFE9E5D9),
        Color(0xFFD6D1C4), Color(0xFFB4AE9E), Color(0xFF8B8779),
        Color(0xFF66675B), Color(0xFF4A4C43), Color(0xFF34372D),
        Color(0xFF24271F), Color(0xFF12140F),
      ],
      [
        Color(0xFFE6FFFB), Color(0xFFCCFBF1), Color(0xFF99F6E4),
        Color(0xFF5EEAD4), Color(0xFF2DD4BF), Color(0xFF14B8A6),
        Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF115E59),
        Color(0xFF134E4A), Color(0xFF042F2E),
      ],
      [
        Color(0xFFF0FDF4), Color(0xFFDCFCE7), Color(0xFFBBF7D0),
        Color(0xFF86EFAC), Color(0xFF4ADE80), Color(0xFF22C55E),
        Color(0xFF16A34A), Color(0xFF15803D), Color(0xFF166534),
        Color(0xFF14532D), Color(0xFF052E16),
      ],
      [
        Color(0xFFFFFBEB), Color(0xFFFEF3C7), Color(0xFFFDE68A),
        Color(0xFFFCD34D), Color(0xFFFBBF24), Color(0xFFF59E0B),
        Color(0xFFD97706), Color(0xFFB45309), Color(0xFF92400E),
        Color(0xFF78350F), Color(0xFF451A03),
      ],
      [
        Color(0xFFFEF2F2), Color(0xFFFEE2E2), Color(0xFFFECACA),
        Color(0xFFFCA5A5), Color(0xFFF87171), Color(0xFFEF4444),
        Color(0xFFDC2626), Color(0xFFB91C1C), Color(0xFF991B1B),
        Color(0xFF7F1D1D), Color(0xFF450A0A),
      ],
    ];

    expect(HopeV2TonalPalette.steps, expectedSteps);
    for (var paletteIndex = 0; paletteIndex < palettes.length; paletteIndex++) {
      final palette = palettes[paletteIndex];
      expect(palette.values, expectedValues[paletteIndex]);
      for (var stopIndex = 0; stopIndex < expectedSteps.length; stopIndex++) {
        expect(palette.shade(expectedSteps[stopIndex]), expectedValues[paletteIndex][stopIndex]);
      }
    }
    expect(() => HopeV2TonalPalettes.brand.shade(75), throwsArgumentError);
    expect(HopeV2TonalPalettes.brand.shade(500), HopeV2Colors.primary);
    expect(HopeV2TonalPalettes.neutral.shade(900), HopeV2Colors.ink);
    expect(HopeV2TonalPalettes.info.shade(700), HopeV2Colors.secondaryAction);
    expect(HopeV2TonalPalettes.warning.shade(500), HopeV2Colors.accent);
    expect(HopeV2TonalPalettes.danger.shade(700), HopeV2Colors.dangerOnLight);
  });

  testWidgets('featured and financial semantic roles use readable non-brand foregrounds',
      (tester) async {
    late Map<String, Color> light;
    late Map<String, Color> dark;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(builder: (context) {
        light = {
          'amount': HopeV2SemanticColors.amount(context),
          'neutral': HopeV2SemanticColors.neutral(context),
          'featured': HopeV2SemanticColors.featured(context),
          'pending': HopeV2SemanticColors.pending(context),
          'processing': HopeV2SemanticColors.processing(context),
          'incoming': HopeV2SemanticColors.incomingAmount(context),
          'outgoing': HopeV2SemanticColors.outgoingAmount(context),
          'accentSurface': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.orange),
          'accentForeground': HopeV2SemanticColors.readableAccent(context, HopeV2Colors.orange),
        };
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(builder: (context) {
        dark = {
          'amount': HopeV2SemanticColors.amount(context),
          'neutral': HopeV2SemanticColors.neutral(context),
          'featured': HopeV2SemanticColors.featured(context),
          'pending': HopeV2SemanticColors.pending(context),
          'processing': HopeV2SemanticColors.processing(context),
          'incoming': HopeV2SemanticColors.incomingAmount(context),
          'outgoing': HopeV2SemanticColors.outgoingAmount(context),
          'accentSurface': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.orangeDark),
          'accentForeground': HopeV2SemanticColors.readableAccent(context, HopeV2Colors.orangeDark),
        };
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();

    expect(light['amount'], HopeV2Colors.moneyTextLight);
    expect(dark['amount'], HopeV2Colors.moneyTextDark);
    expect(light['neutral'], HopeV2Colors.muted);
    expect(dark['neutral'], HopeV2Colors.darkMuted);
    expect(light['featured'], HopeV2Colors.accentTextLight);
    expect(dark['featured'], HopeV2Colors.accentTextDark);
    expect(light['pending'], HopeV2Colors.warningOnLight);
    expect(dark['pending'], HopeV2Colors.warningDark);
    expect(light['processing'], HopeV2Colors.infoTextLight);
    expect(dark['processing'], HopeV2Colors.infoTextDark);
    expect(light['incoming'], HopeV2Colors.successOnLight);
    expect(dark['incoming'], HopeV2Colors.successDark);
    expect(light['outgoing'], HopeV2Colors.dangerOnLight);
    expect(dark['outgoing'], HopeV2Colors.dangerDark);
    expect(light['accentSurface'], HopeV2Colors.accentSurfaceLight);
    expect(dark['accentSurface'], HopeV2Colors.accentSurfaceDark);
    expect(light['accentForeground'], HopeV2Colors.accentTextLight);
    expect(dark['accentForeground'], HopeV2Colors.accentTextDark);

    final brandActionColors = <Color>{
      HopeV2Colors.primary,
      HopeV2Colors.primaryAction,
      HopeV2Colors.primaryDark,
      HopeV2Colors.primaryActionHoverLight,
      HopeV2Colors.primaryActionPressedLight,
    };
    for (final foreground in [
      ...light.values.where((color) => color != HopeV2Colors.accentSurfaceLight),
      ...dark.values.where((color) => color != HopeV2Colors.accentSurfaceDark),
    ]) {
      expect(brandActionColors.contains(foreground), isFalse);
    }

    final lightTextSurfaces = [
      HopeV2Colors.surface,
      HopeV2Colors.backgroundWarm,
      HopeV2Colors.pageLight,
      HopeV2Colors.panelSoftLight,
      HopeV2Colors.chipLight,
      HopeV2Colors.accentSurfaceLight,
    ];
    final darkTextSurfaces = [
      HopeV2Colors.darkBackground,
      HopeV2Colors.darkSurface,
      HopeV2Colors.darkCard,
      HopeV2Colors.panelDark,
      HopeV2Colors.panelSoftDark,
      HopeV2Colors.accentSurfaceDark,
    ];
    for (final surface in lightTextSurfaces) {
      expect(_contrastRatio(HopeV2Colors.accentTextLight, surface), greaterThanOrEqualTo(4.5));
    }
    for (final surface in darkTextSurfaces) {
      expect(_contrastRatio(HopeV2Colors.accentTextDark, surface), greaterThanOrEqualTo(4.5));
    }
  });

  test('readable theme labels stay neutral while indigo remains available for controls', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final text = theme.brightness == Brightness.dark
          ? HopeV2Colors.darkText
          : HopeV2Colors.ink;
      expect(theme.listTileTheme.selectedColor, text);
      expect(theme.tabBarTheme.labelColor, text);
      expect(theme.textButtonTheme.style?.foregroundColor?.resolve({}), text);
      expect(theme.outlinedButtonTheme.style?.foregroundColor?.resolve({}), text);
      expect(
        theme.navigationBarTheme.labelTextStyle?.resolve({WidgetState.selected})?.color,
        text,
      );
      expect(theme.navigationRailTheme.selectedLabelTextStyle?.color, text);
    }
  });

  testWidgets('brand-accent chip labels and informational status text are readable',
      (tester) async {
    Future<void> pump(Brightness brightness) async {
      final theme =
          brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PremiumTag(label: 'Brand tag', color: HopeV2Colors.primary),
              PremiumFilterChip(
                label: 'Selected filter',
                selected: true,
                color: HopeV2Colors.primary,
                onTap: () {},
              ),
              const StatusPill('Information'),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final neutral = brightness == Brightness.dark
          ? HopeV2Colors.darkText
          : HopeV2Colors.ink;
      expect(tester.widget<Text>(find.text('Brand tag')).style?.color, neutral);
      expect(tester.widget<Text>(find.text('Selected filter')).style?.color, neutral);
      expect(
        tester.widget<Text>(find.text('Information')).style?.color,
        brightness == Brightness.dark ? HopeV2Colors.infoTextDark : HopeV2Colors.infoTextLight,
      );
    }

    await pump(Brightness.light);
    await pump(Brightness.dark);
  });


  testWidgets('semantic status surfaces resolve to distinct light and dark tonal roles',
      (tester) async {
    late Map<String, Color> light;
    late Map<String, Color> dark;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(builder: (context) {
        light = {
          'info': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.primary),
          'success': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.success),
          'warning': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.warning),
          'danger': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.danger),
        };
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Theme(
        data: AppTheme.dark(),
        child: Builder(builder: (context) {
          expect(Theme.of(context).brightness, Brightness.dark);
          dark = {
            'info': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.primaryDark),
            'success': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.successDark),
            'warning': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.warningDark),
            'danger': HopeV2SemanticColors.statusSurface(context, HopeV2Colors.dangerDark),
          };
          return const SizedBox();
        }),
      ),
    ));
    expect(light['info'], HopeV2Colors.infoSurfaceLight);
    expect(light['success'], HopeV2Colors.successSurfaceLight);
    expect(light['warning'], HopeV2Colors.warningSurfaceLight);
    expect(light['danger'], HopeV2Colors.dangerSurfaceLight);
    expect(dark['info'], HopeV2Colors.infoSurfaceDark);
    expect(dark['success'], HopeV2Colors.successSurfaceDark);
    expect(dark['warning'], HopeV2Colors.warningSurfaceDark);
    expect(dark['danger'], HopeV2Colors.dangerSurfaceDark);
  });

}
