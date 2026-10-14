import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// HOPE V2 design primitives.
///
/// This is intentionally token-first: screens should consume these values
/// instead of inventing per-page spacing, radii, or breakpoints.

/// Canonical HOPE contract: near-black navy/charcoal surfaces, indigo-led actions, and a very restrained forest-green accent.
/// Runtime certification batch: compact home, deterministic glass, restrained bloom.
/// Certification round three: opaque premium surfaces + controlled wallet hero.
/// Final visual checkpoint: wallet/profile bloom removed; home remains compact.
/// Canonical HOPE visual tokens. Legacy theme APIs alias these values so
/// existing screens can migrate without creating a second design system.
class HopeV2Colors {
  const HopeV2Colors._();

  static const primary = Color(0xFF6366F1);
  static const primaryAction = Color(0xFF6366F1);
  static const primaryOnLight = Color(0xFF4F46E5);
  static const successOnLight = Color(0xFF236443);
  static const warningOnLight = Color(0xFF92400E);
  static const dangerOnLight = Color(0xFFB91C1C);
  static const secondaryAction = Color(0xFF0F766E);

  static const primaryDark = Color(0xFF818CF8);
  static const secondary = Color(0xFF14B8A6);
  static const secondaryStrong = Color(0xFF0D9488);
  static const secondaryDark = Color(0xFF5EEAD4);
  static const accent = Color(0xFFF59E0B);
  /// Focus accent for featured/recommended work surfaces; use sparingly.
  static const orange = Color(0xFFF97316);
  static const orangeDark = Color(0xFFFF9A4D);
  static const inkSoft = Color(0xFF34372D);
  static const backgroundWarm = Color(0xFFF5F3EA);
  static const ink = Color(0xFF24271F);
  static const muted = Color(0xFF66675B);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFEFECE3);
  // Match the canonical reference semantic green used for trust/success.
  static const success = Color(0xFF27764C);
  static const successDark = Color(0xFF89BD95);
  static const warning = Color(0xFFB78635);
  static const warningDark = Color(0xFFD5B56C);
  static const danger = Color(0xFFC14B43);
  static const dangerDark = Color(0xFFDC766F);
  static const softPrimary = Color(0xFFE8E0CD);
  static const darkBackground = Color(0xFF070A12);
  static const darkSurface = Color(0xFF0F111A);
  static const darkCard = Color(0xFF111827);
  static const darkText = Color(0xFFF1F3EC);
  static const darkMuted = Color(0xFFAEB7AC);

  static const pageLight = Color(0xFFF2F0E8);
  static const pageDark = Color(0xFF070A12);
  static const panelLight = Color(0xFFFFFFFF);
  static const panelDark = Color(0xFF101522);
  static const panelSoftLight = Color(0xFFFAF9F4);
  static const panelSoftDark = Color(0xFF121726);
  static const chipLight = Color(0xFFEEECE2);
  static const chipDark = Color(0x20FFFFFF);
  static const chipSelectedDark = Color(0x2B6366F1);
  static const disabledLight = Color(0xFFE5E2D9);
  static const borderControlLight = Color(0xFFD8D4C8);
  static const dividerLight = Color(0xFFE6E2D9);
  static const outlinedButtonBorderLight = Color(0xFFD6D1C4);
  static const navigationLight = Color(0xFFF9F8F3);
  static const navigationDark = Color(0xF9080D0B);
  static const navigationIndicatorLight = Color(0xFFE9E1D0);
  static const navigationIndicatorDark = Color(0x2B6366F1);
  static const inputDark = Color(0xFF0F111A);
  static const darkBorder = Color(0x1FFFFFFF);
  static const darkBorderStrong = Color(0x2BFFFFFF);
  static const darkDivider = Color(0x18FFFFFF);
  static const cardBorderLight = Color(0xFFE1DDD2);
  /// Light warm-brown accent used only as a restrained atmospheric underlay.
  static const darkGreenGlow = Color(0xFF264C36);
  static const warmHalo = Color(0xFFC2A487);
  static const warmHaloDark = Color(0xFF826D59);

  // Wallet balance hero roles. These aliases preserve the established deep
  // slate-blue identity while keeping page-specific colors out of widgets.
  static const walletBalanceHeroStart = Color(0xFF121726);
  static const walletBalanceHeroMiddle = Color(0xFF1B2748);
  static const walletBalanceHeroEnd = Color(0xFF0E131E);
  static const walletBalanceOnHero = Color(0xFFFFFFFF);
  static const walletBalanceOnHeroMuted = Color(0xB3FFFFFF);
  static const walletBalanceOnHeroSubtle = Color(0x99FFFFFF);
  static const walletBalanceMetricFill = Color(0x0BFFFFFF);
  static const walletBalanceMetricBorder = Color(0x0FFFFFFF);
  static const walletBalanceMetricBorderEmphasized = Color(0x3DFFFFFF);
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
  static const section = 28.0;
  static const display = 48.0;
}

