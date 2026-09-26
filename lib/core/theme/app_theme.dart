import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'hope_v2_design.dart';

class AppColors {
  // Compatibility facade. New UI code should consume HopeV2Colors directly.
  const AppColors._();

  static const primary = HopeV2Colors.primary;
  static const primaryDark = HopeV2Colors.primaryDark;
  static const secondary = HopeV2Colors.secondary;
  static const secondaryStrong = HopeV2Colors.secondaryStrong;
  static const secondaryDark = HopeV2Colors.secondaryDark;
  static const accent = HopeV2Colors.accent;
  static const inkSoft = HopeV2Colors.inkSoft;
  static const backgroundWarm = HopeV2Colors.backgroundWarm;
  static const ink = HopeV2Colors.ink;
  static const muted = HopeV2Colors.muted;
  static const surface = HopeV2Colors.surface;
  static const background = HopeV2Colors.background;
  static const success = HopeV2Colors.success;
  static const successDark = HopeV2Colors.successDark;
  static const warning = HopeV2Colors.warning;
  static const warningDark = HopeV2Colors.warningDark;
  static const danger = HopeV2Colors.danger;
  static const dangerDark = HopeV2Colors.dangerDark;
  static const softPrimary = HopeV2Colors.softPrimary;
  static const darkBackground = HopeV2Colors.darkBackground;
  static const darkSurface = HopeV2Colors.darkSurface;
  static const darkCard = HopeV2Colors.darkCard;
  static const darkText = HopeV2Colors.darkText;
  static const darkMuted = HopeV2Colors.darkMuted;
}
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: dark ? AppColors.secondaryDark : AppColors.secondary,
      onSecondary: Colors.white,
      surface: dark ? AppColors.darkSurface : AppColors.surface,
      onSurface: dark ? AppColors.darkText : AppColors.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: HopeV2Typography.primaryFontFamily,
      fontFamilyFallback: HopeV2Typography.fontFamilyFallback,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? AppColors.darkBackground : AppColors.backgroundWarm,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      focusColor: (dark ? AppColors.primaryDark : AppColors.primary)
          .withValues(alpha: .14),
      hoverColor: (dark ? AppColors.primaryDark : AppColors.primary)
          .withValues(alpha: .08),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      }),
    );

    final textColor = dark ? AppColors.darkText : AppColors.ink;
    final mutedColor = dark ? AppColors.darkMuted : AppColors.muted;

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textColor,
        centerTitle: false,
        toolbarHeight: 58,
        titleSpacing: 16,
        iconTheme: IconThemeData(color: textColor, size: 23),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: -.3,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: dark ? AppColors.primaryDark.withValues(alpha: .16) : AppColors.softPrimary,
          borderRadius: BorderRadius.circular(HopeV2Radii.chip),
        ),
        labelColor: scheme.primary,
        unselectedLabelColor: mutedColor,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? HopeV2Colors.chipDark : HopeV2Colors.chipLight,
        selectedColor: dark ? HopeV2Colors.chipSelectedDark : AppColors.softPrimary,
        disabledColor: dark ? const Color(0x1AFFFFFF) : HopeV2Colors.disabledLight,
        side: BorderSide(
          color: dark ? HopeV2Colors.darkBorderStrong : HopeV2Colors.borderControlLight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HopeV2Radii.chip),
        ),
        labelStyle: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        secondaryLabelStyle: TextStyle(
          color: mutedColor,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HopeV2Radii.xl),
        ),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
        contentTextStyle: TextStyle(
          color: mutedColor,
          fontSize: 14,
          height: 1.55,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? AppColors.darkSurface : AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(HopeV2Radii.xl),
          ),
        ),
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? AppColors.darkCard : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HopeV2Radii.lg)),
      ),
      dividerTheme: DividerThemeData(
          color: dark ? HopeV2Colors.darkDivider : HopeV2Colors.dividerLight, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? HopeV2Colors.inputDark : HopeV2Colors.panelSoftLight,
        hintStyle: TextStyle(color: mutedColor),
        labelStyle: TextStyle(color: mutedColor, fontWeight: FontWeight.w700),
        prefixIconColor: mutedColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: HopeV2Spacing.lg, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HopeV2Radii.input),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HopeV2Radii.input),
            borderSide: BorderSide(
                color: dark ? HopeV2Colors.darkBorderStrong : HopeV2Colors.borderControlLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HopeV2Radii.input),
            borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HopeV2Radii.input),
            borderSide: const BorderSide(color: AppColors.danger)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: HopeV2Spacing.lg),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(HopeV2Radii.button)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(
              color: dark ? HopeV2Colors.darkBorder : HopeV2Colors.outlinedButtonBorderLight),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(HopeV2Radii.button)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded)),
      navigationBarTheme: NavigationBarThemeData(
        height: HopeV2Navigation.barHeight,
        backgroundColor: dark ? HopeV2Colors.navigationDark : HopeV2Colors.navigationLight,
        surfaceTintColor: Colors.transparent,
        indicatorColor: dark ? HopeV2Colors.navigationIndicatorDark : HopeV2Colors.navigationIndicatorLight,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HopeV2Radii.navigation),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : mutedColor,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : mutedColor,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? HopeV2Colors.navigationDark : HopeV2Colors.navigationLight,
        indicatorColor: dark ? HopeV2Colors.navigationIndicatorDark : HopeV2Colors.navigationIndicatorLight,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HopeV2Radii.navigation),
        ),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme: IconThemeData(color: mutedColor, size: 23),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: mutedColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: dark ? AppColors.darkBackground : Colors.white,
        elevation: 7,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HopeV2Radii.fab)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkCard : AppColors.ink,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HopeV2Radii.md)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      textTheme: TextTheme(
        displaySmall: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w900,
            height: 1.08,
            letterSpacing: -.65,
            color: textColor),
        headlineMedium: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
            color: textColor),
        headlineSmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.08,
            letterSpacing: -.45,
            color: textColor),
        titleLarge: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -.2,
            color: textColor),
        titleMedium: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
        bodyLarge: TextStyle(fontSize: 15, height: 1.65, color: textColor),
        bodyMedium: TextStyle(fontSize: 13, height: 1.58, color: mutedColor),
        labelLarge: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800, height: 1.25),
      ),
    );
  }
}