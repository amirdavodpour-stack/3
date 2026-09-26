import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// HOPE V2 design primitives.
///
/// This is intentionally token-first: screens should consume these values
/// instead of inventing per-page spacing, radii, or breakpoints.

/// Canonical HOPE visual tokens. Legacy theme APIs alias these values so
/// existing screens can migrate without creating a second design system.
class HopeV2Colors {
  const HopeV2Colors._();

  static const primary = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF818CF8);
  static const secondary = Color(0xFF10B981);
  static const secondaryStrong = Color(0xFF059669);
  static const secondaryDark = Color(0xFF34D399);
  static const accent = Color(0xFFF59E0B);
  /// Focus accent for featured/recommended work surfaces; use sparingly.
  static const orange = Color(0xFFF97316);
  static const orangeDark = Color(0xFFFF9A4D);
  static const inkSoft = Color(0xFF26223A);
  static const backgroundWarm = Color(0xFFF4F0FB);
  static const ink = Color(0xFF151326);
  static const muted = Color(0xFF6B6780);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF0ECF8);
  // Match the canonical reference semantic green used for trust/success.
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF34D8C8);
  static const warning = Color(0xFFF59E0B);
  static const warningDark = Color(0xFFFBBF24);
  static const danger = Color(0xFFEF4444);
  static const dangerDark = Color(0xFFF87171);
  static const softPrimary = Color(0xFFE0E7FF);
  static const darkBackground = Color(0xFF070A12);
  static const darkSurface = Color(0xFF0F111A);
  static const darkCard = Color(0xFF111827);
  static const darkText = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFFA5ADBD);

  static const pageLight = Color(0xFFF1EDF8);
  static const pageDark = Color(0xFF070A12);
  static const panelLight = Color(0xFFFFFFFF);
  static const panelDark = Color(0xFF0F111A);
  static const panelSoftLight = Color(0xFFFBF9FE);
  static const panelSoftDark = Color(0xFF121726);
  static const chipLight = Color(0xFFEFEBF8);
  static const chipDark = Color(0x1AFFFFFF);
  static const chipSelectedDark = Color(0x336366F1);
  static const disabledLight = Color(0xFFE8E3F0);
  static const borderControlLight = Color(0xFFDED9E8);
  static const dividerLight = Color(0xFFE4E0EA);
  static const outlinedButtonBorderLight = Color(0xFFDAD4E5);
  static const navigationLight = Color(0xFFF7F4FC);
  static const navigationDark = Color(0xF7090D17);
  static const navigationIndicatorLight = Color(0xFFE5DFFF);
  static const navigationIndicatorDark = Color(0x3A6366F1);
  static const inputDark = Color(0xFF0D1320);
  static const darkBorder = Color(0x1AFFFFFF);
  static const darkBorderStrong = Color(0x2DFFFFFF);
  static const darkDivider = Color(0x16FFFFFF);
  static const cardBorderLight = Color(0xFFE5E0EF);
  /// Light warm-brown accent used only as a restrained atmospheric underlay.
  static const warmHalo = Color(0xFFC2A487);
  static const warmHaloDark = Color(0xFF826D59);
}

/// Canonical icon vocabulary. Keep navigation and recurring product concepts
/// on this set so the interface reads as one designed system rather than a
/// collection of unrelated Material defaults.
class HopeV2Icons {
  const HopeV2Icons._();

  // HOPE's product icon language is Hugeicons Stroke Rounded. The package
  // provides 6,000+ consistent SVG icons with controlled stroke weight.
  // Keep recurring concepts here so screens never pick arbitrary glyphs.
  static const home = HugeIcons.strokeRoundedHome01;
  static const homeSelected = HugeIcons.strokeRoundedHome02;
  static const workshop = HugeIcons.strokeRoundedBriefcase01;
  static const workshopSelected = HugeIcons.strokeRoundedBriefcase02;
  static const activity = HugeIcons.strokeRoundedActivity01;
  static const activitySelected = HugeIcons.strokeRoundedActivity02;
  static const wallet = HugeIcons.strokeRoundedWallet01;
  static const walletSelected = HugeIcons.strokeRoundedWallet02;
  static const profile = HugeIcons.strokeRoundedUser;
  static const profileSelected = HugeIcons.strokeRoundedUserAccount;

