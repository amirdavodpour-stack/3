import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hope_l10n.dart';
import '../theme/hope_v2_design.dart';

/// Resolves the accessible secondary accent for the current brightness.
/// Text/icons in the brand teal need >= 4.5:1 against the surface they sit
/// on; the raw brand teal only passes on dark backgrounds, so light mode
/// uses a darker teal and dark mode a lighter one.
Color secondaryAccent(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? HopeV2Colors.secondaryDark
        : HopeV2Colors.secondaryStrong;

class AnimatedEntrance extends StatelessWidget {
  const AnimatedEntrance(
      {super.key,
      required this.child,
      this.delay = Duration.zero,
      this.offset = const Offset(0, .03)});
  final Widget child;
  final Duration delay;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    // Honor the system "reduce motion" preference: skip the entrance
    // animation and show the content immediately.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) {
        final delayed = delay.inMilliseconds == 0
            ? value
            : Curves.easeOutCubic.transform(
                ((value * 1000 - delay.inMilliseconds) / 1000).clamp(0, 1));
        return Opacity(
          opacity: delayed,
          child: Transform.translate(
            offset: Offset(
                offset.dx * (1 - delayed) * 24, offset.dy * (1 - delayed) * 24),
            child: child,
          ),
        );
      },
    );
  }
}

class PressableScale extends StatefulWidget {
  const PressableScale(
      {super.key,
      required this.child,
      required this.onTap,
      this.semanticLabel});
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool pressed = false;
  bool focused = false;

  void _activate() {
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final content = GestureDetector(
      onTap: _activate,
      onTapDown: (_) {
        if (!reduceMotion) setState(() => pressed = true);
      },
      onTapCancel: () {
        if (!reduceMotion) setState(() => pressed = false);
      },
      onTapUp: (_) {
        if (!reduceMotion) setState(() => pressed = false);
      },
      child: reduceMotion
          ? widget.child
          : AnimatedScale(
              scale: pressed ? .975 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: widget.child,
            ),
    );

    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: FocusableActionDetector(
            onShowFocusHighlight: (value) {
              if (mounted) setState(() => focused = value);
            },
            child: DecoratedBox(
              decoration: focused
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(HopeV2Radii.button),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    )
                  : const BoxDecoration(),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility facade for the canonical premium panel primitive.
class HopeSurface extends StatelessWidget {
  const HopeSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = HopeV2Radii.lg,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool highlight;

  @override
  Widget build(BuildContext context) => PremiumPanel(
        padding: padding,
        radius: radius,
        highlight: highlight,
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PremiumSectionHeader(
        title: title,
        subtitle: subtitle,
        action: action,
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.color = HopeV2Colors.primary,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => PremiumTag(
        label: label,
        color: secondaryAccent(context) == color ? secondaryAccent(context) : color,
        icon: icon,
      );
}

class HopeIconTile extends StatelessWidget {
  const HopeIconTile(this.icon,
      {super.key,
      this.color = HopeV2Colors.primary,
      this.size = 46,
      this.filled = false,
      this.semanticLabel});
  final IconData icon;
  final Color color;
  final double size;
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fill = filled ? color : color.withValues(alpha: .10);
    final iconColor = filled ? Colors.white : color;
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: fill, borderRadius: BorderRadius.circular(size * .30)),
      child: Icon(icon, color: iconColor, size: size * .48),
    );
    // Decorative icons (no semanticLabel) are excluded from the accessibility
    // tree so screen readers don't announce an unlabeled generic icon node.
    return semanticLabel == null
        ? ExcludeSemantics(child: child)
        : Semantics(image: true, label: semanticLabel, child: child);
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = HopeV2Colors.primary,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => PremiumStatCard(
        label: label,
        value: value,
        icon: icon ?? Icons.insights_rounded,
        accent: color,
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: HopeSurface(
            padding: const EdgeInsets.all(28),
            highlight: true,
            // Grouped into one semantic node + liveRegion so screen readers
            // announce the empty state as a single coherent message when it
            // appears, instead of three separate unlabeled text nodes.
            child: MergeSemantics(
              child: Semantics(
                liveRegion: true,
                label: '$title. $message',
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  HopeIconTile(icon, size: 70, filled: true),
                  const SizedBox(height: 17),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (action != null) ...[const SizedBox(height: 18), action!],
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Compatibility facade for the canonical hero primitive.
class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PremiumHero(
        eyebrow: eyebrow,
        title: title,
        message: message,
        icon: icon,
        action: action,
      );
}

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.onFilter,
    this.hint,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;
  final String? hint;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final resolvedHint =
        widget.hint ?? HopeCopy.of(context).copy_search_dd58413;
    final hasQuery = _controller.text.isNotEmpty;

    return TextField(
      controller: _controller,
      onChanged: (value) {
        widget.onChanged(value);
        setState(() {});
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: resolvedHint,
        suffixIcon: hasQuery || widget.onFilter != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasQuery)
                    IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).clearButtonTooltip,
                      onPressed: _clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  if (widget.onFilter != null)
                    IconButton(
                      tooltip: HopeCopy.of(context).copy_filters_df4d10e,
                      onPressed: widget.onFilter,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}
