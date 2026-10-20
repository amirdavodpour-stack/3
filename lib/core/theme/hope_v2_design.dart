import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// HOPE V2 design primitives.
///
/// This is intentionally token-first: screens should consume these values
/// instead of inventing per-page spacing, radii, or breakpoints.

/// Canonical HOPE contract: indigo-led actions, near-black navy-charcoal surfaces, warm editorial paper, and disciplined semantic accents.
/// Runtime certification batch: compact home, deterministic glass, restrained bloom.
/// Certification round three: opaque premium surfaces + controlled wallet hero.
/// Final visual checkpoint: wallet/profile bloom removed; home remains compact.
/// Canonical HOPE visual tokens. Legacy theme APIs alias these values so
/// existing screens can migrate without creating a second design system.
class HopeV2Colors {
  const HopeV2Colors._();

  static const primary = Color(0xFF6366F1);
  static const primaryAction = Color(0xFF4F46E5);
  /// Dark-green fill for the specific primary CTAs marked in the 2026-10-20 visual audit.
  /// Keep the global indigo brand/action ramp unchanged.
  static const markedPrimaryActionDarkGreen = Color(0xFF2E7B5A);
  static const primaryOnLight = Color(0xFF4F46E5);
  static const successOnLight = Color(0xFF166534);
  static const warningOnLight = Color(0xFF92400E);
  static const dangerOnLight = Color(0xFFB91C1C);
  static const secondaryAction = Color(0xFF0F766E);

  static const primaryDark = Color(0xFF818CF8);
  // Brand hues are interaction cues, never uncontrolled readable text foregrounds.
  static const primaryActionHoverLight = Color(0xFF4338CA);
  static const primaryActionPressedLight = Color(0xFF3730A3);
  static const primaryTintLight = Color(0xFFE0E7FF);
  static const primaryBorderLight = Color(0xFFA5B4FC);
  static const primaryTintDark = Color(0x2B6366F1);
  static const primaryBorderDark = Color(0x59818CF8);
  static const secondary = Color(0xFF14B8A6);
  static const secondaryStrong = Color(0xFF0D9488);
  static const secondaryDark = Color(0xFF5EEAD4);
  // Legacy generic accent stays amber and aliases the warning ramp below.
  static const accent = Color(0xFFF59E0B);
  static const editorialClay = Color(0xFFD0A16D);
  /// Focus accent for featured/recommended work surfaces; use sparingly.
  static const orange = Color(0xFFF97316);
  static const orangeDark = Color(0xFFFF9A4D);
  static const inkSoft = Color(0xFF344238);
  static const backgroundWarm = Color(0xFFF4F0E5);
  static const ink = Color(0xFF18221C);
  static const muted = Color(0xFF5B665A);
  static const surface = Color(0xFFFFFCF5);
  static const background = Color(0xFFE9E5D9);
  // Match the canonical reference semantic green used for trust/success.
  static const success = Color(0xFF166534);
  static const successDark = Color(0xFFBBF7D0);
  static const warning = Color(0xFF92400E);
  static const warningDark = Color(0xFFFDE68A);
  static const danger = Color(0xFFB91C1C);
  static const dangerDark = Color(0xFFFECACA);
  static const softPrimary = Color(0xFFE0E7FF);
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
  static const moneyTextLight = Color(0xFF18221C);
  static const moneyTextDark = Color(0xFFF1F3EC);
  static const infoTextLight = Color(0xFF115E59);
  static const infoTextDark = Color(0xFF5EEAD4);
  // Dedicated blue identity/trust roles: separate from teal information and indigo brand actions.
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