  static const mission = HugeIcons.strokeRoundedFlash;
  static const job = HugeIcons.strokeRoundedWorkHistory;
  static const featured = HugeIcons.strokeRoundedSparkles;
  static const match = HugeIcons.strokeRoundedUserCheck01;
  static const location = HugeIcons.strokeRoundedLocation01;
  static const category = HugeIcons.strokeRoundedTag01;
  static const distance = HugeIcons.strokeRoundedLocationUser01;
  static const protectedFunds = HugeIcons.strokeRoundedShield01;
  static const payments = HugeIcons.strokeRoundedMoney01;
  static const transferIn = HugeIcons.strokeRoundedMoneyReceive01;
  static const transferOut = HugeIcons.strokeRoundedMoneySend01;
  static const completed = HugeIcons.strokeRoundedTaskDone01;
  static const pending = HugeIcons.strokeRoundedHourglass;
  static const secure = HugeIcons.strokeRoundedLock;
  static const insights = HugeIcons.strokeRoundedActivitySpark;
  static const savedSearches = HugeIcons.strokeRoundedBookmark01;
  static const mail = HugeIcons.strokeRoundedMail01;
  static const view = HugeIcons.strokeRoundedView;
  static const viewOff = HugeIcons.strokeRoundedViewOff;
  static const password = HugeIcons.strokeRoundedLockPassword;
  static const copy = HugeIcons.strokeRoundedCopy01;
  static const verified = HugeIcons.strokeRoundedCheckmarkBadge02;
  static const error = HugeIcons.strokeRoundedCancelCircle;
  static const description = HugeIcons.strokeRoundedFile01;
  static const skills = HugeIcons.strokeRoundedBrain02;
  static const message = HugeIcons.strokeRoundedMessage01;
  static const route = HugeIcons.strokeRoundedRoute01;
  static const android = HugeIcons.strokeRoundedAndroid;
  static const apple = HugeIcons.strokeRoundedApple;
  static const web = HugeIcons.strokeRoundedGlobe;
  static const device = HugeIcons.strokeRoundedDeviceAccess;
  static const add = HugeIcons.strokeRoundedAdd01;
  static const menu = HugeIcons.strokeRoundedMenu01;
  static const refresh = HugeIcons.strokeRoundedRefresh;
  static const search = HugeIcons.strokeRoundedSearch01;
  static const filter = HugeIcons.strokeRoundedFilter;
  static const close = HugeIcons.strokeRoundedCancel01;
  static const notifications = HugeIcons.strokeRoundedNotification01;
  static const translate = HugeIcons.strokeRoundedLanguageCircle;
  static const userAdd = HugeIcons.strokeRoundedUserAdd01;
  static const login = HugeIcons.strokeRoundedLogin01;
  static const arrowLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const arrowRight = HugeIcons.strokeRoundedArrowRight01;
}

class HopeV2Spacing {
  const HopeV2Spacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 32.0;
  static const display = 48.0;
}

class HopeV2Radii {
  const HopeV2Radii._();
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 18.0;
  static const xl = 24.0;
  static const hero = 28.0;
  static const input = 14.0;
  static const button = 14.0;
  static const navigation = 14.0;
  static const chip = 12.0;
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

  static const barHeight = 72.0;
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

  static Gradient pageHalo(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Avoid visible radial contour rings on Android. The reference uses
    // a nearly-black canvas with only a controlled atmospheric tint.
    return LinearGradient(
      begin: AlignmentDirectional.topEnd,
      end: AlignmentDirectional.bottomStart,
      colors: [
        dark
            ? HopeV2Colors.primary.withValues(alpha: .035)
            : HopeV2Colors.warmHalo.withValues(alpha: .045),
        dark
            ? HopeV2Colors.secondary.withValues(alpha: .012)
            : HopeV2Colors.warmHalo.withValues(alpha: .015),
        Colors.transparent,
      ],
      stops: const [0.0, 0.34, 1.0],
    );
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
    return dark ? HopeV2Colors.darkBorder : HopeV2Colors.cardBorderLight;
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
        : HopeV2Colors.navigationIndicatorLight;
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
      Color(0xFF2B225F),
      Color(0xFF4236A8),
      Color(0xFF0A5160),
      Color(0xFF0B1020),
    ],
    stops: [0, .36, .72, 1],
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

  static const heroDark = [
    BoxShadow(
      color: Color(0x552E2A72),
      blurRadius: 34,
      offset: Offset(0, 18),
    ),
    BoxShadow(
      color: Color(0x3310B981),
      blurRadius: 48,
      offset: Offset(-10, 20),
    ),
  ];

  static const gradientHero = [
    BoxShadow(
      color: Color(0x4A6366F1),
      blurRadius: 34,
      offset: Offset(0, 16),
    ),
  ];
}

class HopeV2Typography {
  const HopeV2Typography._();

  /// Single source of truth for the app-wide UI type family. The value stays
  /// on the legally bundled font until a replacement asset is explicitly
  /// licensed and added to the repository.
  static const primaryFontFamily = 'Vazirmatn';
  static const fontFamilyFallback = <String>['Roboto'];
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

  static TextStyle metric(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -.45,
        height: 1.0,
      );

  static TextStyle section(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(fontSize: 20, letterSpacing: -.25);

  static TextStyle eyebrow(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge!
      .copyWith(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8);
}