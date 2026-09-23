import 'package:flutter/material.dart';

/// HOPE V2 design primitives.
///
/// This is intentionally token-first: screens should consume these values
/// instead of inventing per-page spacing, radii, or breakpoints.

/// Canonical HOPE visual tokens. Legacy theme APIs alias these values so
/// existing screens can migrate without creating a second design system.
class HopeV2Colors {
  const HopeV2Colors._();

  static const primary = Color(0xFF6C4DFF);
  static const primaryDark = Color(0xFFB3A2FF);
  static const secondary = Color(0xFF22B8A7);
  static const secondaryStrong = Color(0xFF0C7D70);
  static const secondaryDark = Color(0xFF3AC3B1);
  static const accent = Color(0xFFFFB45C);
  static const inkSoft = Color(0xFF26223A);
  static const backgroundWarm = Color(0xFFF8F7FC);
  static const ink = Color(0xFF151326);
  static const muted = Color(0xFF6B6780);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF6F5FC);
  static const success = Color(0xFF0B7A58);
  static const successDark = Color(0xFF4CD4A3);
  static const warning = Color(0xFF8F5C0E);
  static const warningDark = Color(0xFFFFD54F);
  static const danger = Color(0xFFBA454D);
  static const dangerDark = Color(0xFFFF8A80);
  static const softPrimary = Color(0xFFEAE5FF);
  static const darkBackground = Color(0xFF0C0A12);
  static const darkSurface = Color(0xFF15131D);
  static const darkCard = Color(0xFF1C1925);
  static const darkText = Color(0xFFF8F7FC);
  static const darkMuted = Color(0xFFAAA6B8);

  static const pageLight = Color(0xFFF7F7FB);
  static const pageDark = Color(0xFF090811);
  static const panelLight = Color(0xFFFFFFFF);
  static const panelDark = Color(0xFF15131D);
  static const panelSoftLight = Color(0xFFFCFBFF);
  static const panelSoftDark = Color(0xFF1C1926);
  static const chipLight = Color(0xFFF1EFF7);
  static const chipDark = Color(0x1AFFFFFF);
  static const chipSelectedDark = Color(0x337660FF);
  static const disabledLight = Color(0xFFEAE7F0);
  static const borderControlLight = Color(0xFFE6E2F0);
  static const dividerLight = Color(0xFFE8E5F0);
  static const outlinedButtonBorderLight = Color(0xFFDED9EA);
  static const navigationLight = Color(0xFDFEFEFF);
  static const navigationDark = Color(0xF714121B);
  static const navigationIndicatorDark = Color(0x4D7660FF);
  static const inputDark = Color(0xFF201D28);
  static const darkBorder = Color(0x14FFFFFF);
  static const darkBorderStrong = Color(0x24FFFFFF);
  static const darkDivider = Color(0x12FFFFFF);
}

class HopeV2Spacing {
  const HopeV2Spacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 40.0;
  static const display = 56.0;
}

class HopeV2Radii {
  const HopeV2Radii._();
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const hero = 32.0;
  static const input = 18.0;
  static const button = 16.0;
  static const navigation = 16.0;
  static const chip = 14.0;
  static const iconTile = 18.0;
  static const fab = 19.0;
  static const pill = 999.0;
}

class HopeV2Breakpoints {
  const HopeV2Breakpoints._();
  static const compact = 600.0;
  static const medium = 900.0;
  static const expanded = 1200.0;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) => width(context) < compact;

  static bool isMedium(BuildContext context) =>
      width(context) >= compact && width(context) < medium;

  static bool isExpanded(BuildContext context) => width(context) >= medium;

  static bool isWide(BuildContext context) => width(context) >= expanded;
}

class HopeV2Motion {
  const HopeV2Motion._();
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const emphasis = Duration(milliseconds: 360);
}

class HopeV2Touch {
  const HopeV2Touch._();
  static const minimum = 48.0;
}