  static const pageLight = Color(0xFFF4F0E5);
  static const pageDark = Color(0xFF070A12);
  static const panelLight = Color(0xFFFFFCF5);
  static const panelDark = Color(0xFF101522);
  static const panelSoftLight = Color(0xFFF9F6ED);
  static const panelSoftDark = Color(0xFF121726);
  static const chipLight = Color(0xFFE9E5D9);
  static const chipDark = Color(0x20FFFFFF);
  static const chipSelectedDark = Color(0x2B6366F1);
  static const disabledLight = Color(0xFFE5E2D9);
  static const borderControlLight = Color(0xFFD8D4C8);
  static const dividerLight = Color(0xFFE6E2D9);
  static const outlinedButtonBorderLight = Color(0xFFD6D1C4);
  static const navigationLight = Color(0xFFF9F8F3);
  static const navigationDark = Color(0xF90B0F18);
  static const navigationIndicatorLight = Color(0xFFE0E7FF);
  static const navigationIndicatorDark = Color(0x2B6366F1);
  static const inputDark = Color(0xFF0F111A);
  static const darkBorder = Color(0x1FFFFFFF);
  static const darkBorderStrong = Color(0x2BFFFFFF);
  static const darkDivider = Color(0x18FFFFFF);
  static const cardBorderLight = Color(0xFFE1DDD2);
  /// Muted forest-green glow for rare decorative underlays, never a global surface.
  static const darkGreenGlow = Color(0xFF264C36);
  static const warmHalo = Color(0xFFD0A16D);
  static const warmHaloDark = Color(0xFF826D59);

  // Wallet balance hero roles restore the prior slate/navy surface hierarchy.
  // The semantic status ramps remain independent from this neutral hero.
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

/// State-aware style for only the primary CTAs called out in the 2026-10-20 visual audit.
/// Disabled/loading actions remain neutral; enabled actions use the audited green fill.
class HopeV2ButtonStyles {
  const HopeV2ButtonStyles._();

  static ButtonStyle auditedGreenPrimaryCta(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton.styleFrom(
      backgroundColor: HopeV2Colors.markedPrimaryActionDarkGreen,
      foregroundColor: HopeV2Colors.darkText,
      disabledBackgroundColor: isDark
          ? HopeV2Colors.darkSurface
          : HopeV2Colors.disabledLight,
      disabledForegroundColor: isDark
          ? HopeV2Colors.darkMuted
          : HopeV2Colors.muted,
      overlayColor: HopeV2Colors.darkText.withValues(alpha: 0.12),
    );
  }
}

/// Muted decorative identities for opportunity artwork and its matching card
/// accent rail. These colors are never readable text and never represent a
/// lifecycle, money, verification, or trust state.
class HopeV2OpportunityAccents {
  const HopeV2OpportunityAccents._();

  static const software = Color(0xFF557D75);
  static const design = Color(0xFF9B805A);
  static const marketing = Color(0xFFAD735B);
  static const content = Color(0xFF65827D);
  static const finance = Color(0xFF4F805D);
  static const education = Color(0xFF728B91);
  static const support = Color(0xFF718E87);
  static const construction = Color(0xFFB27A55);
  static const media = Color(0xFF9E7782);
  static const data = Color(0xFF4E817B);
  static const sales = Color(0xFF6B895D);
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

/// Ten ramps form the HOPE color genome: indigo brand actions, restrained botanical accents,
/// slate-neutral surfaces, teal information, blue trust, green success, amber warning,
/// featured orange, and red danger. Each family owns a distinct semantic role.
class HopeV2TonalPalettes {
  const HopeV2TonalPalettes._();

  static const brand = indigo;