class HopeV2Radii {
  const HopeV2Radii._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const hero = 28.0;
  static const input = 12.0;
  static const button = 12.0;
  static const navigation = 12.0;
  static const chip = 10.0;
  static const iconTile = 14.0;
  static const fab = 16.0;
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

  static const barHeight = 68.0;
  /// Scroll tail for the final meaningful item above the fixed dock.
  static const scrollEndGap = 12.0;

  /// Tail padding for scrollable content. Scaffold reserves the dock height;
  /// this adds final breathing room and any system inset not consumed by SafeArea.
  static EdgeInsets scrollEndPadding(
    BuildContext context, {
    double horizontal = 0,
    double top = 0,
  }) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      bottomInset + scrollEndGap,
    );
  }

  static const dockRadius = 18.0;
  static const itemRadius = 12.0;
  static const itemWidth = 42.0;
  static const itemHeight = 28.0;
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
    // The dark reference uses a controlled near-black canvas. Keep the page
    // layer flat so domain surfaces, hero cards, and content carry the visual
    // hierarchy instead of a full-page color wash.
    if (dark) {
      return const LinearGradient(
        colors: [Colors.transparent, Colors.transparent],
      );
    }
    return const LinearGradient(
      begin: AlignmentDirectional.topEnd,
      end: AlignmentDirectional.bottomStart,
      colors: [
        Color(0x0DC2A487),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: [0.0, 0.42, 1.0],
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
      Color(0xFF5B5343),
      Color(0xFF827252),
      Color(0xFFB9A77C),
    ],
    stops: [0, .55, 1],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // Runtime visual target: flat dark canvas with a restrained neutral hero.
  static const heroDark = LinearGradient(
    colors: [
      Color(0xFF121726),
      Color(0xFF1B2748),
      Color(0xFF121726),
      Color(0xFF090D16),
    ],
    stops: [0, .38, .72, 1],
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
  static Color success(BuildContext context) => HopeV2Colors.success;
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

  // Runtime visual certification target: no cyan spill on dark hero edges.
  static const heroDark = [
    BoxShadow(
      color: Color(0x18264C36),
      blurRadius: 30,
      offset: Offset(0, 14),
    ),
    BoxShadow(
      color: Color(0x0C264C36),
      blurRadius: 42,
      offset: Offset(-8, 18),
    ),
  ];

  static const gradientHero = [
    BoxShadow(
      color: Color(0x252B5B42),
      blurRadius: 28,
      offset: Offset(0, 12),
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
      .copyWith(fontSize: 30, letterSpacing: -.7, height: 1.1);

  static TextStyle hero(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineMedium!
      .copyWith(fontSize: 25, letterSpacing: -.55, height: 1.08);

  static TextStyle metric(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -.45,
        height: 1.0,
      );

  static TextStyle section(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(fontSize: 18, letterSpacing: -.2, height: 1.18);

  static TextStyle eyebrow(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge!
      .copyWith(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .55);
}