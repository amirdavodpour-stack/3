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

class HopeSurface extends StatelessWidget {
  const HopeSurface(
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.radius = HopeV2Radii.lg,
      this.highlight = false});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = HopeV2Surfaces.border(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: highlight
            ? (dark
                ? HopeV2Colors.darkCard.withValues(alpha: .92)
                : HopeV2Colors.softPrimary)
            : HopeV2Surfaces.panel(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlight
              ? HopeV2Colors.primary.withValues(alpha: .24)
              : border,
          width: highlight ? 1.1 : 1,
        ),
        boxShadow: dark ? const [] : HopeV2Shadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
      {super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          );

          if (action == null) return content;

          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: action!,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: content),
              const SizedBox(width: 12),
              action!,
            ],
          );
        },
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label,
      {super.key, this.color = HopeV2Colors.primary, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Dark surfaces need brighter status hues to keep text >= 4.5:1.
    final resolved = _accessible(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: resolved.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: resolved),
          const SizedBox(width: 5)
        ],
        Semantics(
            label: label,
            child: Text(label,
                style: TextStyle(
                    color: resolved,
                    fontSize: 11,
                    fontWeight: FontWeight.w900))),
      ]),
    );
  }

  Color _accessible(BuildContext context, Color c) {
    if (Theme.of(context).brightness != Brightness.dark) return c;
    if (c == HopeV2Colors.warning) return HopeV2Colors.warningDark;
    if (c == HopeV2Colors.danger) return HopeV2Colors.dangerDark;
    if (c == HopeV2Colors.success) return HopeV2Colors.successDark;
    if (c == HopeV2Colors.muted) return HopeV2Colors.darkMuted;
    if (c == HopeV2Colors.primary) return HopeV2Colors.primaryDark;
    return c;
  }
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
  const MetricTile(
      {super.key,
      required this.label,
      required this.value,
      this.icon,
      this.color = HopeV2Colors.primary});
  final String label;
  final String value;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => HopeSurface(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          if (icon != null) ...[
            HopeIconTile(icon!, color: color),
            const SizedBox(width: 12)
          ],
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
              ])),
        ]),
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

class GradientHero extends StatelessWidget {
  const GradientHero(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.message,
      required this.icon,
      this.action});
  final String eyebrow;
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5D43E8), Color(0xFF8B73FF), Color(0xFFB09FFF)],
            stops: [0, .55, 1],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(HopeV2Radii.hero),
          boxShadow: const [
            BoxShadow(
                color: Color(0x2B6C4DFF), blurRadius: 32, offset: Offset(0, 16))
          ],
        ),
        child: Stack(children: [
          Positioned(
              right: -28,
              top: -38,
              child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      shape: BoxShape.circle))),
          Positioned(
              left: -36,
              bottom: -55,
              child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .06),
                      shape: BoxShape.circle))),
          Padding(
            padding: const EdgeInsets.all(HopeV2Spacing.xl),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(eyebrow,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2)),
                    const SizedBox(height: 8),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.5)),
                    const SizedBox(height: 9),
                    Text(message,
                        style: const TextStyle(
                            color: Colors.white70, height: 1.45)),
                    if (action != null) ...[
                      const SizedBox(height: 18),
                      action!
                    ],
                  ])),
              const SizedBox(width: 14),
              Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(HopeV2Radii.fab),
                      border: Border.all(color: Colors.white24)),
                  child: Icon(icon, color: Colors.white, size: 29)),
            ]),
          ),
        ]),
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

class HopeResponsive extends StatelessWidget {
  const HopeResponsive(
      {super.key,
      required this.child,
      this.maxWidth = 860,
      this.padding = const EdgeInsets.symmetric(horizontal: 20)});
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}

class SkeletonBox extends StatefulWidget {
  const SkeletonBox(
      {super.key, this.height = 16, this.width, this.radius = 12});
  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  void _ensureController() {
    if (_controller != null || MediaQuery.disableAnimationsOf(context)) return;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    _ensureController();
    final base =
        dark ? Colors.white.withValues(alpha: .06) : const Color(0xFFECEAF2);
    final highlight = dark ? Colors.white.withValues(alpha: .12) : Colors.white;
    // Honor the system "reduce motion" preference: show a static placeholder.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [base, highlight, base],
            stops: const [.2, .5, .8],
            begin: Alignment(-1.0 + 2 * _controller!.value, 0),
            end: Alignment(1.0 + 2 * _controller!.value, 0),
          ),
        ),
      ),
    );
  }
}

class OpportunitySkeletonCard extends StatelessWidget {
  const OpportunitySkeletonCard({super.key});

  @override
  Widget build(BuildContext context) => const HopeSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonBox(height: 110, radius: HopeV2Radii.xl),
          Padding(
            padding: const EdgeInsets.all(HopeV2Spacing.lg),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(height: 20, width: 240),
              SizedBox(height: 9),
              SkeletonBox(height: 14, width: 180),
              SizedBox(height: 15),
              SkeletonBox(height: 14, width: 90),
              SizedBox(height: 8),
              SkeletonBox(height: 20, width: 150),
              SizedBox(height: 12),
              Row(children: [
                SkeletonBox(height: 28, width: 100),
                SizedBox(width: 8),
                SkeletonBox(height: 28, width: 118)
              ]),
            ]),
          ),
        ]),
      );
}
