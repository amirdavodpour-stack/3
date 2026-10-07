export 'hope_product_architecture.dart';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/hope_v2_design.dart';

import 'components.dart';
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
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected
        ? (dark ? HopeV2Colors.primaryDark : primary)
        : (dark ? HopeV2Colors.darkMuted : HopeV2Colors.muted);

    return AnimatedContainer(
      duration: HopeV2Motion.fast,
      curve: Curves.easeOutCubic,
      width: HopeV2Navigation.itemWidth,
      height: HopeV2Navigation.itemHeight,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final surface = HopeV2Surfaces.navigation(context);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        key: const ValueKey('hope-navigation-dock'),
        height: HopeV2Navigation.barHeight,
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
        decoration: BoxDecoration(
          color: dark
              ? HopeV2Colors.navigationDark.withValues(alpha: .985)
              : surface.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(HopeV2Navigation.dockRadius),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: .065)
                : HopeV2Surfaces.border(context).withValues(alpha: .75),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _PremiumNavigationItem(
                  destination: destinations[index],
                  selected: index == selectedIndex,
                  onPressed: () => onDestinationSelected(index),
                  accent: primary,
                ),
              ),
          ],
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
    required this.accent,
  });

  final NavigationDestination destination;
  final bool selected;
  final VoidCallback onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icon = selected ? destination.selectedIcon : destination.icon;
    final labelColor = selected
        ? (dark ? HopeV2Colors.primaryDark : accent)
        : (dark ? HopeV2Colors.darkMuted : HopeV2Colors.muted);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(HopeV2Navigation.itemRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: dark ? .16 : .10) : Colors.transparent,
              borderRadius: BorderRadius.circular(HopeV2Navigation.itemRadius),
              border: selected
                  ? Border.all(
                      color: accent.withValues(alpha: dark ? .22 : .16),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: HopeV2Touch.minimum,
                    height: 28,
                    child: Center(child: icon),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                      height: 1.05,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
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
        icon: const HopeNavigationGlyph(icon: HopeV2Icons.home, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2Icons.home, selected: true),
        label: label('خانه', 'Home'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2Icons.search, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2Icons.search, selected: true),
        label: label('کاوش', 'Explore'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2Icons.activity, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2Icons.activitySelected, selected: true),
        label: label('کار', 'Work'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2Icons.wallet, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2Icons.wallet, selected: true),
        label: label('کیف پول', 'Wallet'),
      ),
      NavigationDestination(
        icon: const HopeNavigationGlyph(icon: HopeV2Icons.profile, selected: false),
        selectedIcon: const HopeNavigationGlyph(icon: HopeV2Icons.profile, selected: true),
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
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 96),
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
    final resolvedDomain = domain ?? page?.spec.domain;
    final domainAccent = resolvedDomain?.spec.accent;
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: padding.copyWith(
                  bottom: padding.bottom + bottomInset,
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
  });

  final Object icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool selected;

  /// Stable native-accessibility/test identifier for this action.
  final String? semanticsIdentifier;

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
            width: HopeV2Touch.minimum,
            height: HopeV2Touch.minimum,
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
    this.semanticLabel,
  });

  final String label;
  final Object icon;
  final VoidCallback? onPressed;
  final bool primary;
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
    final background = action.primary
        ? accent.withValues(alpha: dark ? .84 : .96)
        : (dark ? HopeV2Colors.panelSoftDark : HopeV2Colors.panelSoftLight)
            .withValues(alpha: dark ? .48 : .86);

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.semanticLabel ?? action.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? action.onPressed : null,
          borderRadius: BorderRadius.circular(HopeV2Radii.md),
          child: Ink(
            constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(HopeV2Radii.md),
              border: Border.all(
                color: action.primary
                    ? accent.withValues(alpha: dark ? .28 : .20)
                    : HopeV2Surfaces.border(context).withValues(alpha: .55),
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
                          action.primary ? FontWeight.w900 : FontWeight.w700,
                    ),
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
        resolvedDomain?.spec.accent ?? Theme.of(context).colorScheme.primary;

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
                    color: resolvedDomain == null ? null : accent,
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
            spacing: HopeV2Spacing.sm,
            runSpacing: HopeV2Spacing.sm,
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
    final accent = spec.accent;
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
                style: HopeV2Type.eyebrow(context).copyWith(color: accent),
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
                          color: spec.accent,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
          ),
          PremiumPanel(
            glass: true,
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
    this.subtitle,
    this.trailing,
    this.domain,
    this.page,
    this.dense = false,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
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
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: HopeV2Type.display(context).copyWith(
                  fontSize: compact ? 21 : 28,
                  height: 1.08,
                  letterSpacing: compact ? -.5 : -.75,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: compact ? 13 : null,
                        height: compact ? 1.3 : 1.42,
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
                            color: resolvedDomain?.spec.accent ??
                                Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (eyebrow.trim().isNotEmpty) SizedBox(height: dense ? 3 : 5),
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
                      color: resolvedDomain.spec.accent,
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
    this.radius = HopeV2Radii.xl,
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
    // Only default 16px panels tighten on compact mobile. Explicit page-specific
    // padding remains untouched so feature-level composition stays intentional.
    final effectivePadding =
        compact && padding == const EdgeInsets.all(HopeV2Spacing.lg)
            ? const EdgeInsets.all(14)
            : padding;
    final panelFill = dark
        ? (glass
            ? HopeV2Colors.panelSoftDark
            : (quiet
                ? HopeV2Colors.panelSoftDark
                : HopeV2Colors.panelDark))
        : (glass
            ? HopeV2Colors.panelSoftLight
            : (quiet
                ? HopeV2Colors.panelSoftLight.withValues(alpha: .72)
                : Colors.transparent));
    final gradient = highlight
        ? LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: dark
                ? [
                    scheme.primary.withValues(alpha: glass ? .13 : .075),
                    HopeV2Colors.secondary.withValues(alpha: glass ? .022 : .012),
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
                ? Colors.transparent
                : (glass ? panelFill : HopeV2Surfaces.panel(context)),
        gradient: gradient,
        borderRadius: BorderRadius.circular(quiet ? HopeV2Radii.md : radius),
        border: Border.all(
          color: quiet
              ? Colors.transparent
              : highlight
                  ? scheme.primary.withValues(alpha: dark ? .17 : .16)
                  : (dark
                      ? Colors.white.withValues(alpha: glass ? .065 : .04)
                      : HopeV2Surfaces.border(context)),
          width: 1,
        ),
        boxShadow: quiet
            ? const []
            : dark
                ? [
                if (highlight)
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: glass ? .05 : .035),
                    blurRadius: glass ? 22 : 18,
                    offset: const Offset(0, 9),
                  ),
                if (glass)
                  BoxShadow(
                    color: HopeV2Colors.secondary.withValues(alpha: .012),
                    blurRadius: 26,
                    offset: const Offset(-7, 12),
                  ),
              ]
            : [
                BoxShadow(
                  color: highlight
                      ? scheme.primary.withValues(alpha: .06)
                      : const Color(0x081B1638),
                  blurRadius: highlight ? 26 : 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
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
  });

  final Color accent;
  final Object? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: [
            accent.withValues(alpha: .22),
            const Color(0xFF151A31),
            const Color(0xFF080B13),
          ],
          stops: const [0, .42, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
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
    this.height = 264,
    this.compactHero = false,
    this.semanticLabel,
    this.domain,
    this.page,
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

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final resolvedDomain = domain ?? page?.spec.domain;
    final heroHeight = compactHero
        ? height.clamp(112.0, 300.0).toDouble()
        : compact
            // Standard mobile hero stays editorial while returning more first-fold
            // space to match, metadata, and the primary action.
            ? height.clamp(176.0, 300.0).toDouble()
            : (height < 280 ? 280.0 : height);
    final horizontal = compactHero
        ? HopeV2Spacing.md
        : compact
            ? HopeV2Spacing.lg
            : HopeV2Spacing.xxl;

    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: Container(
        height: heroHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HopeV2Radii.hero),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? HopeV2Shadows.heroDark
              : HopeV2Shadows.hero,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
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
                  accent: resolvedDomain?.spec.accent ??
                      Theme.of(context).colorScheme.primary,
                  icon: icon,
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
                width: compact ? 176 : 204,
                height: compact ? 176 : 204,
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
                width: compact ? 190 : 224,
                height: compact ? 190 : 224,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          // Runtime visual certification: hero lower ambient light stays violet-led.
                          HopeV2Colors.primary.withValues(
                            alpha: Theme.of(context).brightness == Brightness.dark
                                ? .09
                                : .07,
                          ),
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
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(HopeV2Radii.iconTile),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .16),
                      ),
                    ),
                    child: icon is IconData
                        ? Icon(icon as IconData, color: Colors.white, size: 28)
                        : HugeIcon(
                            icon: icon as List<List>,
                            color: Colors.white,
                            size: 28,
                            strokeWidth: 2.1,
                          ),
                  ),
                ),
              ),
            Positioned(
              right: -52,
              top: -62,
              child: ExcludeSemantics(
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: .10)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(horizontal),
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
                                      color: resolvedDomain.spec.accent.withValues(alpha: .18),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: resolvedDomain.spec.accent.withValues(alpha: .34),
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
                                        color: resolvedDomain.spec.accent,
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
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: .9,
                            ),
                          ),
                          SizedBox(
                            height: dense ? 5 : HopeV2Spacing.sm,
                          ),
                          Text(
                            title,
                            maxLines: compactHero ? 2 : (dense ? 2 : 3),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compactHero ? 20 : (dense ? 21 : 24),
                              height: 1.03,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.9,
                            ),
                          ),
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
    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final ultraCompact = constraints.maxWidth < 135;
          return PremiumPanel(
            semanticLabel: '$label: $value',
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
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
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
              resolvedDomain?.spec.accent ?? Theme.of(context).colorScheme.primary;
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
                        fontSize: compact ? 17 : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          );
          if (action == null) return content;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: HopeV2Spacing.sm),
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

class PremiumTag extends StatelessWidget {
  const PremiumTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.inverse = false,
  });

  final String label;
  final Object? icon;
  final Color? color;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = inverse ? Colors.white : (dark ? Colors.white : base);
    final background = inverse
        ? Colors.white.withValues(alpha: .12)
        : base.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .14 : .10,
          );
    return Semantics(
      label: label,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(HopeV2Radii.chip),
          border: Border.all(
            color: inverse
                ? Colors.white24
                : base.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .07,
                  ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: icon is IconData
                    ? Icon(icon as IconData, size: 14, color: foreground)
                    : HugeIcon(
                        icon: icon as List<List>,
                        size: 14,
                        color: foreground,
                        strokeWidth: 1.9,
                      ),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final foreground = interactive
        ? (selected ? base : Theme.of(context).colorScheme.onSurface)
        : muted;

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? base.withValues(alpha: interactive ? .08 : .04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(HopeV2Radii.chip),
              border: Border.all(
                color: selected
                    ? base.withValues(alpha: interactive ? .22 : .10)
                    : HopeV2Surfaces.border(context).withValues(alpha: .30),
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
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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