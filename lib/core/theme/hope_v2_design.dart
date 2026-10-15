import 'package:flutter/cupertino.dart';
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
  static const primaryAction = Color(0xFF4F46E5);
  static const primaryOnLight = Color(0xFF4F46E5);
  static const successOnLight = Color(0xFF166534);
  static const warningOnLight = Color(0xFF92400E);
  static const dangerOnLight = Color(0xFFB91C1C);
  static const secondaryAction = Color(0xFF0F766E);

  static const primaryDark = Color(0xFF818CF8);
  // Indigo is an interaction cue, never a readable text foreground.
  static const primaryActionHoverLight = Color(0xFF4338CA);
  static const primaryActionPressedLight = Color(0xFF3730A3);
  static const primaryTintLight = Color(0xFFEEF2FF);
  static const primaryBorderLight = Color(0xFFC7D2FE);
  static const primaryTintDark = Color(0x2B6366F1);
  static const primaryBorderDark = Color(0x4D818CF8);
  static const secondary = Color(0xFF14B8A6);
  static const secondaryStrong = Color(0xFF0D9488);
  static const secondaryDark = Color(0xFF5EEAD4);
  // Legacy generic accent stays amber and aliases the warning ramp below.
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
  static const successDark = Color(0xFFBBF7D0);
  static const warning = Color(0xFFB78635);
  static const warningDark = Color(0xFFFDE68A);
  static const danger = Color(0xFFC14B43);
  static const dangerDark = Color(0xFFFECACA);
  static const softPrimary = Color(0xFFE8E0CD);
  static const darkBackground = Color(0xFF070A12);
  static const darkSurface = Color(0xFF0F111A);
  static const darkCard = Color(0xFF111827);
  static const darkText = Color(0xFFF1F3EC);
  static const darkMuted = Color(0xFFAEB7AC);

  // Navigation labels are deliberately achromatic, unlike olive-muted body text.
  static const navigationLabelDark = Color(0xFFF4F4F5);
  static const navigationLabelMutedDark = Color(0xFFBDBDC3);
  static const navigationLabelLight = Color(0xFF27272A);
  static const navigationLabelMutedLight = Color(0xFF68686F);

  // Text roles must remain independent from brand-action hues.
  static const moneyTextLight = Color(0xFF24271F);
  static const moneyTextDark = Color(0xFFF1F3EC);
  static const infoTextLight = Color(0xFF0F766E);
  static const infoTextDark = Color(0xFF5EEAD4);
  // Dedicated blue identity/trust roles: separate from teal information and indigo actions.
  static const trustTextLight = Color(0xFF1E40AF);
  static const trustTextDark = Color(0xFFBFDBFE);
  static const trustSurfaceLight = Color(0xFFEFF6FF);
  static const trustSurfaceDark = Color(0xFF14253A);

  // Featured/recommended content uses a dedicated warm foreground, never the
  // brand-action hue. Its surface stays distinct from readable foregrounds.
  static const accentTextLight = Color(0xFF9A3412);
  static const accentTextDark = Color(0xFFFDBA74);
  static const accentSurfaceLight = Color(0xFFFFF1E6);
  static const accentSurfaceDark = Color(0xFF332316);

  // Low-intensity state backgrounds are separate from their text foregrounds.
  static const successSurfaceLight = Color(0xFFE8F5E9);
  static const successSurfaceDark = Color(0xFF172A22);
  static const warningSurfaceLight = Color(0xFFFFF3D6);
  static const warningSurfaceDark = Color(0xFF302617);
  static const dangerSurfaceLight = Color(0xFFFDEBEC);
  static const dangerSurfaceDark = Color(0xFF351D22);
  static const infoSurfaceLight = Color(0xFFDDF5F0);
  static const infoSurfaceDark = Color(0xFF142C2C);

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

/// Muted decorative identities for opportunity artwork and its matching card
/// accent rail. These colors are never readable text and never represent a
/// lifecycle, money, verification, or trust state.
class HopeV2OpportunityAccents {
  const HopeV2OpportunityAccents._();

  static const software = Color(0xFF557D75);
  static const design = Color(0xFFB58A4D);
  static const marketing = Color(0xFFB86F55);
  static const content = Color(0xFF5A8793);
  static const finance = Color(0xFF4F805D);
  static const education = Color(0xFF638DA3);
  static const support = Color(0xFF718E87);
  static const construction = Color(0xFFB9784C);
  static const media = Color(0xFFB46F86);
  static const data = Color(0xFF438B91);
  static const sales = Color(0xFF5D875F);
}