  /// Indigo action ramp restored from the prior HOPE dark identity.
  static const indigo = HopeV2TonalPalette(
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

  /// Supporting botanical ramp for low-emphasis category artwork, not global actions.
  static const forest = HopeV2TonalPalette(
    shade50: Color(0xFFF0F5EE),
    shade100: Color(0xFFDDE9D8),
    shade200: Color(0xFFC0D7B8),
    shade300: Color(0xFF9FBF91),
    shade400: Color(0xFF789F6B),
    shade500: Color(0xFF557D4D),
    shade600: Color(0xFF3E673F),
    shade700: Color(0xFF31583C),
    shade800: Color(0xFF244D38),
    shade900: Color(0xFF193A2A),
    shade950: Color(0xFF0E2419),
  );

  /// Legacy lichen ramp is a sparing decorative accent, not the selected/action color.
  static const lichen = HopeV2TonalPalette(
    shade50: Color(0xFFF7FAE9),
    shade100: Color(0xFFEEF5D0),
    shade200: Color(0xFFDCEBA8),
    shade300: Color(0xFFCCE477),
    shade400: Color(0xFFB8D86C),
    shade500: Color(0xFF9FBF67),
    shade600: Color(0xFF88A96A),
    shade700: Color(0xFF6F9659),
    shade800: Color(0xFF4E713F),
    shade900: Color(0xFF354D2B),
    shade950: Color(0xFF1C2A18),
  );

  static const neutral = HopeV2TonalPalette(
    shade50: Color(0xFFFAF9F4),
    shade100: Color(0xFFF2F0E8),
    shade200: Color(0xFFE9E5D9),
    shade300: Color(0xFFD6D1C4),
    shade400: Color(0xFFB4AE9E),
    shade500: Color(0xFF8B8779),
    shade600: Color(0xFF5B665A),
    shade700: Color(0xFF4A574A),
    shade800: Color(0xFF344238),
    shade900: Color(0xFF18221C),
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
/// Canonical Cupertino/SF-style icon vocabulary for all product surfaces.
/// Keep one stable semantic name per concept so screens never choose glyphs locally.
class HopeV2Icons {
  const HopeV2Icons._();

  // Primary navigation: outline / filled pairs.
  static const IconData home = CupertinoIcons.house;
  static const IconData homeSelected = CupertinoIcons.house_fill;
  static const IconData workshop = CupertinoIcons.briefcase;
  static const IconData workshopSelected = CupertinoIcons.briefcase_fill;
  static const IconData activity = CupertinoIcons.waveform_path;
  static const IconData activitySelected = CupertinoIcons.waveform_path_ecg;
  static const IconData wallet = CupertinoIcons.creditcard;
  static const IconData walletSelected = CupertinoIcons.creditcard_fill;
  static const IconData profile = CupertinoIcons.person_crop_circle;
  static const IconData profileSelected = CupertinoIcons.person_crop_circle_fill;

  // Discover, opportunities and matching.
  static const IconData mission = CupertinoIcons.bolt;
  static const IconData job = CupertinoIcons.doc_text;
  static const IconData featured = CupertinoIcons.star;
  static const IconData match = CupertinoIcons.sparkles;
  static const IconData location = CupertinoIcons.location;
  static const IconData category = CupertinoIcons.tag;
  static const IconData distance = CupertinoIcons.location_north;
  static const IconData skills = CupertinoIcons.wrench;
  static const IconData description = CupertinoIcons.doc_richtext;
  static const IconData route = CupertinoIcons.map;
  static const IconData android = CupertinoIcons.device_phone_portrait;
  static const IconData apple = CupertinoIcons.device_laptop;
  static const IconData web = CupertinoIcons.globe;
  static const IconData device = CupertinoIcons.device_phone_portrait;

  // Financial actions and lifecycle.
  static const IconData protectedFunds = CupertinoIcons.lock_shield;
  static const IconData secure = CupertinoIcons.lock;
  static const IconData payments = CupertinoIcons.doc_on_clipboard;
  static const IconData transferIn = CupertinoIcons.arrow_down_left;
  static const IconData transferOut = CupertinoIcons.arrow_up_right;
  static const IconData completed = CupertinoIcons.checkmark_circle;
  static const IconData success = CupertinoIcons.checkmark_circle;
  static const IconData pending = CupertinoIcons.hourglass;
  static const IconData error = CupertinoIcons.xmark_circle;
  static const IconData insights = CupertinoIcons.chart_bar;
  static const IconData savedSearches = CupertinoIcons.bookmark;
  static const IconData deposit = CupertinoIcons.arrow_down_circle;
  static const IconData withdraw = CupertinoIcons.arrow_up_circle;
  static const IconData history = CupertinoIcons.clock;
  static const IconData budget = CupertinoIcons.doc_chart;
  static const IconData deadline = CupertinoIcons.calendar;
  static const IconData escrow = CupertinoIcons.lock_shield;

  // Forms, communication and utilities.
  static const IconData mail = CupertinoIcons.envelope;
  static const IconData email = CupertinoIcons.envelope;
  static const IconData at = CupertinoIcons.at;
  static const IconData view = CupertinoIcons.eye;
  static const IconData viewOff = CupertinoIcons.eye_slash;
  static const IconData password = CupertinoIcons.lock;
  static const IconData lockOpen = CupertinoIcons.lock_open;
  static const IconData copy = CupertinoIcons.doc_on_doc;
  static const IconData verified = CupertinoIcons.checkmark_seal;
  static const IconData message = CupertinoIcons.chat_bubble_text;
  static const IconData add = CupertinoIcons.plus;
  static const IconData menu = CupertinoIcons.line_horizontal_3;
  static const IconData refresh = CupertinoIcons.arrow_clockwise;
  static const IconData search = CupertinoIcons.search;
  static const IconData filter = CupertinoIcons.slider_horizontal_3;
  static const IconData close = CupertinoIcons.xmark;
  static const IconData notifications = CupertinoIcons.bell;
  static const IconData translate = CupertinoIcons.textformat;
  static const IconData userAdd = CupertinoIcons.person_crop_circle_badge_plus;
  static const IconData login = CupertinoIcons.arrow_right_square;
  static const IconData logout = CupertinoIcons.escape;
  static const IconData arrowLeft = CupertinoIcons.arrow_left;
  static const IconData arrowRight = CupertinoIcons.arrow_right;
  static const IconData save = CupertinoIcons.bookmark;
  static const IconData share = CupertinoIcons.share;
  static const IconData roleSwitch = CupertinoIcons.repeat;
  static const IconData transfer = CupertinoIcons.arrow_left_right;
  static const IconData empty = CupertinoIcons.tray;
  static const IconData offline = CupertinoIcons.wifi_slash;
  static const IconData info = CupertinoIcons.info;
  static const IconData warning = CupertinoIcons.exclamationmark_triangle;
  static const IconData upload = CupertinoIcons.tray_arrow_up;
  static const IconData attachment = CupertinoIcons.paperclip;
  static const IconData download = CupertinoIcons.tray_arrow_down;
  static const IconData pause = CupertinoIcons.pause_circle;
  static const IconData refund = CupertinoIcons.arrow_uturn_left;
  static const IconData flag = CupertinoIcons.flag;
  static const IconData play = CupertinoIcons.play_circle;
  static const IconData campaign = CupertinoIcons.speaker;
  static const IconData validation = CupertinoIcons.exclamationmark_triangle;
  static const IconData conflict = CupertinoIcons.arrow_2_circlepath;
  static const IconData retry = CupertinoIcons.arrow_clockwise;
  static const IconData permission = CupertinoIcons.lock;
  static const IconData rateLimit = CupertinoIcons.hourglass_tophalf_fill;
  static const IconData legal = CupertinoIcons.hammer;
  static const IconData assign = CupertinoIcons.person_crop_circle_badge_checkmark;
  static const IconData account = CupertinoIcons.person_crop_circle;
  static const IconData moderation = CupertinoIcons.shield;
  static const IconData identity = CupertinoIcons.person_crop_circle;
  static const IconData admin = CupertinoIcons.lock_shield;
  static const IconData removeRole = CupertinoIcons.person_crop_circle_badge_minus;
  static const IconData partial = CupertinoIcons.chart_pie;
}

/// Resolves a restrained identity/semantic tint for icon tiles and empty states.
///
/// The mapping is by product concept, not by screen theme: botanical green is
/// a peer accent for work and money-in actions; teal marks information and
/// communication; blue marks trust/identity; warm clay marks featured content;
/// amber/red remain reserved for pending and negative states. Unmapped actions
/// keep the indigo brand role. Readable text must not use these decorative tints.
class HopeV2IconAccents {
  const HopeV2IconAccents._();

  static const List<IconData> _green = <IconData>[
    HopeV2Icons.mission,
    HopeV2Icons.job,
    HopeV2Icons.workshop,
    HopeV2Icons.workshopSelected,
    HopeV2Icons.activity,
    HopeV2Icons.activitySelected,
    HopeV2Icons.wallet,
    HopeV2Icons.walletSelected,
    HopeV2Icons.payments,
    HopeV2Icons.transferIn,
    HopeV2Icons.completed,
    HopeV2Icons.success,
    HopeV2Icons.deposit,
    HopeV2Icons.insights,
    HopeV2Icons.budget,
    HopeV2Icons.refund,
  ];
  static const List<IconData> _teal = <IconData>[
    HopeV2Icons.message,
    HopeV2Icons.mail,
    HopeV2Icons.email,
    HopeV2Icons.info,
    HopeV2Icons.search,
    HopeV2Icons.refresh,
    HopeV2Icons.notifications,
    HopeV2Icons.attachment,
    HopeV2Icons.download,
    HopeV2Icons.upload,
    HopeV2Icons.partial,
    HopeV2Icons.category,
    HopeV2Icons.savedSearches,
    HopeV2Icons.translate,
  ];
  static const List<IconData> _blue = <IconData>[
    HopeV2Icons.protectedFunds,
    HopeV2Icons.secure,
    HopeV2Icons.escrow,
    HopeV2Icons.verified,
    HopeV2Icons.moderation,
    HopeV2Icons.identity,
    HopeV2Icons.account,
    HopeV2Icons.profile,
    HopeV2Icons.profileSelected,
    HopeV2Icons.admin,
    HopeV2Icons.assign,
    HopeV2Icons.userAdd,
    HopeV2Icons.legal,
    HopeV2Icons.location,
    HopeV2Icons.distance,
    HopeV2Icons.route,
    HopeV2Icons.android,
    HopeV2Icons.apple,
    HopeV2Icons.device,
    HopeV2Icons.web,
  ];
  static const List<IconData> _clay = <IconData>[
    HopeV2Icons.featured,
    HopeV2Icons.match,
    HopeV2Icons.campaign,
    HopeV2Icons.flag,
    HopeV2Icons.play,
  ];
  static const List<IconData> _amber = <IconData>[
    HopeV2Icons.pending,
    HopeV2Icons.warning,
    HopeV2Icons.rateLimit,
    HopeV2Icons.deadline,
    HopeV2Icons.history,
  ];
  static const List<IconData> _red = <IconData>[
    HopeV2Icons.error,
    HopeV2Icons.offline,
    HopeV2Icons.withdraw,
    HopeV2Icons.transferOut,
    HopeV2Icons.validation,
    HopeV2Icons.conflict,
    HopeV2Icons.removeRole,
  ];

  /// Resolves a role tint. Text must use semantic text colors, never these accents.
  static Color resolve(Object? icon, {required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    final green = dark
        ? HopeV2TonalPalettes.forest.shade300
        : HopeV2TonalPalettes.forest.shade700;
    final teal = dark
        ? HopeV2TonalPalettes.info.shade300
        : HopeV2TonalPalettes.info.shade700;
    final blue = dark
        ? HopeV2TonalPalettes.trust.shade300
        : HopeV2TonalPalettes.trust.shade700;
    final clay = dark
        ? HopeV2TonalPalettes.featured.shade300
        : HopeV2TonalPalettes.featured.shade700;
    final amber = dark
        ? HopeV2TonalPalettes.warning.shade200
        : HopeV2TonalPalettes.warning.shade800;
    final red = dark
        ? HopeV2TonalPalettes.danger.shade300
        : HopeV2TonalPalettes.danger.shade700;
    final indigo = dark ? HopeV2Colors.primaryDark : HopeV2Colors.primaryAction;

    if (icon is! IconData) return indigo;
    if (_green.contains(icon)) return green;
    if (_teal.contains(icon)) return teal;
    if (_blue.contains(icon)) return blue;
    if (_clay.contains(icon)) return clay;
    if (_amber.contains(icon)) return amber;
    if (_red.contains(icon)) return red;
    return indigo;
  }
}

/// Primary navigation uses the same Cupertino family with outline/filled pairs.
/// Domain actions resolve through HopeV2Icons so every screen shares one vocabulary.
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
  static const section = 24.0;
  static const display = 40.0;
}

class HopeV2Radii {
  const HopeV2Radii._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const hero = 18.0;
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
        Color(0x0DD0A16D),
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

  // Restore the prior restrained slate/navy hero; indigo remains reserved for action and selection.
  static const heroDark = LinearGradient(
    colors: [
      Color(0xFF121726),
      Color(0xFF1B2748),
      Color(0xFF121726),
    ],
    stops: [0, .55, 1],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

class HopeV2SemanticColors {
  const HopeV2SemanticColors._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Indigo owns brand actions and selection. Forest and lichen are supporting decorative accents, never readable text roles.
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

  /// Verified identity/security is blue, not the forest/lichen brand action hue.
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

  /// Recommended/featured state uses warm orange, never the brand action hue as text.
  static Color featured(BuildContext context) =>
      _isDark(context) ? HopeV2Colors.accentTextDark : HopeV2Colors.accentTextLight;

  /// Named state roles make intent explicit at product call sites.
  static Color pending(BuildContext context) => warning(context);
  static Color processing(BuildContext context) => info(context);
  static Color incomingAmount(BuildContext context) => success(context);
  static Color pendingAmount(BuildContext context) => warning(context);
  static Color outgoingAmount(BuildContext context) => error(context);
  static Color negativeAmount(BuildContext context) => error(context);

  /// Contrast-safe text foreground for semantic chips; never pass a raw brand action hue.
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


/// Theme-aware identities for the financial chart series. These are data-series
/// colors (not text colors): incoming funds use the success family, outgoing
/// cash flow has a distinct negative-flow family, and reserved funds use amber.
class HopeV2ChartColors {
  const HopeV2ChartColors._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color cashIn(BuildContext context) => _isDark(context)
      ? HopeV2TonalPalettes.success.shade400
      : HopeV2TonalPalettes.success.shade700;

  static Color cashOut(BuildContext context) => _isDark(context)
      ? HopeV2TonalPalettes.danger.shade400
      : HopeV2TonalPalettes.danger.shade700;

  static Color reserved(BuildContext context) => _isDark(context)
      ? HopeV2TonalPalettes.warning.shade300
      : HopeV2TonalPalettes.warning.shade700;
}

class HopeV2Shadows {
  const HopeV2Shadows._();

  static const card = [
    BoxShadow(
      color: Color(0x0D1B1638),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const hero = [
    BoxShadow(
      color: Color(0x1A1C1738),
      blurRadius: 16,
      offset: Offset(0, 5),
    ),
  ];

  // Runtime visual certification target: no cyan spill on dark hero edges.
  static const heroDark = [
    BoxShadow(
      color: Color(0x12333B70),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x062B345F),
      blurRadius: 18,
      offset: Offset(-3, 5),
    ),
  ];

  static const gradientHero = [
    BoxShadow(
      color: Color(0x1A2C3372),
      blurRadius: 12,
      offset: Offset(0, 4),
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
      .copyWith(fontSize: 28, letterSpacing: -.6, height: 1.12);

  static TextStyle hero(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineMedium!
      .copyWith(fontSize: 23, letterSpacing: -.45, height: 1.12);

  static TextStyle metric(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
        height: 1.08,
      );

  static TextStyle section(BuildContext context) => Theme.of(context)
      .textTheme
      .titleLarge!
      .copyWith(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.15, height: 1.22);

  static TextStyle eyebrow(BuildContext context) => Theme.of(context)
      .textTheme
      .labelLarge!
      .copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .4);
}