import 'package:flutter/material.dart';
import '../theme/hope_v2_design.dart';
import 'components.dart';

/// Shared page shell. Every V2 flagship surface should use this instead of
/// inventing its own max-width, page padding, or bottom safe-area behavior.
/// Canonical mobile navigation surface for the HOPE shell.
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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .96),
        border: Border(
          top: BorderSide(color: HopeV2Surfaces.border(context)),
        ),
        boxShadow: HopeV2Shadows.card,
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
          height: 80,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: scheme.primary.withValues(alpha: .12),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .96),
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
          minWidth: 88,
          minExtendedWidth: 210,
          labelType: extended
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          leading: leading,
          trailing: trailing,
          backgroundColor: Colors.transparent,
          indicatorColor: scheme.primary.withValues(alpha: .12),
          useIndicator: true,
          groupAlignment: -.6,
        ),
      ),
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
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    final bottomInset = safeBottom ? MediaQuery.paddingOf(context).bottom : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(color: HopeV2Surfaces.page(context)),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: ExcludeSemantics(
              child: _BrandOrb(
                size: 250,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Positioned(
            top: 300,
            left: -130,
            child: ExcludeSemantics(
              child: _BrandOrb(
                size: 220,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: padding.copyWith(
                    bottom: padding.bottom + bottomInset,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _BrandOrb extends StatelessWidget {
  const _BrandOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: .12),
              color.withValues(alpha: .035),
              Colors.transparent,
            ],
          ),
        ),
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
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < HopeV2Breakpoints.compact;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(HopeV2Radii.pill),
                ),
                child: Text(
                  eyebrow.toUpperCase(),
                style: HopeV2Type.eyebrow(context).copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
                ),
              ),
              const SizedBox(height: HopeV2Spacing.sm),
              Text(title, style: HopeV2Type.display(context)),
              if (subtitle != null) ...[
                const SizedBox(height: HopeV2Spacing.sm),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ],
          );

          if (trailing == null) return content;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: HopeV2Spacing.lg),
                trailing!,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: content),
              const SizedBox(width: HopeV2Spacing.lg),
              trailing!,
            ],
          );
        },
      );
}

class PremiumPanel extends StatelessWidget {
  const PremiumPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HopeV2Spacing.xl),
    this.radius = HopeV2Radii.lg,
    this.highlight = false,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool highlight;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panel = Container(
      decoration: BoxDecoration(
        color: highlight
            ? (dark
                ? scheme.primary.withValues(alpha: .09)
                : scheme.primary.withValues(alpha: .055))
            : HopeV2Surfaces.panel(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlight
              ? scheme.primary.withValues(alpha: .20)
              : HopeV2Surfaces.border(context),
          width: highlight ? 1.1 : 1,
        ),
        boxShadow: dark
            ? const []
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
      padding: padding,
      child: Material(type: MaterialType.transparency, child: child),
    );
    return semanticLabel == null
        ? panel
        : Semantics(container: true, label: semanticLabel, child: panel);
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
    this.height = 280,
    this.semanticLabel,
  });
  final String eyebrow;
  final String title;
  final String message;
  final Widget? action;
  final IconData? icon;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < HopeV2Breakpoints.compact;
    final heroHeight = compact
        ? height.clamp(300.0, 420.0).toDouble()
        : (height < 344 ? 344.0 : height);
    final horizontal = compact ? HopeV2Spacing.lg : HopeV2Spacing.xxl;

    return Semantics(
      container: true,
      label: semanticLabel ?? title,
      child: Container(
        height: heroHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(HopeV2Radii.hero),
          boxShadow: HopeV2Shadows.hero,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ],
                ),
              ),
            ),
            if (icon != null)
              PositionedDirectional(
                end: horizontal,
                top: horizontal,
                child: ExcludeSemantics(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .16),
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
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
                            maxLines: dense ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: dense ? 27 : 31,
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
                            maxLines: dense ? 2 : 4,
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
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return PremiumPanel(
      semanticLabel: '$label: $value',
      padding: const EdgeInsets.all(HopeV2Spacing.lg),
      child: Row(
        children: [
          ExcludeSemantics(
            child: HopeIconTile(icon, color: color, filled: true, size: 46),
          ),
          const SizedBox(width: HopeV2Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 3),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
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
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < HopeV2Breakpoints.compact;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HopeV2Type.section(context)),
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
  final IconData? icon;
  final Color? color;
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Theme.of(context).colorScheme.primary;
    final foreground = inverse ? Colors.white : base;
    final background = inverse
        ? Colors.white.withValues(alpha: .12)
        : base.withValues(alpha: .10);
    return Semantics(
      label: label,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(HopeV2Radii.pill),
          border: Border.all(
            color: inverse ? Colors.white24 : base.withValues(alpha: .08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(child: Icon(icon, size: 14, color: foreground)),
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
                  fontWeight: FontWeight.w900,
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
  final IconData? icon;
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
          borderRadius: BorderRadius.circular(HopeV2Radii.pill),
          child: AnimatedContainer(
            duration: reduceMotion ? Duration.zero : HopeV2Motion.fast,
            constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? base.withValues(alpha: interactive ? .11 : .05)
                  : HopeV2Surfaces.panel(context),
              borderRadius: BorderRadius.circular(HopeV2Radii.pill),
              border: Border.all(
                color: selected
                    ? base.withValues(alpha: interactive ? .28 : .12)
                    : HopeV2Surfaces.border(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  ExcludeSemantics(
                    child: Icon(
                      reduceMotion ? Icons.hourglass_empty_rounded : Icons.progress_activity_rounded,
                      size: 16,
                      color: foreground,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 16, color: foreground),
                if (loading || icon != null) const SizedBox(width: 5),
                if (!loading && selected) ...[
                  Icon(Icons.check_rounded, size: 16, color: foreground),
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
  Widget build(BuildContext context) => Semantics(
        textField: true,
        label: hint,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(HopeV2Radii.lg),
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
        ),
      );
}