/// A complete, stable tonal ramp. Consumers should request named stops rather
/// than interpolate UI colors at runtime; interaction hues and text roles stay
/// separately defined in [HopeV2Colors].
class HopeV2TonalPalette {
  const HopeV2TonalPalette({
    required this.shade50,
    required this.shade100,
    required this.shade200,
    required this.shade300,
    required this.shade400,
    required this.shade500,
    required this.shade600,
    required this.shade700,
    required this.shade800,
    required this.shade900,
    required this.shade950,
  });

  static const steps = <int>[50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];

  final Color shade50;
  final Color shade100;
  final Color shade200;
  final Color shade300;
  final Color shade400;
  final Color shade500;
  final Color shade600;
  final Color shade700;
  final Color shade800;
  final Color shade900;
  final Color shade950;

  Color shade(int step) => switch (step) {
        50 => shade50,
        100 => shade100,
        200 => shade200,
        300 => shade300,
        400 => shade400,
        500 => shade500,
        600 => shade600,
        700 => shade700,
        800 => shade800,
        900 => shade900,
        950 => shade950,
        _ => throw ArgumentError.value(step, 'step', 'Expected a defined tonal step'),
      };

  List<Color> get values => [
        shade50, shade100, shade200, shade300, shade400, shade500,
        shade600, shade700, shade800, shade900, shade950,
      ];
}

/// Eight shared ramps form the HOPE color genome. The warm featured-orange
/// ramp is distinct from amber warning, and blue trust is distinct from teal info.
/// Purple/indigo remains action-only; semantic foregrounds are chosen separately.
class HopeV2TonalPalettes {
  const HopeV2TonalPalettes._();

  static const brand = HopeV2TonalPalette(
    shade50: Color(0xFFEEF2FF),
    shade100: Color(0xFFE0E7FF),
    shade200: Color(0xFFC7D2FE),
    shade300: Color(0xFFA5B4FC),
    shade400: Color(0xFF818CF8),
    shade500: Color(0xFF6366F1),
    shade600: Color(0xFF4F46E5),
    shade700: Color(0xFF4338CA),
    shade800: Color(0xFF3730A3),
    shade900: Color(0xFF312E81),
    shade950: Color(0xFF1E1B4B),
  );

  static const neutral = HopeV2TonalPalette(
    shade50: Color(0xFFFAF9F4),
    shade100: Color(0xFFF2F0E8),
    shade200: Color(0xFFE9E5D9),
    shade300: Color(0xFFD6D1C4),
    shade400: Color(0xFFB4AE9E),
    shade500: Color(0xFF8B8779),
    shade600: Color(0xFF66675B),
    shade700: Color(0xFF4A4C43),
    shade800: Color(0xFF34372D),
    shade900: Color(0xFF24271F),
    shade950: Color(0xFF12140F),
  );

  static const info = HopeV2TonalPalette(
    shade50: Color(0xFFE6FFFB),
    shade100: Color(0xFFCCFBF1),
    shade200: Color(0xFF99F6E4),
    shade300: Color(0xFF5EEAD4),
    shade400: Color(0xFF2DD4BF),
    shade500: Color(0xFF14B8A6),
    shade600: Color(0xFF0D9488),
    shade700: Color(0xFF0F766E),
    shade800: Color(0xFF115E59),
    shade900: Color(0xFF134E4A),
    shade950: Color(0xFF042F2E),
  );

  static const trust = HopeV2TonalPalette(
    shade50: Color(0xFFEFF6FF),
    shade100: Color(0xFFDBEAFE),
    shade200: Color(0xFFBFDBFE),
    shade300: Color(0xFF93C5FD),
    shade400: Color(0xFF60A5FA),
    shade500: Color(0xFF3B82F6),
    shade600: Color(0xFF2563EB),
    shade700: Color(0xFF1D4ED8),
    shade800: Color(0xFF1E40AF),
    shade900: Color(0xFF1E3A8A),
    shade950: Color(0xFF172554),
  );

  static const success = HopeV2TonalPalette(
    shade50: Color(0xFFF0FDF4),
    shade100: Color(0xFFDCFCE7),
    shade200: Color(0xFFBBF7D0),
    shade300: Color(0xFF86EFAC),
    shade400: Color(0xFF4ADE80),
    shade500: Color(0xFF22C55E),
    shade600: Color(0xFF16A34A),
    shade700: Color(0xFF15803D),
    shade800: Color(0xFF166534),
    shade900: Color(0xFF14532D),
    shade950: Color(0xFF052E16),
  );