class HopeV2Navigation {
  const HopeV2Navigation._();

  static const barHeight = 80.0;
  static const railMinWidth = 88.0;
  static const railExtendedWidth = 210.0;
}

class HopeV2Layer {
  const HopeV2Layer._();
  static const base = 0;
  static const navigation = 20;
  static const modal = 40;
  static const toast = 60;
}

class HopeV2Surfaces {
  const HopeV2Surfaces._();

  static Color page(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.pageDark : HopeV2Colors.pageLight;
  }

  static Color panel(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.panelDark : HopeV2Colors.panelLight;
  }

  static Color panelSoft(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.panelSoftDark : HopeV2Colors.panelSoftLight;
  }

  static Color border(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.darkBorder : const Color(0xFFE5E2EC);
  }

  static Color chip(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.chipDark : HopeV2Colors.chipLight;
  }

  static Color input(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.inputDark : HopeV2Colors.panelSoftLight;
  }

  static Color divider(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.darkDivider : HopeV2Colors.dividerLight;
  }

  static Color controlBorder(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.darkBorderStrong : HopeV2Colors.borderControlLight;
  }

  static Color navigation(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.navigationDark : HopeV2Colors.navigationLight;
  }

  static Color navigationIndicator(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? HopeV2Colors.navigationIndicatorDark
        : HopeV2Colors.softPrimary;
  }

  static Color outlinedButtonBorder(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? HopeV2Colors.darkBorder : HopeV2Colors.outlinedButtonBorderLight;
  }
}


/// Semantic color roles used by product states. These intentionally resolve
/// through ThemeData so light/dark modes retain the same meaning.
class HopeV2Gradients {
  const HopeV2Gradients._();

  static const hero = LinearGradient(
    colors: [
      Color(0xFF5D43E8),
      Color(0xFF8B73FF),
      Color(0xFFB09FFF),
    ],
    stops: [0, .55, 1],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const heroDark = LinearGradient(
    colors: [
      Color(0xFF2D1C67),
      Color(0xFF145A55),
      Color(0xFF101225),
    ],
    stops: [0, .55, 1],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

class HopeV2SemanticColors {
  const HopeV2SemanticColors._();

  static Color primary(BuildContext context) => Theme.of(context).colorScheme.primary;
  static Color secondary(BuildContext context) => Theme.of(context).colorScheme.secondary;
  static Color surface(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color elevated(BuildContext context) => HopeV2Surfaces.panel(context);
  static Color background(BuildContext context) => HopeV2Surfaces.page(context);
  static Color border(BuildContext context) => HopeV2Surfaces.border(context);
  static Color textPrimary(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color textSecondary(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
  static Color success(BuildContext context) => Theme.of(context).colorScheme.tertiary;
  static Color warning(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? HopeV2Colors.warningDark
          : HopeV2Colors.warning;
  static Color error(BuildContext context) => Theme.of(context).colorScheme.error;
  static Color info(BuildContext context) => Theme.of(context).colorScheme.primary;
}

class HopeV2Shadows {
  const HopeV2Shadows._();

  static const card = [
    BoxShadow(
      color: Color(0x0D1B1638),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  static const hero = [
    BoxShadow(
      color: Color(0x241C1738),
      blurRadius: 36,
      offset: Offset(0, 18),
    ),
  ];

  static const gradientHero = [
    BoxShadow(
      color: Color(0x2B6C4DFF),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];
}

class HopeV2Type {
  const HopeV2Type._();

  static TextStyle display(BuildContext context) => Theme.of(context)
      .textTheme
      .displaySmall!
      .copyWith(fontSize: 34, letterSpacing: -.85, height: 1.06);

  static TextStyle hero(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineMedium!
      .copyWith(fontSize: 31, letterSpacing: -.75, height: 1.05);

  static TextStyle section(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(fontSize: 20, letterSpacing: -.25);

  static TextStyle eyebrow(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge!
      .copyWith(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8);
}