import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(light.onPrimary, AppColors.surface);
    expect(light.tertiary, HopeV2TonalPalettes.forest.shade600);
    expect(light.onTertiary, AppColors.surface);
    expect(
      _contrastRatio(light.onPrimary, light.primary),
      greaterThanOrEqualTo(4.5),
    );

    final dark = AppTheme.dark().colorScheme;
    expect(dark.primary, AppColors.primaryDark);
    expect(dark.onPrimary, AppColors.ink);
    expect(dark.tertiary, HopeV2TonalPalettes.forest.shade300);
    expect(dark.onTertiary, HopeV2TonalPalettes.forest.shade900);
    expect(
      _contrastRatio(dark.onPrimary, dark.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('annotated dark-green CTA token meets WCAG AA and preserves indigo brand tokens', () {
    expect(HopeV2Colors.markedPrimaryActionDarkGreen, const Color(0xFF2E7B5A));
    expect(
      _contrastRatio(HopeV2Colors.darkText, HopeV2Colors.markedPrimaryActionDarkGreen),
      greaterThanOrEqualTo(4.5),
    );
    expect(HopeV2Colors.primaryAction, const Color(0xFF4F46E5));
    expect(HopeV2Colors.primaryDark, const Color(0xFF818CF8));
    expect(HopeV2Colors.success, const Color(0xFF166534));
  });

  testWidgets('audited green CTA keeps disabled state neutral in light and dark themes', (tester) async {
    late ButtonStyle darkStyle;
    await tester.pumpWidget(
      Theme(
        data: AppTheme.dark(),
        child: Builder(
          builder: (context) {
            darkStyle = HopeV2ButtonStyles.auditedGreenPrimaryCta(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(darkStyle.backgroundColor?.resolve({}), HopeV2Colors.markedPrimaryActionDarkGreen);
    expect(darkStyle.backgroundColor?.resolve({WidgetState.disabled}), HopeV2Colors.darkSurface);
    expect(darkStyle.foregroundColor?.resolve({WidgetState.disabled}), HopeV2Colors.darkMuted);
    expect(
      _contrastRatio(darkStyle.foregroundColor!.resolve({})!, darkStyle.backgroundColor!.resolve({})!),
      greaterThanOrEqualTo(4.5),
    );

    late ButtonStyle lightStyle;
    await tester.pumpWidget(
      Theme(
        data: AppTheme.light(),
        child: Builder(
          builder: (context) {
            lightStyle = HopeV2ButtonStyles.auditedGreenPrimaryCta(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(lightStyle.backgroundColor?.resolve({}), HopeV2Colors.markedPrimaryActionDarkGreen);
    expect(lightStyle.backgroundColor?.resolve({WidgetState.disabled}), HopeV2Colors.disabledLight);
    expect(lightStyle.foregroundColor?.resolve({WidgetState.disabled}), HopeV2Colors.muted);
    expect(
      _contrastRatio(lightStyle.foregroundColor!.resolve({})!, lightStyle.backgroundColor!.resolve({})!),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('indigo action pairings meet WCAG AA with editorial surfaces', () {
    expect(
      _contrastRatio(HopeV2Colors.surface, HopeV2Colors.primaryAction),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(HopeV2Colors.ink, HopeV2Colors.primaryDark),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(HopeV2Colors.primaryDark, HopeV2Colors.darkBackground),
      greaterThanOrEqualTo(4.5),
    );
    expect(HopeV2TonalPalettes.brand, HopeV2TonalPalettes.indigo);
    expect(HopeV2TonalPalettes.indigo.shade(400), HopeV2Colors.primaryDark);
    expect(HopeV2Colors.backgroundWarm, const Color(0xFFF4F0E5));
    expect(HopeV2Colors.editorialClay, const Color(0xFFD0A16D));
    expect(HopeV2Colors.darkBackground, const Color(0xFF070A12));
  });

  test('HOPE palette restores indigo actions, distinct semantic accents, and navy-charcoal surfaces', () {
    expect(HopeV2Colors.primary, const Color(0xFF6366F1));
    expect(HopeV2Colors.primaryAction, const Color(0xFF4F46E5));
    expect(HopeV2Colors.primaryDark, const Color(0xFF818CF8));
    expect(HopeV2Colors.secondaryAction, const Color(0xFF0F766E));
    expect(HopeV2Colors.secondary, const Color(0xFF14B8A6));
    expect(HopeV2Colors.success, const Color(0xFF166534));
    expect(HopeV2Colors.darkGreenGlow, const Color(0xFF264C36));
    expect(HopeV2Colors.darkSurface, const Color(0xFF0F111A));
    expect(HopeV2Colors.darkCard, const Color(0xFF111827));
    expect(HopeV2Colors.darkText, const Color(0xFFF1F3EC));
    expect(
      HopeV2Gradients.hero.colors,
      const [
        Color(0xFF5B5343),
        Color(0xFF827252),
        Color(0xFFB9A77C),
      ],
      reason: 'Light-mode editorial heroes retain the prior restrained warm-neutral ramp.',
    );
    expect(
      HopeV2Gradients.heroDark.colors,
      const [
        Color(0xFF121726),
        Color(0xFF1B2748),
        Color(0xFF121726),
      ],
      reason: 'Dark-mode heroes must retain the prior slate/navy ramp rather than a green wash.',
    );
    expect(HopeV2Shadows.card.single.color, const Color(0x0D1B1638));
    expect(HopeV2Shadows.hero.single.color, const Color(0x1A1C1738));
  });

  test('opportunity artwork accents stay unique and separate from semantic states', () {
    const accents = <Color>[
      HopeV2OpportunityAccents.software,
      HopeV2OpportunityAccents.design,
      HopeV2OpportunityAccents.marketing,
      HopeV2OpportunityAccents.content,
      HopeV2OpportunityAccents.finance,
      HopeV2OpportunityAccents.education,
      HopeV2OpportunityAccents.support,
      HopeV2OpportunityAccents.construction,
      HopeV2OpportunityAccents.media,
      HopeV2OpportunityAccents.data,
      HopeV2OpportunityAccents.sales,
    ];

    expect(accents.toSet(), hasLength(accents.length));
    expect(accents, isNot(contains(HopeV2Colors.primary)));
    expect(accents, isNot(contains(HopeV2Colors.primaryAction)));
    expect(accents, isNot(contains(HopeV2Colors.primaryDark)));
    expect(accents, isNot(contains(HopeV2Colors.secondary)));
    expect(accents, isNot(contains(HopeV2Colors.success)));
    expect(accents, isNot(contains(HopeV2Colors.warning)));
    expect(accents, isNot(contains(HopeV2Colors.danger)));
    expect(accents, isNot(contains(HopeV2Colors.trustTextLight)));
    expect(accents, isNot(contains(HopeV2Colors.accentTextLight)));
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
    expect(HopeV2Colors.backgroundWarm, const Color(0xFFF4F0E5));
    expect(HopeV2Colors.pageLight, const Color(0xFFF4F0E5));
    expect(HopeV2Colors.panelSoftLight, const Color(0xFFF9F6ED));
    expect(HopeV2Colors.navigationLight, const Color(0xFFF9F8F3));
    expect(HopeV2Colors.navigationIndicatorLight, const Color(0xFFE0E7FF));
  });

  test('HOPE typography keeps font selection behind a single design-system token', () {
    expect(HopeV2Typography.primaryFontFamily, 'Vazirmatn');
    expect(HopeV2Typography.fontFamilyFallback, contains('Roboto'));
  });

  test('HOPE warm-brown accent is a light accent token, not the page base', () {
    expect(HopeV2Colors.warmHalo, const Color(0xFFD0A16D));
  });

  test('HOPE hero geometry stays intentionally more expressive than standard cards', () {
    expect(HopeV2Radii.hero, 18.0);
    expect(HopeV2Radii.hero, greaterThan(HopeV2Radii.lg));
  });

  testWidgets('editorial heroes stay bounded on compact, compact-auth, and wide layouts',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);

    Widget renderHero({bool compactHero = false}) => MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: PremiumHero(
              eyebrow: 'EDITORIAL',
              title: 'A concise headline',
              message: 'Supporting information remains secondary.',
              compactHero: compactHero,
            ),
          ),
        );

    await tester.pumpWidget(renderHero());
    expect(
      tester.getSize(find.byType(PremiumHero)).height,
      lessThanOrEqualTo(204),
      reason: 'A standard mobile hero must not consume more than one editorial band.',
    );

    await tester.pumpWidget(renderHero(compactHero: true));
    expect(
      tester.getSize(find.byType(PremiumHero)).height,
      lessThanOrEqualTo(148),
      reason: 'Auth and compact heroes should stay visibly subordinate to the form.',
    );

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(renderHero());
    expect(
      tester.getSize(find.byType(PremiumHero)).height,
      lessThanOrEqualTo(224),
      reason: 'Wide layouts should not scale a hero into a billboard.',
    );
  });

  testWidgets('editorial hero with a primary action remains overflow-free on RTL mobile',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: PremiumHero(
                eyebrow: 'حساب کاربری',
                title: 'مسیر حرفه‌ای خود را ادامه دهید',
                message: 'پروفایل، فرصت‌ها و تراکنش‌های خود را یکجا مدیریت کنید.',
                icon: HopeV2Icons.profile,
                action: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {},
                        child: const Text('ساخت حساب'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        child: const Text('ورود'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(PremiumHero)).height, lessThanOrEqualTo(204));
    expect(tester.takeException(), isNull);
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

  test('HOPE dark surfaces restore the prior navy-charcoal hierarchy with a restrained green glow token', () {
    expect(HopeV2Colors.pageDark, HopeV2Colors.darkBackground);
    expect(HopeV2Colors.darkBackground, const Color(0xFF070A12));
    expect(HopeV2Colors.darkSurface, const Color(0xFF0F111A));
    expect(HopeV2Colors.darkCard, const Color(0xFF111827));
    expect(HopeV2Colors.panelDark, const Color(0xFF101522));
    expect(HopeV2Colors.panelSoftDark, const Color(0xFF121726));
    expect(HopeV2Colors.inputDark, const Color(0xFF0F111A));
    expect(HopeV2Colors.navigationIndicatorDark, const Color(0x2B6366F1));
    expect(HopeV2Colors.navigationDark, const Color(0xF90B0F18));
    expect(HopeV2Colors.darkGreenGlow, const Color(0xFF264C36));
  });

  test('generic dark elevation shadows use indigo and navy tones', () {
    expect(
      HopeV2Shadows.heroDark.map((shadow) => shadow.color).toList(),
      const [Color(0x12333B70), Color(0x062B345F)],
    );
    expect(
      HopeV2Shadows.gradientHero.single.color,
      const Color(0x1A2C3372),
    );
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

  test('HOPE action icon vocabulary uses the Cupertino font package consistently', () {
    final icons = <IconData>[
      HopeV2Icons.home,
      HopeV2Icons.homeSelected,
      HopeV2Icons.workshop,
      HopeV2Icons.wallet,
      HopeV2Icons.profile,
      HopeV2Icons.search,
      HopeV2Icons.menu,
      HopeV2Icons.refresh,
      HopeV2Icons.add,
      HopeV2Icons.notifications,
      HopeV2Icons.mission,
      HopeV2Icons.activity,
      HopeV2Icons.activitySelected,
      HopeV2Icons.insights,
      HopeV2Icons.partial,
      HopeV2Icons.description,
      HopeV2Icons.assign,
      HopeV2Icons.protectedFunds,
      HopeV2Icons.transferIn,
      HopeV2Icons.transferOut,
      HopeV2Icons.verified,
      HopeV2Icons.error,
      HopeV2Icons.empty,
      HopeV2Icons.offline,
      HopeV2Icons.history,
      HopeV2Icons.deadline,
      HopeV2Icons.deposit,
      HopeV2Icons.withdraw,
    ];
    expect(icons, isNotEmpty);
    expect(
      icons.every(
        (icon) =>
            icon.fontFamily == CupertinoIcons.iconFont &&
            icon.fontPackage == CupertinoIcons.iconFontPackage,
      ),
      isTrue,
    );
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

  testWidgets('lifecycle rail readable labels stay neutral in light and dark themes',
      (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: HopeLifecycleRail(
              labels: const ['Created', 'Funded', 'Released'],
              icons: const [
                Icons.circle,
                Icons.account_balance_wallet,
                Icons.check_circle,
              ],
              current: 1,
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(HopeLifecycleRail));
      expect(
        tester.widget<Text>(find.text('Created')).style?.color,
        HopeV2SemanticColors.textPrimary(context),
      );
      expect(
        tester.widget<Text>(find.text('Funded')).style?.color,
        HopeV2SemanticColors.textPrimary(context),
      );
      expect(
        tester.widget<Text>(find.text('Released')).style?.color,
        HopeV2SemanticColors.textSecondary(context),
      );
    }
  });

  testWidgets('domain accent graphics do not tint readable domain text',
      (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          theme: theme,
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PremiumQuickActionStrip(
                  title: 'Work center',
                  domain: HopeProductDomain.work,
                  actions: const [
                    PremiumQuickAction(
                      label: 'Continue',
                      icon: HopeV2Icons.home,
                      primary: true,
                    ),
                  ],
                ),
                PremiumDomainMarker(domain: HopeProductDomain.work),
                PremiumDomainNavigationGroup(
                  domain: HopeProductDomain.work,
                  children: const [SizedBox.shrink()],
                ),
              ],
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(PremiumQuickActionStrip));
      expect(
        tester.widget<Text>(find.text('Work center')).style?.color,
        HopeV2SemanticColors.textPrimary(context),
      );
      final workshopLabels =
          tester.widgetList<Text>(find.text('Workshop')).toList();
      expect(workshopLabels, hasLength(2));
      expect(
        workshopLabels.first.style?.color,
        HopeV2SemanticColors.textSecondary(context),
      );
      expect(
        workshopLabels.last.style?.color,
        HopeV2SemanticColors.textPrimary(context),
      );
    }
  });

  testWidgets('HopeIconTile renders canonical Cupertino action tokens',
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

    expect(find.byIcon(HopeV2Icons.search), findsOneWidget);
  });
  testWidgets('status and empty-state primitives accept canonical Cupertino icons',
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

    expect(find.byType(Icon), findsWidgets);
  });


  test('money and information text roles are separate from indigo actions', () {
    expect(HopeV2Colors.moneyTextLight, HopeV2Colors.ink);
    expect(HopeV2Colors.moneyTextDark, HopeV2Colors.darkText);
    expect(HopeV2Colors.infoTextLight, HopeV2TonalPalettes.info.shade(800));
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
      HopeV2Colors.trustTextLight,
      HopeV2Colors.trustTextDark,
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
      HopeV2Colors.trustSurfaceLight,
    ];
    final darkSurfaces = [
      HopeV2Colors.darkBackground,
      HopeV2Colors.darkSurface,
      HopeV2Colors.darkCard,
      HopeV2Colors.panelDark,
      HopeV2Colors.panelSoftDark,
      HopeV2Colors.inputDark,
      HopeV2Colors.trustSurfaceDark,
    ];
    for (final surface in lightSurfaces) {
      expect(_contrastRatio(HopeV2Colors.moneyTextLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.infoTextLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.successOnLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.warningOnLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.dangerOnLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.trustTextLight, surface), greaterThanOrEqualTo(4.5));
    }
    for (final surface in darkSurfaces) {
      expect(_contrastRatio(HopeV2Colors.moneyTextDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.infoTextDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.successDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.warningDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.dangerDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.trustTextDark, surface), greaterThanOrEqualTo(4.5));
    }
  });

  test('HOPE color genome provides indigo, forest, lichen and semantic 50–950 tonal scales', () {
    const expectedSteps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];
    final palettes = <HopeV2TonalPalette>[
      HopeV2TonalPalettes.indigo,
      HopeV2TonalPalettes.forest,
      HopeV2TonalPalettes.lichen,
      HopeV2TonalPalettes.neutral,
      HopeV2TonalPalettes.info,
      HopeV2TonalPalettes.trust,
      HopeV2TonalPalettes.success,
      HopeV2TonalPalettes.warning,
      HopeV2TonalPalettes.featured,
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
        Color(0xFFF0F5EE), Color(0xFFDDE9D8), Color(0xFFC0D7B8),
        Color(0xFF9FBF91), Color(0xFF789F6B), Color(0xFF557D4D),
        Color(0xFF3E673F), Color(0xFF31583C), Color(0xFF244D38),
        Color(0xFF193A2A), Color(0xFF0E2419),
      ],
      [
        Color(0xFFF7FAE9), Color(0xFFEEF5D0), Color(0xFFDCEBA8),
        Color(0xFFCCE477), Color(0xFFB8D86C), Color(0xFF9FBF67),
        Color(0xFF88A96A), Color(0xFF6F9659), Color(0xFF4E713F),
        Color(0xFF354D2B), Color(0xFF1C2A18),
      ],
      [
        Color(0xFFFAF9F4), Color(0xFFF2F0E8), Color(0xFFE9E5D9),
        Color(0xFFD6D1C4), Color(0xFFB4AE9E), Color(0xFF8B8779),
        Color(0xFF5B665A), Color(0xFF4A574A), Color(0xFF344238),
        Color(0xFF18221C), Color(0xFF12140F),
      ],
      [
        Color(0xFFE6FFFB), Color(0xFFCCFBF1), Color(0xFF99F6E4),
        Color(0xFF5EEAD4), Color(0xFF2DD4BF), Color(0xFF14B8A6),
        Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF115E59),
        Color(0xFF134E4A), Color(0xFF042F2E),
      ],
      [
        Color(0xFFEFF6FF), Color(0xFFDBEAFE), Color(0xFFBFDBFE),
        Color(0xFF93C5FD), Color(0xFF60A5FA), Color(0xFF3B82F6),
        Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF),
        Color(0xFF1E3A8A), Color(0xFF172554),
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
        Color(0xFFFFF7ED), Color(0xFFFFEDD5), Color(0xFFFDBA74),
        Color(0xFFFF9A4D), Color(0xFFFB923C), Color(0xFFF97316),
        Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFF9A3412),
        Color(0xFF7C2D12), Color(0xFF431407),
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
    expect(HopeV2TonalPalettes.indigo.shade(500), HopeV2Colors.primary);
    expect(HopeV2TonalPalettes.indigo.shade(600), HopeV2Colors.primaryAction);
    expect(HopeV2TonalPalettes.indigo.shade(400), HopeV2Colors.primaryDark);
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
          'price': HopeV2SemanticColors.price(context),
          'priceLabel': HopeV2SemanticColors.priceLabel(context),
          'trust': HopeV2SemanticColors.trust(context),
          'secure': HopeV2SemanticColors.secure(context),
          'link': HopeV2SemanticColors.link(context),
          'pendingAmount': HopeV2SemanticColors.pendingAmount(context),
          'negativeAmount': HopeV2SemanticColors.negativeAmount(context),
          'trustSurface': HopeV2SemanticColors.statusSurface(
            context, HopeV2Colors.trustTextLight),
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
          'price': HopeV2SemanticColors.price(context),
          'priceLabel': HopeV2SemanticColors.priceLabel(context),
          'trust': HopeV2SemanticColors.trust(context),
          'secure': HopeV2SemanticColors.secure(context),
          'link': HopeV2SemanticColors.link(context),
          'pendingAmount': HopeV2SemanticColors.pendingAmount(context),
          'negativeAmount': HopeV2SemanticColors.negativeAmount(context),
          'trustSurface': HopeV2SemanticColors.statusSurface(
            context, HopeV2Colors.trustTextDark),
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
    expect(light['price'], light['amount']);
    expect(dark['price'], dark['amount']);
    expect(light['priceLabel'], HopeV2Colors.muted);
    expect(dark['priceLabel'], HopeV2Colors.darkMuted);
    expect(light['trust'], HopeV2Colors.trustTextLight);
    expect(dark['trust'], HopeV2Colors.trustTextDark);
    expect(light['secure'], light['trust']);
    expect(dark['secure'], dark['trust']);
    expect(light['link'], HopeV2Colors.infoTextLight);
    expect(dark['link'], HopeV2Colors.infoTextDark);
    expect(light['pendingAmount'], HopeV2Colors.warningOnLight);
    expect(dark['pendingAmount'], HopeV2Colors.warningDark);
    expect(light['negativeAmount'], AppTheme.light().colorScheme.error);
    expect(dark['negativeAmount'], AppTheme.dark().colorScheme.error);
    expect(light['trustSurface'], HopeV2Colors.trustSurfaceLight);
    expect(dark['trustSurface'], HopeV2Colors.trustSurfaceDark);
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
      HopeV2Colors.trustSurfaceLight,
    ];
    final darkTextSurfaces = [
      HopeV2Colors.darkBackground,
      HopeV2Colors.darkSurface,
      HopeV2Colors.darkCard,
      HopeV2Colors.panelDark,
      HopeV2Colors.panelSoftDark,
      HopeV2Colors.accentSurfaceDark,
      HopeV2Colors.trustSurfaceDark,
    ];
    for (final surface in lightTextSurfaces) {
      expect(_contrastRatio(HopeV2Colors.accentTextLight, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.trustTextLight, surface), greaterThanOrEqualTo(4.5));
    }
    for (final surface in darkTextSurfaces) {
      expect(_contrastRatio(HopeV2Colors.accentTextDark, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(HopeV2Colors.trustTextDark, surface), greaterThanOrEqualTo(4.5));
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

  test('HOPE tonal ramps darken consistently and stay aligned with legacy tokens', () {
    final ramps = <String, HopeV2TonalPalette>{
      'brand': HopeV2TonalPalettes.brand,
      'neutral': HopeV2TonalPalettes.neutral,
      'info': HopeV2TonalPalettes.info,
      'success': HopeV2TonalPalettes.success,
      'warning': HopeV2TonalPalettes.warning,
      'featured': HopeV2TonalPalettes.featured,
      'danger': HopeV2TonalPalettes.danger,
    };

    for (final entry in ramps.entries) {
      final tones = entry.value.values;
      for (var i = 1; i < tones.length; i++) {
        expect(
          tones[i].computeLuminance(),
          lessThan(tones[i - 1].computeLuminance()),
          reason: '${entry.key} shade ${HopeV2TonalPalette.steps[i]} must be darker than shade ${HopeV2TonalPalette.steps[i - 1]}.',
        );
      }
    }

    // These compatibility tokens are still consumed by existing screens.
    // Keep them synchronized with the canonical ramps during migration.
    expect(HopeV2Colors.primary, HopeV2TonalPalettes.indigo.shade500);
    expect(HopeV2Colors.primaryDark, HopeV2TonalPalettes.indigo.shade400);
    expect(HopeV2Colors.primaryAction, HopeV2TonalPalettes.indigo.shade600);
    expect(HopeV2Colors.primaryActionHoverLight, HopeV2TonalPalettes.indigo.shade700);
    expect(HopeV2Colors.primaryActionPressedLight, HopeV2TonalPalettes.indigo.shade800);
    expect(HopeV2Colors.primaryTintLight, HopeV2TonalPalettes.indigo.shade100);
    expect(HopeV2Colors.primaryBorderLight, HopeV2TonalPalettes.indigo.shade300);
    expect(HopeV2Colors.ink, HopeV2TonalPalettes.neutral.shade900);
    expect(HopeV2Colors.muted, HopeV2TonalPalettes.neutral.shade600);
    expect(HopeV2Colors.orange, HopeV2TonalPalettes.featured.shade500);
    expect(HopeV2Colors.orangeDark, HopeV2TonalPalettes.featured.shade300);
    expect(HopeV2Colors.accentTextLight, HopeV2TonalPalettes.featured.shade800);
    expect(HopeV2Colors.accentTextDark, HopeV2TonalPalettes.featured.shade200);
    expect(HopeV2Colors.inkSoft, HopeV2TonalPalettes.neutral.shade800);
    expect(HopeV2Colors.secondary, HopeV2TonalPalettes.info.shade500);
    expect(HopeV2Colors.secondaryStrong, HopeV2TonalPalettes.info.shade600);
    expect(HopeV2Colors.secondaryDark, HopeV2TonalPalettes.info.shade300);
    expect(HopeV2Colors.secondaryAction, HopeV2TonalPalettes.info.shade700);
    expect(HopeV2Colors.warningOnLight, HopeV2TonalPalettes.warning.shade800);
    expect(HopeV2Colors.dangerOnLight, HopeV2TonalPalettes.danger.shade700);
  });


  testWidgets(
    'highlighted dark panels use indigo treatment over canonical navy surfaces',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: PremiumPanel(
              highlight: true,
              child: Text('Highlighted panel'),
            ),
          ),
        ),
      );

      final panel = tester.widget<Container>(
        find.descendant(
          of: find.byType(PremiumPanel),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = panel.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;

      expect(
        gradient.colors.first,
        HopeV2Colors.primary.withValues(alpha: .075),
      );
      expect(
        gradient.colors[1],
        HopeV2Colors.primary.withValues(alpha: .018),
      );
      expect(gradient.colors[2], const Color(0xFF101522));
      expect(
        decoration.boxShadow!.last.color,
        HopeV2Colors.primary.withValues(alpha: .025),
      );
      expect(tester.takeException(), isNull);
    },
  );


  test('icon accents distribute the HOPE multi-accent genome by product role', () {
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.wallet, brightness: Brightness.light),
      HopeV2TonalPalettes.forest.shade700,
    );
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.wallet, brightness: Brightness.dark),
      HopeV2TonalPalettes.forest.shade300,
    );
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.message, brightness: Brightness.light),
      HopeV2TonalPalettes.info.shade700,
    );
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.profile, brightness: Brightness.dark),
      HopeV2TonalPalettes.trust.shade300,
    );
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.featured, brightness: Brightness.light),
      HopeV2TonalPalettes.featured.shade700,
    );
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.pending, brightness: Brightness.dark),
      HopeV2TonalPalettes.warning.shade200,
    );
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.error, brightness: Brightness.light),
      HopeV2TonalPalettes.danger.shade700,
    );
    expect(
      HopeV2IconAccents.resolve(HopeV2Icons.home, brightness: Brightness.light),
      HopeV2Colors.primaryAction,
    );
  });

  testWidgets('default icon tiles render green, teal, clay and trust accents by role',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              HopeIconTile(HopeV2Icons.wallet),
              HopeIconTile(HopeV2Icons.message),
              HopeIconTile(HopeV2Icons.featured),
              HopeIconTile(HopeV2Icons.profile),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(HopeV2Icons.wallet)).color,
      HopeV2TonalPalettes.forest.shade300,
    );
    expect(
      tester.widget<Icon>(find.byIcon(HopeV2Icons.message)).color,
      HopeV2TonalPalettes.info.shade300,
    );
    expect(
      tester.widget<Icon>(find.byIcon(HopeV2Icons.featured)).color,
      HopeV2TonalPalettes.featured.shade300,
    );
    expect(
      tester.widget<Icon>(find.byIcon(HopeV2Icons.profile)).color,
      HopeV2TonalPalettes.trust.shade300,
    );
    expect(tester.takeException(), isNull);
  });

}