  static const warning = HopeV2TonalPalette(
    shade50: Color(0xFFFFFBEB),
    shade100: Color(0xFFFEF3C7),
    shade200: Color(0xFFFDE68A),
    shade300: Color(0xFFFCD34D),
    shade400: Color(0xFFFBBF24),
    shade500: Color(0xFFF59E0B),
    shade600: Color(0xFFD97706),
    shade700: Color(0xFFB45309),
    shade800: Color(0xFF92400E),
    shade900: Color(0xFF78350F),
    shade950: Color(0xFF451A03),
  );

  static const featured = HopeV2TonalPalette(
    shade50: Color(0xFFFFF7ED),
    shade100: Color(0xFFFFEDD5),
    shade200: Color(0xFFFDBA74),
    shade300: Color(0xFFFF9A4D),
    shade400: Color(0xFFFB923C),
    shade500: Color(0xFFF97316),
    shade600: Color(0xFFEA580C),
    shade700: Color(0xFFC2410C),
    shade800: Color(0xFF9A3412),
    shade900: Color(0xFF7C2D12),
    shade950: Color(0xFF431407),
  );

  static const danger = HopeV2TonalPalette(
    shade50: Color(0xFFFEF2F2),
    shade100: Color(0xFFFEE2E2),
    shade200: Color(0xFFFECACA),
    shade300: Color(0xFFFCA5A5),
    shade400: Color(0xFFF87171),
    shade500: Color(0xFFEF4444),
    shade600: Color(0xFFDC2626),
    shade700: Color(0xFFB91C1C),
    shade800: Color(0xFF991B1B),
    shade900: Color(0xFF7F1D1D),
    shade950: Color(0xFF450A0A),
  );
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

/// Editorial navigation uses one deliberately distinct Cupertino icon family.
/// The rest of the product keeps its HugeIcons vocabulary; these five
/// high-frequency destinations share familiar outline/filled pairs.
class HopeV2NavigationIcons {
  const HopeV2NavigationIcons._();

