export 'hope_product_architecture.dart';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/hope_v2_design.dart';

import 'components.dart';
import 'hope_display_formatters.dart';
import 'hope_l10n.dart';
import 'hope_product_architecture.dart';

/// Shared page shell. Every V2 flagship surface should use this instead of
/// inventing its own max-width, page padding, or bottom safe-area behavior.
/// Canonical mobile navigation surface for the HOPE shell.
class HopeNavigationGlyph extends StatelessWidget {
  const HopeNavigationGlyph({
    super.key,
    required this.icon,
    required this.selected,
  });

  final Object icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected
        ? (dark ? HopeV2Colors.primaryDark : primary)
        : (dark ? HopeV2Colors.darkMuted : HopeV2Colors.muted);

    return AnimatedContainer(
      duration: reduceMotion ? Duration.zero : HopeV2Motion.fast,
      curve: Curves.easeOutCubic,
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(),
      child: HopeIcon(
        icon,
        size: selected ? 21 : 20,
        color: color,
        strokeWidth: 1.9,
      ),
    );
  }
}

class PremiumNavigationBar extends StatelessWidget {
  const PremiumNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final surface = HopeV2Surfaces.navigation(context);
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactLabels = width < 340 || textScale > 1.2;
    final horizontalInset = compactLabels ? 4.0 : 12.0;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final activeIndex = selectedIndex.clamp(0, destinations.length - 1).toInt();

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 6),
      child: Container(
        key: const ValueKey('hope-navigation-dock'),
        height: HopeV2Navigation.barHeight + (textScale > 1.2 ? 12 : 0),
        padding: EdgeInsets.fromLTRB(compactLabels ? 2 : 6, 4, compactLabels ? 2 : 6, 3),
        decoration: BoxDecoration(
          color: dark
              ? HopeV2Colors.navigationDark.withValues(alpha: .985)
              : surface.withValues(alpha: .98),
          // A restrained, full-width navigation rail: the page content is
          // the visual focus, not a floating decorative container.
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(14),
            topEnd: Radius.circular(14),
          ),
          border: Border(
            top: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: .10)
                  : HopeV2Surfaces.border(context).withValues(alpha: .85),
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / destinations.length;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositionedDirectional(
                  start: itemWidth * activeIndex + 2,
                  top: 2,
                  bottom: 2,
                  width: itemWidth - 4,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: DecoratedBox(
                    key: const ValueKey('hope-navigation-selection-plate'),
                    decoration: ShapeDecoration(
                      color: dark
                          ? HopeV2Colors.navigationIndicatorDark
                          : HopeV2Colors.navigationIndicatorLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: primary.withValues(alpha: dark ? .22 : .16),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositionedDirectional(
                  key: const ValueKey('hope-navigation-selection-accent'),
                  start: itemWidth * activeIndex + itemWidth * .27,
                  top: 4,
                  width: itemWidth * .46,
                  height: 2,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: (dark
                              ? HopeV2TonalPalettes.forest.shade300
                              : HopeV2TonalPalettes.forest.shade700)
                          .withValues(alpha: dark ? .92 : .86),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < destinations.length; index++)
                      Expanded(
                        child: _PremiumNavigationItem(
                          destination: destinations[index],
                          selected: index == activeIndex,
                          onPressed: () => onDestinationSelected(index),
                          compact: compactLabels,
                          showLabel: true,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PremiumNavigationItem extends StatelessWidget {
  const _PremiumNavigationItem({
    required this.destination,
    required this.selected,
    required this.onPressed,
    required this.compact,
    required this.showLabel,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onPressed;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? destination.selectedIcon ?? destination.icon : destination.icon;
    final labelColor = HopeV2SemanticColors.navigationLabel(
      context,
      selected: selected,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(HopeV2Navigation.itemRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 0 : 2,
              vertical: compact ? 1 : 3,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 1 : 4,
                  vertical: compact ? 2 : 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: compact ? 22 : 26,
                      child: Center(child: icon),
                    ),
                    if (showLabel) ...[
                      const SizedBox(height: 1),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: compact ? 10.5 : 11.5,
                            height: compact ? .95 : 1.0,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumPrimaryNavigationScaffold extends StatelessWidget {
  const PremiumPrimaryNavigationScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static List<NavigationDestination> _destinations(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    String label(String fa, String en) => isEn ? en : fa;
    return [
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.home, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.homeSelected, selected: true),
        label: label('خانه', 'Home'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.explore, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.exploreSelected, selected: true),
        label: label('کاوش', 'Explore'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.workshop, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.workshopSelected, selected: true),
        label: label('کارگاه', 'Workshop'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.wallet, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.walletSelected, selected: true),
        label: label('کیف پول', 'Wallet'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.profile, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2NavigationIcons.profileSelected, selected: true),
        label: label('پروفایل', 'Profile'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final destinations = _destinations(context);
    final isDesktop = size.width >= HopeV2Breakpoints.medium;
    return Scaffold(
      backgroundColor: HopeV2Surfaces.page(context),
      body: isDesktop
          ? Row(
              children: [
                PremiumNavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations,
                  extended: size.width >= HopeV2Breakpoints.expanded,
                ),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: isDesktop
          ? null
          : PremiumNavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: destinations,
            ),
    );
  }
}

class PremiumNavigationRail extends StatelessWidget {
  const PremiumNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.extended = false,
    this.leading,
    this.trailing,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final bool extended;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark
              ? HopeV2Colors.navigationDark
              : HopeV2Surfaces.navigation(context).withValues(alpha: .96),
          border: BorderDirectional(
            end: BorderSide(color: HopeV2Surfaces.border(context)),
          ),
        ),
        child: SafeArea(
          left: false,
          top: false,
          bottom: false,
          child: NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: destination.icon,
                  selectedIcon: destination.selectedIcon,
                  label: Text(destination.label),
                ),
            ],
            extended: extended,
            minWidth: HopeV2Navigation.railMinWidth,
            minExtendedWidth: HopeV2Navigation.railExtendedWidth,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            // Keep desktop navigation multi-accent too: green identifies the
            // selected destination; readable labels remain neutral.
            selectedIconTheme: IconThemeData(
              color: dark
                  ? HopeV2TonalPalettes.forest.shade300
                  : HopeV2TonalPalettes.forest.shade700,
              size: 24,
            ),
            unselectedIconTheme: IconThemeData(
              color: HopeV2SemanticColors.navigationLabel(context, selected: false),
              size: 24,
            ),
            selectedLabelTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: HopeV2SemanticColors.textPrimary(context),
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelTextStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: HopeV2SemanticColors.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
            leading: leading,
            trailing: trailing,
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            useIndicator: false,
            groupAlignment: -.6,
          ),
        ),
      ),
    );
  }
}

/// App-wide opaque canvas used behind every routed surface.
///
/// Some flagship routes are direct page widgets rather than Scaffolds. Keeping
/// the base canvas at the MaterialApp builder seam prevents transparent gaps
/// from exposing the platform surface while preserving each page's own
/// composition and surface hierarchy.
class PremiumAppCanvas extends StatelessWidget {
  const PremiumAppCanvas({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HopeV2Surfaces.page(context),
        gradient: HopeV2Surfaces.pageHalo(context),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}

class PremiumPageFrame extends StatelessWidget {
  const PremiumPageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 104),
    this.safeBottom = true,
    this.page,
    this.domain,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool safeBottom;
  final HopePageId? page;
  final HopeProductDomain? domain;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = safeBottom ? MediaQuery.paddingOf(context).bottom : 0.0;
    // The navigation dock is outside the page body, so large fixed bottom tails
    // double-reserve space and create a dead band above the dock on compact phones.
    // Keep only a small gesture/safe-area cushion; longer screens retain their
    // page-specific editorial spacing.
    final compactBottomPadding = size.height < 560
        ? padding.bottom.clamp(0.0, 8.0).toDouble()
        : size.height < 680
            ? padding.bottom.clamp(0.0, 16.0).toDouble()
            : padding.bottom;
    final resolvedDomain = domain ?? page?.spec.domain;
    final domainAccent = resolvedDomain?.spec.accentFor(context);
    final showDomainRail = size.width >= HopeV2Breakpoints.medium;
    final pageColor = HopeV2Surfaces.page(context);

    // Paint the page color on the frame itself, not only on a positioned child.
    // Runtime integration_test captures direct page subtrees; those must remain
    // opaque even when no parent Scaffold participates in the captured layer.
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: size.height,
      ),
      child: Material(
        // Use an explicit canvas Material at the frame root. This gives direct
        // Android integration_test captures an opaque surface before any
        // transparent gradient/surface layers are composited above it.
        type: MaterialType.canvas,
        color: pageColor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: HopeV2Surfaces.pageHalo(context),
            border: domainAccent == null || !showDomainRail
                ? null
                : BorderDirectional(
                    start: BorderSide(
                      color: domainAccent.withValues(alpha: .12),
                      width: 1,
                    ),
                  ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : size.height;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    minHeight: availableHeight,
                  ),
                  child: Padding(
                    key: const ValueKey('premium-page-frame-content-padding'),
                    padding: padding.copyWith(
                      bottom: compactBottomPadding + bottomInset,
                    ),
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      label: page?.spec.title(context),
                      child: Material(
                        type: MaterialType.transparency,
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class PremiumIconButton extends StatelessWidget {
  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.selected = false,
    this.semanticsIdentifier,
    this.targetSize = HopeV2Touch.minimum,
  });

  final Object icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool selected;

  /// Stable native-accessibility/test identifier for this action.
  final String? semanticsIdentifier;
  final double targetSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null;
    final foreground = enabled
        ? (selected ? base : Theme.of(context).colorScheme.onSurface)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final background = selected
        ? base.withValues(
            alpha: dark ? .14 : .10,
          )
        : HopeV2Surfaces.panel(context);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        selected: selected,
        identifier: semanticsIdentifier,
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(HopeV2Radii.button),
          child: Ink(
            width: targetSize,
            height: targetSize,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(HopeV2Radii.button),
              border: Border.all(
                color: selected
                    ? base.withValues(alpha: dark ? .26 : .18)
                    : HopeV2Surfaces.border(context),
              ),
            ),
            child: Center(
              child: HopeIcon(
                icon,
                size: 21,
                color: foreground,
                strokeWidth: 1.9,
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class PremiumQuickAction {
  const PremiumQuickAction({
    required this.label,
    required this.icon,
    this.onPressed,
    this.primary = false,
    this.primaryActionColor,
    this.semanticLabel,
  });

  final String label;
  final Object icon;
  final VoidCallback? onPressed;
  final bool primary;
  /// Optional fill override for an individually marked primary action.
  final Color? primaryActionColor;
  final String? semanticLabel;
}

class _PremiumQuickActionButton extends StatelessWidget {
  const _PremiumQuickActionButton({
    required this.action,
    required this.accent,
  });

  final PremiumQuickAction action;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = action.onPressed != null;
    final foreground = enabled
        ? (action.primary
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final primaryAccent = action.primaryActionColor ?? accent;
    final background = action.primary
        ? primaryAccent.withValues(alpha: dark ? .92 : .96)
        : Colors.transparent;

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.semanticLabel ?? action.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? action.onPressed : null,
          borderRadius: BorderRadius.circular(HopeV2Radii.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(HopeV2Radii.md),
              border: Border.all(
                color: action.primary
                    ? primaryAccent.withValues(alpha: dark ? .30 : .20)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HopeIcon(
                  action.icon,
                  size: 18,
                  color: action.primary ? foreground : accent,
                  strokeWidth: 1.9,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      height: 1.05,
                      fontWeight:
                          action.primary ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class PremiumQuickActionStrip extends StatelessWidget {
  const PremiumQuickActionStrip({
    super.key,
    required this.title,
    required this.actions,
    this.subtitle,
    this.domain,
    this.page,
    this.glass = true,
    this.quiet = false,
  });

  final String title;
  final String? subtitle;
  final List<PremiumQuickAction> actions;
  final HopeProductDomain? domain;
  final HopePageId? page;
  final bool glass;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final resolvedDomain = domain ?? page?.spec.domain;
    final accent =
        resolvedDomain?.spec.accentFor(context) ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      container: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (resolvedDomain != null) ...[
                PremiumDomainMarker(domain: resolvedDomain, compact: true),
                const SizedBox(width: HopeV2Spacing.sm),
              ],
              Expanded(
                child: Text(
                  title,
                  style: HopeV2Type.section(context).copyWith(
                    color: resolvedDomain == null ? null : HopeV2SemanticColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: HopeV2Spacing.sm),
          Wrap(
            spacing: HopeV2Spacing.xs,
            runSpacing: HopeV2Spacing.xs,
            children: [
              for (final action in actions)
                _PremiumQuickActionButton(
                  action: action,
                  accent: accent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumDomainMarker extends StatelessWidget {
  const PremiumDomainMarker({
    super.key,
    required this.domain,
    this.compact = false,
  });

  final HopeProductDomain domain;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spec = domain.spec;
    final accent = spec.accentFor(context);
    final size = compact ? 26.0 : 36.0;
    return Semantics(
      container: true,
      label: spec.label(context),
      child: Container(
        constraints: BoxConstraints(
          minHeight: size,
          minWidth: size,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(compact ? 8 : HopeV2Radii.button),
          border: Border.all(
            color: accent.withValues(alpha: compact ? .13 : .18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HopeIcon(spec.icon, size: compact ? 16 : 18, color: accent, strokeWidth: 1.9),
            if (!compact) ...[
              const SizedBox(width: 6),
              Text(
                spec.label(context),
                style: HopeV2Type.eyebrow(context).copyWith(color: HopeV2SemanticColors.textSecondary(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PremiumDomainNavigationGroup extends StatelessWidget {
  const PremiumDomainNavigationGroup({
    super.key,
    required this.domain,
    required this.children,
    this.compact = false,
  });

  final HopeProductDomain domain;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spec = domain.spec;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : HopeV2Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PremiumDomainMarker(domain: domain, compact: true),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spec.label(context),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: HopeV2SemanticColors.textPrimary(context),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
          PremiumPanel(
            quiet: true,
            glass: false,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class PremiumHeader extends StatelessWidget {
  const PremiumHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.titleKey,
    this.subtitle,
    this.subtitleKey,
    this.trailing,
    this.domain,
    this.page,
    this.dense = false,
  });

  final String eyebrow;
  final String title;
  final Key? titleKey;
  final String? subtitle;
  final Key? subtitleKey;
  final Widget? trailing;
  final HopeProductDomain? domain;
  final HopePageId? page;
  final bool dense;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < HopeV2Breakpoints.medium;
          final resolvedDomain = domain ?? page?.spec.domain;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: titleKey,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: HopeV2Type.display(context).copyWith(
                  fontSize: compact ? 19.5 : 25.5,
                  height: compact ? 1.12 : 1.08,
                  letterSpacing: compact ? -.25 : -.65,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  key: subtitleKey,
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? HopeV2Colors.darkMuted
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: compact ? 13 : null,
                        height: compact ? 1.34 : 1.42,
                      ),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (eyebrow.trim().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (resolvedDomain != null) ...[
                        PremiumDomainMarker(
                          domain: resolvedDomain,
                          compact: true,
                        ),
                        const SizedBox(width: HopeV2Spacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          eyebrow.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: HopeV2Type.eyebrow(context).copyWith(
                            color: HopeV2SemanticColors.readableAccent(
                              context,
                              resolvedDomain?.spec.accentFor(context) ??
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (eyebrow.trim().isNotEmpty) SizedBox(height: dense ? 2 : 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    if (trailing != null) ...[
                      const SizedBox(width: HopeV2Spacing.sm),
                      trailing!,
                    ],
                  ],
                ),
              ],
            );
          }

          final editorial = Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: titleBlock),
              if (trailing != null) ...[
                const SizedBox(width: HopeV2Spacing.lg),
                trailing!,
              ],
            ],
          );

          if (resolvedDomain == null || eyebrow.trim().isEmpty) return editorial;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PremiumDomainMarker(domain: resolvedDomain, compact: true),
                  const SizedBox(width: HopeV2Spacing.sm),
                  Text(
                    eyebrow.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: HopeV2Type.eyebrow(context).copyWith(
                      color: HopeV2SemanticColors.readableAccent(
                        context,
                        resolvedDomain.spec.accentFor(context),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: dense ? 4 : 6),
              editorial,
            ],
          );
        },
      );
}

class PremiumPanel extends StatelessWidget {
  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HopeV2Spacing.lg),
    this.radius = HopeV2Radii.lg,
    this.highlight = false,
    this.glass = false,
    this.quiet = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool highlight;
  final bool glass;

  /// Secondary surface with reduced containment/chrome.
  final bool quiet;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    // Compact default panels use a denser 12dp inset; explicitly tuned feature
    // panels retain their own values so existing layouts stay intentional.
    final effectivePadding =
        compact && padding == const EdgeInsets.all(HopeV2Spacing.lg)
            ? const EdgeInsets.all(12)
            : padding;
    final panelFill = dark
        ? (glass
            ? HopeV2Colors.panelSoftDark.withValues(alpha: .74)
            : HopeV2Colors.panelDark.withValues(alpha: .82))
        : (glass
            ? HopeV2Colors.panelSoftLight
            : HopeV2Surfaces.panel(context));
    final gradient = highlight
        ? LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: dark
                ? [
                    HopeV2Colors.primary.withValues(alpha: glass ? .13 : .075),
                    HopeV2Colors.primary.withValues(alpha: glass ? .04 : .018),
                    HopeV2Surfaces.panel(context).withValues(alpha: glass ? .74 : 1),
                  ]
                : [
                    scheme.primary.withValues(alpha: glass ? .10 : .07),
                    HopeV2Surfaces.panel(context).withValues(alpha: glass ? .76 : 1),
                    HopeV2Surfaces.panel(context).withValues(alpha: glass ? .84 : 1),
                  ],
            stops: const [0, .52, 1],
          )
        : null;

    final panel = Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: highlight
            ? null
            : quiet
                ? HopeV2Surfaces.panelSoft(context)
                : (glass ? panelFill : HopeV2Surfaces.panel(context)),
        gradient: gradient,
        borderRadius: BorderRadius.circular(quiet ? HopeV2Radii.md : radius),
        border: Border.all(
          color: quiet
              ? Colors.transparent
              : highlight
                  ? scheme.primary.withValues(alpha: dark ? .15 : .14)
                  : (dark
                      ? Colors.white.withValues(alpha: glass ? .05 : .035)
                      : HopeV2Surfaces.border(context).withValues(alpha: .52)),
          width: 1,
        ),
        boxShadow: quiet
            ? const []
            : dark
                ? [
                    if (highlight)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .09),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    if (highlight)
                      BoxShadow(
                        color: HopeV2Colors.primary.withValues(alpha: glass ? .05 : .025),
                        blurRadius: glass ? 14 : 10,
                        offset: const Offset(0, 3),
                      ),
                    if (glass)
                      BoxShadow(
                        color: HopeV2Colors.primary.withValues(alpha: .014),
                        blurRadius: 18,
                        offset: const Offset(-3, 4),
                      ),
                  ]
            : [
                BoxShadow(
                  color: highlight
                      ? HopeV2Colors.warmHalo.withValues(alpha: .04)
                      : const Color(0x041D2119),
                  blurRadius: highlight ? 12 : 9,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(quiet ? HopeV2Radii.md : radius),
      child: panel,
    );

    return semanticLabel == null
        ? content
        : Semantics(
            container: true,
            explicitChildNodes: true,
            label: semanticLabel,
            child: content,
          );
  }
}

class _HeroEditorialFallback extends StatelessWidget {
  const _HeroEditorialFallback({
    required this.accent,
    required this.icon,
    this.compact = false,
  });

  final Color accent;
  final Object? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final heroGradient =
        dark ? HopeV2Gradients.heroDark : HopeV2Gradients.hero;
    final accentWash = accent.withValues(alpha: dark ? .08 : .045);

    if (compact) {
      return DecoratedBox(
        key: const ValueKey('premium-hero-compact-fallback'),
        decoration: BoxDecoration(gradient: heroGradient),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: AlignmentDirectional.topEnd,
              radius: 1.2,
              colors: [accentWash, Colors.transparent],
              stops: const [0, .82],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: heroGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: AlignmentDirectional.topEnd,
                  radius: 1.2,
                  colors: [accentWash, Colors.transparent],
                  stops: const [0, .82],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: -30,
            top: -22,
            child: Container(
              width: 240,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                color: Colors.white.withValues(alpha: .035),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .10),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: 28,
            top: 8,
            child: Container(
              width: 148,
              height: 1,
              color: Colors.white.withValues(alpha: .12),
            ),
          ),
          PositionedDirectional(
            end: 48,
            top: 34,
            child: Container(
              width: 104,
              height: 1,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          PositionedDirectional(
            start: -42,
            bottom: -52,
            child: Container(
              width: 190,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                color: HopeV2Colors.secondary.withValues(alpha: .055),
                border: Border.all(
                  color: HopeV2Colors.secondary.withValues(alpha: .10),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 20,
            bottom: 26,
            child: Container(
              width: 130,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .08),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 32,
            bottom: 38,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: .72),
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  width: 58,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
          if (icon != null)
            Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .13),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .18),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: HopeIcon(
                    icon!,
                    color: Colors.white,
                    size: 28,
                    strokeWidth: 2.0,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topCenter,
                  end: AlignmentDirectional.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .12),
                    Colors.black.withValues(alpha: .62),
                  ],
                  stops: const [0, .48, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumHero extends StatelessWidget {
  const PremiumHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    this.action,
    this.icon,
    this.mediaUrl,
    this.height = 200,
    this.compactHero = false,
    this.semanticLabel,
    this.domain,
    this.page,
    this.expandForAccessibilityText = false,
  });
  final String eyebrow;
  final String title;
  final String message;
  final Widget? action;
  final Object? icon;
  /// Optional real product media used as the hero composition.
  /// When absent, the canonical HOPE gradient remains the fallback.
  final String? mediaUrl;
  final double height;
  final bool compactHero;
  final String? semanticLabel;
  final HopeProductDomain? domain;
  final HopePageId? page;
  /// Lets a long title grow naturally only when users enlarge system text.
  final bool expandForAccessibilityText;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final accessibilityTitleExpansion = expandForAccessibilityText &&
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final resolvedDomain = domain ?? page?.spec.domain;
    // Editorial density is content-aware: informational heroes without an
    // action should not reserve the same vertical budget as a conversion hero.
    // Explicit short bands survive, while oversized caller values are capped.
    final maxHeroHeight = compactHero
        ? 148.0
        : action != null
            ? (compact ? 184.0 : 208.0)
            : message.trim().isEmpty
                ? (compact ? 132.0 : 152.0)
                : (compact ? 164.0 : 184.0);
    final minHeroHeight = compactHero ? 88.0 : (compact ? 112.0 : 152.0);
    final heroHeight = height.clamp(minHeroHeight, maxHeroHeight).toDouble();
    final horizontal = compactHero
        ? HopeV2Spacing.md
        : compact
            ? HopeV2Spacing.md
            : HopeV2Spacing.xl;

    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: Container(
        height: accessibilityTitleExpansion ? null : heroHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HopeV2Radii.hero),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? HopeV2Shadows.heroDark
              : HopeV2Shadows.hero,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: accessibilityTitleExpansion
              ? StackFit.loose
              : StackFit.expand,
          children: [
            if (mediaUrl != null && mediaUrl!.trim().isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  mediaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: Theme.of(context).brightness == Brightness.dark
                          ? HopeV2Gradients.heroDark
                          : HopeV2Gradients.hero,
                    ),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: _HeroEditorialFallback(
                  accent: resolvedDomain?.spec.accentFor(context) ??
                      Theme.of(context).colorScheme.primary,
                  icon: compactHero ? null : icon,
                  compact: compactHero,
                ),
              ),
            if (mediaUrl != null && mediaUrl!.trim().isNotEmpty)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topCenter,
                      end: AlignmentDirectional.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .10),
                        Colors.black.withValues(alpha: .18),
                        Colors.black.withValues(alpha: .72),
                      ],
                      stops: const [0, .42, 1],
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
                end: compact ? -84 : -48,
                top: compact ? -76 : -54,
                width: compact ? 136 : 164,
                height: compact ? 136 : 164,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: .14),
                          Colors.white.withValues(alpha: .0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: compact ? -92 : -56,
                bottom: compact ? -108 : -84,
                width: compact ? 152 : 180,
                height: compact ? 152 : 180,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          // Keep the generic brand bloom indigo-tinted; domain accents stay in the Hero artwork.
                          Theme.of(context).brightness == Brightness.dark
                              ? HopeV2Colors.primary.withValues(alpha: .055)
                              : HopeV2Colors.warmHalo.withValues(alpha: .05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (icon != null && !compactHero)
              PositionedDirectional(
                end: horizontal,
                top: horizontal,
                child: ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(HopeV2Radii.iconTile),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .16),
                      ),
                    ),
                    child: icon is IconData
                        ? Icon(icon as IconData, color: Colors.white, size: 24)
                        : HugeIcon(
                            icon: icon as List<List>,
                            color: Colors.white,
                            size: 24,
                            strokeWidth: 2.0,
                          ),
                  ),
                ),
              ),
            Positioned(
              right: -52,
              top: -62,
              child: ExcludeSemantics(
                child: Container(
                  width: 164,
                  height: 164,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .10)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontal,
                // Compact auth heroes have short fixed heights; the full-size
                // vertical gutter can force wrapped copy to overflow at 360dp.
                vertical: compactHero ? 4 : (compact ? (action != null ? 10 : 12) : 16),
              ),
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dense = constraints.maxHeight < 340;
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (resolvedDomain != null && !compactHero)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: resolvedDomain.spec.accentFor(context).withValues(alpha: .18),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: resolvedDomain.spec.accentFor(context).withValues(alpha: .34),
                                      ),
                                    ),
                                    child: Center(
                                      child: HopeIcon(
                                        resolvedDomain.spec.icon,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      resolvedDomain.spec.label(context),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: HopeV2Colors.darkText,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!compactHero)
                            Text(
                            eyebrow.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              letterSpacing: .7,
                            ),
                          ),
                          SizedBox(
                            height: dense ? 4 : HopeV2Spacing.sm,
                          ),
                          Text(
                            title,
                            maxLines: accessibilityTitleExpansion
                                ? null
                                : (compactHero ? 2 : (dense ? 2 : 3)),
                            softWrap: true,
                            overflow: accessibilityTitleExpansion
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compactHero ? 19 : (dense ? 20 : 21),
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6,
                            ),
                          ),
                          if (message.trim().isNotEmpty) ...[
                            SizedBox(
                              height: dense ? 5 : HopeV2Spacing.sm,
                            ),
                            Text(
                              message,
                              maxLines: compactHero ? 2 : (dense ? 2 : 3),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                height: dense ? 1.34 : 1.48,
                              ),
                            ),
                          ],
                          if (action != null) ...[
                            SizedBox(
                              height: dense ? 9 : HopeV2Spacing.lg,
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: HopeV2Touch.minimum,
                              ),
                              child: action!,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumStatCard extends StatelessWidget {
  const PremiumStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    this.caption,
    this.highlight = false,
    this.compact = false,
  });

  final String label;
  final String value;
  final Object icon;
  final Color? accent;
  final String? caption;
  final bool compact;
  /// Focal stat surfaces may opt into the stronger gradient treatment.
  /// Ordinary support metrics stay quiet by default.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = dark
        ? HopeV2Colors.darkMuted
        : Theme.of(context).colorScheme.onSurfaceVariant;
    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final ultraCompact = constraints.maxWidth < 135;
          return PremiumPanel(
            semanticLabel: '$label: $value',
            quiet: !highlight,
            padding: EdgeInsets.symmetric(
              horizontal: ultraCompact ? 8 : 12,
              vertical: ultraCompact ? 8 : 9,
            ),
            highlight: highlight,
            child: ultraCompact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ExcludeSemantics(
                        child: HopeIconTile(
                          icon,
                          color: color,
                          filled: true,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: HopeV2Type.metric(context).copyWith(fontSize: 20),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      ExcludeSemantics(
                        child: HopeIconTile(
                          icon,
                          color: color,
                          filled: true,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HopeV2Type.metric(context)
                                  .copyWith(fontSize: 21),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      );
    }

    return PremiumPanel(
      semanticLabel: '$label: $value',
      quiet: !highlight,
      padding: const EdgeInsets.all(14),
      highlight: highlight,
      child: Row(
        children: [
          ExcludeSemantics(
            child: HopeIconTile(icon, color: color, filled: true, size: 42),
          ),
          const SizedBox(width: HopeV2Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                ),
                const SizedBox(height: 3),
                Text(value, style: HopeV2Type.metric(context)),
                if (caption != null)
                  Text(caption!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.domain,
    this.page,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final HopeProductDomain? domain;
  final HopePageId? page;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < HopeV2Breakpoints.compact;
          final resolvedDomain = domain ?? page?.spec.domain;
          final accent =
              resolvedDomain?.spec.accentFor(context) ?? Theme.of(context).colorScheme.primary;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (resolvedDomain != null && !compact)
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  if (resolvedDomain != null && !compact)
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: HopeV2Type.section(context).copyWith(
                        fontSize: compact ? 17 : 18,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? HopeV2Colors.darkMuted
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: compact ? 12.5 : 13,
                    height: 1.32,
                  ),
                ),
              ],
            ],
          );
          if (action == null) return content;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: HopeV2Spacing.xs),
                action!,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: content),
              const SizedBox(width: HopeV2Spacing.lg),
              action!,
            ],
          );
        },
      );
}

/// Shared, compact empty state for data-backed product surfaces.
class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.dense = false,
  });

  final Object icon;
  final String title;
  final String message;
  final Widget? action;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final accent = HopeV2IconAccents.resolve(
      icon,
      brightness: Theme.of(context).brightness,
    );
    return Semantics(
      container: true,
      child: PremiumPanel(
        glass: false,
        highlight: false,
        padding: EdgeInsets.all(dense ? 12 : (compact ? 16 : 20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HopeKineticGlyph(
              width: dense ? 44 : 52,
              height: dense ? 42 : 50,
              color: accent,
              child: HopeIcon(icon, size: dense ? 18 : 21, color: accent),
            ),
            SizedBox(height: dense ? 8 : 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: HopeV2Type.section(context).copyWith(
                fontSize: compact ? 16 : 17,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? HopeV2Colors.darkMuted
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            if (action != null) ...[
              SizedBox(height: dense ? 10 : 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class PremiumTag extends StatelessWidget {
  const PremiumTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.inverse = false,
    this.allowWrap = false,
  });

  final String label;
  final Object? icon;
  final Color? color;
  final bool inverse;
  /// Allows labels to grow naturally at enlarged accessibility text scales.
  /// Defaults to the compact one-line contract for existing callers.
  final bool allowWrap;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = inverse ? Colors.white : HopeV2SemanticColors.textPrimary(context);
    final iconForeground = inverse ? Colors.white : base;
    final background = inverse
        ? Colors.white.withValues(alpha: .10)
        : base.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .055 : .07,
          );
    return Semantics(
      label: label,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(HopeV2Radii.chip),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: icon is IconData
                    ? Icon(icon as IconData, size: 14, color: iconForeground)
                    : HugeIcon(
                        icon: icon as List<List>,
                        size: 14,
                        color: iconForeground,
                        strokeWidth: 1.9,
                      ),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: allowWrap ? null : 1,
                softWrap: allowWrap,
                overflow: allowWrap
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumFilterChip extends StatelessWidget {
  const PremiumFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
    this.enabled = true,
    this.loading = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Object? icon;
  final Color? color;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final interactive = enabled && !loading;
    final base = color ?? Theme.of(context).colorScheme.primary;
    final foreground = interactive
        ? HopeV2SemanticColors.textPrimary(context)
        : HopeV2SemanticColors.textSecondary(context);

    return Semantics(
      button: true,
      selected: selected,
      enabled: interactive,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: interactive ? onTap : null,
          borderRadius: BorderRadius.circular(HopeV2Radii.chip),
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : HopeV2Motion.fast,
            constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? (base == HopeV2Colors.primary ||
                          base == HopeV2Colors.primaryAction ||
                          base == HopeV2Colors.primaryDark
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? HopeV2Colors.primaryTintDark
                          : HopeV2Colors.primaryTintLight)
                      : base.withValues(alpha: interactive ? .08 : .04))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(HopeV2Radii.chip),
              border: Border.all(
                color: selected
                    ? (base == HopeV2Colors.primary ||
                            base == HopeV2Colors.primaryAction ||
                            base == HopeV2Colors.primaryDark
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? HopeV2Colors.primaryBorderDark
                            : HopeV2Colors.primaryBorderLight)
                        : base.withValues(alpha: interactive ? .22 : .10))
                    : HopeV2Surfaces.border(context).withValues(alpha: .18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  ExcludeSemantics(
                    child: reduceMotion
                        ? HopeIcon(
                            HopeV2Icons.pending,
                            size: 16,
                            color: foreground,
                            strokeWidth: 1.9,
                          )
                        : SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foreground,
                            ),
                          ),
                  )
                else if (icon != null)
                  HopeIcon(icon!, size: 16, color: foreground, strokeWidth: 1.9),
                if (loading || icon != null) const SizedBox(width: 5),
                if (!loading && selected) ...[
                  HopeIcon(
                    HopeV2Icons.completed,
                    size: 16,
                    color: foreground,
                    strokeWidth: 1.9,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    height: 1.05,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumSearchBar extends StatelessWidget {
  const PremiumSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.onFilter,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HopeV2Radii.md),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x081B1638),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: SearchField(
            onChanged: onChanged,
            onFilter: onFilter,
            hint: hint,
          ),
        ),
      );
}
    
/// Compact decision surface for opportunity-first screens.
class HopeOpportunityDecisionStrip extends StatelessWidget {
  const HopeOpportunityDecisionStrip({
    super.key,
    required this.matchScore,
    required this.budget,
    required this.category,
    required this.location,
    required this.kind,
    this.accent,
    this.highlightHighScore = true,
    this.breakdown = const <String, double>{},
    this.recommendationReasons = const <String>[],
  });

  final double? matchScore;
  final String budget;
  final String category;
  final String location;
  final String kind;
  final Color? accent;
  final bool highlightHighScore;
  final Map<String, double> breakdown;
  final List<String> recommendationReasons;

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _label(BuildContext context, String key) => switch (key) {
        'skills' => _t(context, 'مهارت', 'Skills'),
        'category' => _t(context, 'دسته‌بندی', 'Category'),
        'location' => _t(context, 'مکان', 'Location'),
        'salary' => _t(context, 'درآمد', 'Salary'),
        'experience' => _t(context, 'تجربه', 'Experience'),
        _ => key,
      };

  double _normalized(String key) {
    final raw = breakdown[key];
    if (raw == null) return 0;
    return (raw <= 1 ? raw : raw / 100).clamp(0.0, 1.0).toDouble();
  }

  bool get hasBreakdown =>
      const ['skills', 'category', 'location', 'salary']
          .any((key) => breakdown.containsKey(key));

  @override
  Widget build(BuildContext context) {
    final primary = accent ?? Theme.of(context).colorScheme.primary;
    final chartColor = HopeV2ChartColors.matchSignal(context);
    final scoreForeground = HopeV2SemanticColors.info(context);
    final neutralForeground = HopeV2SemanticColors.textSecondary(context);
    final compact = MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final scoreRingSize = enlargedText ? 78.0 : 56.0;
    final normalizedScore =
        HopeDisplayFormatter.matchPercentage(matchScore);
    final score = normalizedScore?.round();
    final locale = Localizations.localeOf(context).languageCode;
    final scoreLabel = score == null ? '—' : HopeDisplayFormatter.percent(score, locale: locale);
    final rationaleLabel =
        hopeFirstRecommendationReasonLabel(context, recommendationReasons);
    final matchRationaleTag = rationaleLabel == null
        ? null
        : PremiumTag(
            key: const ValueKey('opportunity-decision-match-rationale'),
            icon: HopeV2Icons.insights,
            label: rationaleLabel,
            color: HopeV2Colors.secondary,
          );

    Widget fact(String label, String value, Object icon, Color color) {
      if (value.trim().isEmpty || value.trim() == '—') {
        return const SizedBox.shrink();
      }
      return Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(HopeV2Radii.sm),
          border: Border.all(color: color.withValues(alpha: .09)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HopeIcon(icon, size: 16, color: color, strokeWidth: 1.8),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: enlargedText ? null : 1,
                    softWrap: true,
                    overflow: enlargedText
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? HopeV2Colors.darkMuted
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    maxLines: enlargedText ? null : (compact ? 2 : 1),
                    softWrap: true,
                    overflow: enlargedText
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget breakdownBar(String key, {required double width}) {
      final value = _normalized(key);
      final percent = (value * 100).round();
      final locale = Localizations.localeOf(context).languageCode;
      return Semantics(
        key: ValueKey('opportunity-decision-breakdown-$key'),
        container: true,
        label: '${_label(context, key)}: ${HopeDisplayFormatter.percent(percent, locale: locale)}',
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(context, key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? HopeV2Colors.darkMuted
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    HopeDisplayFormatter.percent(percent, locale: locale),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scoreForeground,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: value,
                  backgroundColor: HopeV2Surfaces.border(context).withValues(alpha: .32),
                  valueColor: AlwaysStoppedAnimation<Color>(chartColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget breakdownRail() {
      if (!hasBreakdown) return const SizedBox.shrink();
      const ordered = ['skills', 'category', 'location', 'salary'];
      final items = ordered.where((key) => breakdown.containsKey(key));
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = compact
              ? (constraints.maxWidth - 12) / 2
              : 240.0;
          return Wrap(
            spacing: compact ? 12 : 20,
            runSpacing: compact ? 7 : 10,
            children: [
              for (final key in items)
                breakdownBar(key, width: itemWidth),
            ],
          );
        },
      );
    }

    return Semantics(
      container: true,
      label: _t(context, 'خلاصه تصمیم فرصت', 'Opportunity decision summary'),
      child: PremiumPanel(
        key: const ValueKey('opportunity-decision-strip'),
        // The page can suppress the indigo wash while retaining the compact
        // decision hierarchy; the score is carried by the teal data series.
        highlight: highlightHighScore && score != null && score >= 90,
        padding: EdgeInsets.fromLTRB(
          compact ? 9 : 12,
          compact ? 7 : 11,
          compact ? 9 : 12,
          compact ? 7 : 11,
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kind,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: neutralForeground,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .4,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _t(context, 'برای تصمیم سریع', 'Quick decision'),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            if (compact &&
                                !enlargedText &&
                                ((location.trim().isNotEmpty &&
                                        location.trim() != '—') ||
                                    matchRationaleTag != null)) ...[
                              const SizedBox(height: 3),
                              Wrap(
                                spacing: 6,
                                runSpacing: 3,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (location.trim().isNotEmpty &&
                                      location.trim() != '—')
                                    Row(
                                      key: const ValueKey(
                                        'opportunity-decision-location-inline',
                                      ),
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const HopeIcon(
                                          HopeV2Icons.location,
                                          size: 13,
                                          color: HopeV2Colors.secondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Semantics(
                                            label: '${_t(context, 'مکان', 'Location')}: ${location.trim()}',
                                            child: ExcludeSemantics(
                                              child: Text(
                                                location.trim(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: neutralForeground,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (matchRationaleTag != null) matchRationaleTag,
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (score != null)
                        SizedBox(
                          key: const ValueKey('opportunity-match-score-ring'),
                          width: scoreRingSize,
                          height: scoreRingSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: score / 100,
                                  strokeWidth: 4,
                                  backgroundColor: HopeV2Surfaces.border(context)
                                      .withValues(alpha: .42),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(chartColor),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    scoreLabel,
                                    style: HopeV2Type.metric(context).copyWith(
                                      color: scoreForeground,
                                      fontSize: enlargedText ? 14 : 17,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _t(context, 'تطبیق', 'match'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: scoreForeground,
                                          fontWeight: FontWeight.w800,
                                          fontSize: enlargedText ? 10 : null,
                                          height: enlargedText ? 1 : null,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (enlargedText)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        fact(
                          _t(context, 'بودجه', 'Budget'),
                          budget,
                          HopeV2Icons.payments,
                          primary,
                        ),
                        const SizedBox(height: 6),
                        fact(
                          _t(context, 'دسته‌بندی', 'Category'),
                          category,
                          HopeV2Icons.category,
                          HopeV2Colors.secondary,
                        ),
                        const SizedBox(height: 6),
                        fact(
                          _t(context, 'مکان', 'Location'),
                          location,
                          HopeV2Icons.location,
                          HopeV2Colors.secondary,
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        fact(_t(context, 'بودجه', 'Budget'), budget, HopeV2Icons.payments, primary),
                        fact(_t(context, 'دسته‌بندی', 'Category'), category, HopeV2Icons.category, HopeV2Colors.secondary),
                        if (!compact || enlargedText)
                          fact(_t(context, 'مکان', 'Location'), location, HopeV2Icons.location, HopeV2Colors.secondary),
                      ],
                    ),
                  if (matchRationaleTag != null &&
                      (!compact || enlargedText)) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: matchRationaleTag,
                    ),
                  ],
                  if (hasBreakdown) ...[
                    const SizedBox(height: 6),
                    Text(
                      _t(context, 'شاخص‌های تطبیق', 'Match signals'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: HopeV2Colors.darkMuted,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    breakdownRail(),
                  ],
                ],
              )
            : Row(
                children: [
                  if (score != null) ...[
                    Container(
                      constraints: const BoxConstraints(minWidth: 70, minHeight: 60),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: chartColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(HopeV2Radii.md),
                        border: Border.all(color: chartColor.withValues(alpha: .22)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(scoreLabel, style: HopeV2Type.metric(context).copyWith(color: scoreForeground, fontSize: 24)),
                          Text(_t(context, 'تطبیق', 'match'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scoreForeground)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            fact(_t(context, 'نوع', 'Type'), kind, HopeV2Icons.job, primary),
                            fact(_t(context, 'بودجه', 'Budget'), budget, HopeV2Icons.payments, primary),
                            fact(_t(context, 'دسته‌بندی', 'Category'), category, HopeV2Icons.category, HopeV2Colors.secondary),
                            fact(_t(context, 'مکان', 'Location'), location, HopeV2Icons.location, HopeV2Colors.secondary),
                          ],
                        ),
                        if (matchRationaleTag != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: matchRationaleTag,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Five-step composition marker for the Create Opportunity flow.
class HopeCreationProgress extends StatelessWidget {
  const HopeCreationProgress({super.key, this.activeIndex = 0});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    const labelsFa = ['نوع', 'جزئیات', 'مبلغ', 'شرایط', 'بازبینی'];
    const labelsEn = ['Type', 'Details', 'Budget', 'Criteria', 'Review'];
    const persianDigits = ['۱', '۲', '۳', '۴', '۵'];
    final en = Localizations.localeOf(context).languageCode == 'en';
    final safeIndex = activeIndex.clamp(0, labelsFa.length - 1).toInt();
    final currentStep = en
        ? 'Step ${safeIndex + 1} of ${labelsEn.length}'
        : 'مرحله ${persianDigits[safeIndex]} از ۵';

    return Semantics(
      container: true,
      liveRegion: true,
      label: en
          ? 'Create opportunity progress, $currentStep, ${labelsEn[safeIndex]}'
          : 'پیشرفت ثبت فرصت، $currentStep، ${labelsFa[safeIndex]}',
      value: en ? labelsEn[safeIndex] : labelsFa[safeIndex],
      child: Container(
        key: const ValueKey('create-opportunity-progress'),
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 2,
                end: 2,
                bottom: 5,
              ),
              child: Text(
                currentStep,
                key: const ValueKey('create-opportunity-current-step-label'),
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: HopeV2SemanticColors.textPrimary(context),
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Row(
              children: [
                for (var step = 0; step < labelsFa.length; step++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: step == labelsFa.length - 1 ? 0 : 5,
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: step <= safeIndex
                                  ? Theme.of(context).colorScheme.primary
                                  : HopeV2Surfaces.border(context)
                                      .withValues(alpha: .6),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: step == safeIndex
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: .16)
                                  : Theme.of(context).colorScheme.surface,
                              border: Border.all(
                                color: step <= safeIndex
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: .32)
                                    : HopeV2Surfaces.border(context),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              en ? (step + 1).toString() : persianDigits[step],
                              style: TextStyle(
                                color: step <= safeIndex
                                    ? HopeV2SemanticColors.textPrimary(context)
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            en ? labelsEn[step] : labelsFa[step],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: step == safeIndex
                                      ? HopeV2SemanticColors.textPrimary(context)
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: step == safeIndex
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  fontSize: 9.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dense professional trust signals for first-fold identity surfaces.
class HopeTrustSignalRail extends StatelessWidget {
  const HopeTrustSignalRail({super.key, required this.signals});

  final List<({Object icon, String label, String value, Color color})> signals;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680
            ? signals.length.clamp(1, 4).toInt()
            : 2;
        const gap = 7.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final signal in signals)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  decoration: BoxDecoration(
                    color: signal.color.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(HopeV2Radii.md),
                    border: Border.all(color: signal.color.withValues(alpha: .14)),
                  ),
                  child: Row(
                    children: [
                      HopeIcon(signal.icon, size: 17, color: signal.color, strokeWidth: 1.8),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(signal.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).brightness == Brightness.dark ? HopeV2Colors.darkMuted : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            )),
                            const SizedBox(height: 1),
                            Text(signal.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

    
/// Compact lifecycle rail for mobile-first decision surfaces.
class HopeLifecycleRail extends StatelessWidget {
  const HopeLifecycleRail({
    super.key,
    required this.labels,
    required this.icons,
    required this.current,
  });

  final List<String> labels;
  final List<Object> icons;
  final int current;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || icons.length != labels.length) return const SizedBox.shrink();
    final safeCurrent = current.clamp(-1, labels.length - 1);
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).brightness == Brightness.dark
        ? HopeV2Colors.darkMuted
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      label: Localizations.localeOf(context).languageCode == 'en'
          ? 'Lifecycle progress'
          : 'پیشرفت چرخه',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < safeCurrent
                              ? primary
                              : i == safeCurrent
                                  ? primary.withValues(alpha: .14)
                                  : HopeV2Surfaces.panelSoft(context).withValues(alpha: .38),
                          border: Border.all(
                            color: i <= safeCurrent
                                ? primary.withValues(alpha: .38)
                                : HopeV2Surfaces.border(context),
                          ),
                        ),
                        child: HopeIcon(
                          i < safeCurrent ? HopeV2Icons.completed : icons[i],
                          size: i < safeCurrent ? 14 : 13,
                          color: i < safeCurrent
                              ? Theme.of(context).colorScheme.onPrimary
                              : (i == safeCurrent ? primary : muted),
                          strokeWidth: 1.9,
                        ),
                      ),
                    ),
                  ),
                  if (i != labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < safeCurrent
                            ? primary.withValues(alpha: .52)
                            : HopeV2Surfaces.border(context).withValues(alpha: .68),
                      ),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        labels[i],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              height: 1.05,
                              fontWeight: i == safeCurrent ? FontWeight.w900 : FontWeight.w700,
                              color: i <= safeCurrent ? HopeV2SemanticColors.textPrimary(context) : muted,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