  static const home = CupertinoIcons.house;
  static const homeSelected = CupertinoIcons.house_fill;
  static const explore = CupertinoIcons.compass;
  static const exploreSelected = CupertinoIcons.compass_fill;
  static const workshop = CupertinoIcons.briefcase;
  static const workshopSelected = CupertinoIcons.briefcase_fill;
  static const wallet = CupertinoIcons.creditcard;
  static const walletSelected = CupertinoIcons.creditcard_fill;
  static const profile = CupertinoIcons.person_crop_circle;
  static const profileSelected = CupertinoIcons.person_crop_circle_fill;
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

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Brand indigo is reserved for action/selection graphics, never readable text.
  static Color primary(BuildContext context) => Theme.of(context).colorScheme.primary;
  static Color secondary(BuildContext context) => Theme.of(context).colorScheme.secondary;
  static Color surface(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color elevated(BuildContext context) => HopeV2Surfaces.panel(context);
  static Color background(BuildContext context) => HopeV2Surfaces.page(context);
  static Color border(BuildContext context) => HopeV2Surfaces.border(context);

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.darkText : HopeV2Colors.ink;
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.darkMuted : HopeV2Colors.muted;

  /// Navigation labels use neutral grayscale instead of the olive-muted
  /// general text role. Selection remains legible without coloring the copy.
  static Color navigationLabel(
    BuildContext context, {
    required bool selected,
  }) {
    if (_isDark(context)) {
      return selected
          ? HopeV2Colors.navigationLabelDark
          : HopeV2Colors.navigationLabelMutedDark;
    }
    return selected
        ? HopeV2Colors.navigationLabelLight
        : HopeV2Colors.navigationLabelMutedLight;
  }

  static Color amount(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.moneyTextDark : HopeV2Colors.moneyTextLight;

  /// Financial values and their labels have separate foreground roles.
  static Color price(BuildContext context) => amount(context);
  static Color priceLabel(BuildContext context) => textSecondary(context);

  /// Verified identity/security is blue, not the indigo action hue.
  static Color trust(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.trustTextDark : HopeV2Colors.trustTextLight;
  static Color verified(BuildContext context) => trust(context);
  static Color secure(BuildContext context) => trust(context);
  static Color link(BuildContext context) => info(context);
  static Color info(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.infoTextDark : HopeV2Colors.infoTextLight;
  static Color success(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.successDark : HopeV2Colors.successOnLight;
  static Color warning(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.warningDark : HopeV2Colors.warningOnLight;
  static Color error(BuildContext context) => Theme.of(context).colorScheme.error;

  /// Neutral labels and values retain their contrast in both theme modes.
  static Color neutral(BuildContext context) => textSecondary(context);

  /// Recommended/featured state uses warm orange, never brand indigo as text.
  static Color featured(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.accentTextDark : HopeV2Colors.accentTextLight;

  /// Named state roles make intent explicit at product call sites.
  static Color pending(BuildContext context) => warning(context);
  static Color processing(BuildContext context) => info(context);
  static Color incomingAmount(BuildContext context) => success(context);
  static Color pendingAmount(BuildContext context) => warning(context);
  static Color outgoingAmount(BuildContext context) => error(context);
  static Color negativeAmount(BuildContext context) => error(context);

  /// Contrast-safe text foreground for semantic chips; never pass raw indigo.
  static Color statusSurface(BuildContext context, Color accent) {
    if (accent == HopeV2Colors.primary ||
        accent == HopeV2Colors.primaryDark ||
        accent == HopeV2Colors.primaryAction ||
        accent == HopeV2Colors.secondary ||
        accent == HopeV2Colors.secondaryStrong ||
        accent == HopeV2Colors.secondaryDark ||
        accent == HopeV2Colors.secondaryAction) {
      return _isDark(context)
          ? HopeV2Colors.infoSurfaceDark
          : HopeV2Colors.infoSurfaceLight;
    }
    if (accent == HopeV2Colors.trustTextLight ||
        accent == HopeV2Colors.trustTextDark) {
      return _isDark(context)
          ? HopeV2Colors.trustSurfaceDark
          : HopeV2Colors.trustSurfaceLight;
    }
    if (accent == HopeV2Colors.success ||
        accent == HopeV2Colors.successDark ||
        accent == HopeV2Colors.successOnLight) {
      return _isDark(context)
          ? HopeV2Colors.successSurfaceDark
          : HopeV2Colors.successSurfaceLight;
    }
    if (accent == HopeV2Colors.warning ||
        accent == HopeV2Colors.warningDark ||
        accent == HopeV2Colors.warningOnLight) {
      return _isDark(context)
          ? HopeV2Colors.warningSurfaceDark
          : HopeV2Colors.warningSurfaceLight;
    }
    if (accent == HopeV2Colors.danger ||
        accent == HopeV2Colors.dangerDark ||
        accent == HopeV2Colors.dangerOnLight) {
      return _isDark(context)
          ? HopeV2Colors.dangerSurfaceDark
          : HopeV2Colors.dangerSurfaceLight;
    }
    if (accent == HopeV2Colors.accent ||
        accent == HopeV2Colors.orange ||
        accent == HopeV2Colors.orangeDark) {
      return _isDark(context)
          ? HopeV2Colors.accentSurfaceDark
          : HopeV2Colors.accentSurfaceLight;
    }
    return accent.withValues(alpha: _isDark(context) ? .12 : .08);
  }

  static Color readableAccent(BuildContext context, Color accent) {
    if (accent == HopeV2Colors.primary ||
        accent == HopeV2Colors.primaryDark ||
        accent == HopeV2Colors.primaryAction ||
        accent == HopeV2Colors.secondary ||
        accent == HopeV2Colors.secondaryStrong ||
        accent == HopeV2Colors.secondaryDark ||
        accent == HopeV2Colors.secondaryAction) {
      return info(context);
    }
    if (accent == HopeV2Colors.trustTextLight ||
        accent == HopeV2Colors.trustTextDark) return trust(context);
    if (accent == HopeV2Colors.success ||
        accent == HopeV2Colors.successDark ||
        accent == HopeV2Colors.successOnLight) return success(context);
    if (accent == HopeV2Colors.warning ||
        accent == HopeV2Colors.warningDark ||
        accent == HopeV2Colors.warningOnLight) return warning(context);
    if (accent == HopeV2Colors.danger ||
        accent == HopeV2Colors.dangerDark ||
        accent == HopeV2Colors.dangerOnLight) return error(context);
    if (accent == HopeV2Colors.accent ||
        accent == HopeV2Colors.orange ||
        accent == HopeV2Colors.orangeDark) return featured(context);
    if (accent == HopeV2Colors.muted || accent == HopeV2Colors.darkMuted) {
      return textSecondary(context);
    }
    return textPrimary(context);
  }
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