import 'package:flutter/material.dart';

import '../theme/hope_v2_design.dart';
import 'premium_components.dart';
import 'components.dart';

class PremiumLifecycleStep {
  const PremiumLifecycleStep({
    required this.label,
    required this.icon,
    required this.active,
    this.complete = false,
    this.caption,
  });

  final String label;
  final Object icon;
  final bool active;
  final bool complete;
  final String? caption;
}

class PremiumLifecycle extends StatelessWidget {
  const PremiumLifecycle({
    super.key,
    required this.steps,
    this.title,
    this.subtitle,
    this.compact = false,
  });

  final List<PremiumLifecycleStep> steps;
  final String? title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return PremiumPanel(
      semanticLabel: title,
      padding: EdgeInsets.all(compact ? HopeV2Spacing.md : HopeV2Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: HopeV2Type.section(context)),
            if (subtitle != null) ...[
              const SizedBox(height: HopeV2Spacing.xs),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            SizedBox(height: compact ? HopeV2Spacing.sm : HopeV2Spacing.lg),
          ],
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final last = index == steps.length - 1;
            return _StepRow(step: step, last: last, compact: compact);
          }),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last, required this.compact});

  final PremiumLifecycleStep step;
  final bool last;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final highlighted = step.active || step.complete;
    final iconColor = step.complete
        ? HopeV2Colors.success
        : step.active
            ? Theme.of(context).colorScheme.primary
            : HopeV2Colors.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: compact ? 30 : 38,
          child: Column(
            children: [
              Semantics(
                label: step.label,
                child: Container(
                  width: compact ? 28 : 34,
                  height: compact ? 28 : 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: highlighted
                        ? iconColor.withValues(alpha: .12)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color: highlighted
                          ? iconColor.withValues(alpha: .35)
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: HopeIcon(
                    step.complete ? Icons.check_rounded : step.icon,
                    size: compact ? 15 : 18,
                    color: iconColor,
                  ),
                ),
              ),
              if (!last)
                Container(
                  width: 2,
                  height: compact ? 24 : 34,
                  margin: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
                  color: Theme.of(context).dividerColor,
                ),
            ],
          ),
        ),
        SizedBox(width: compact ? HopeV2Spacing.sm : HopeV2Spacing.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: compact ? HopeV2Spacing.sm : HopeV2Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
                      ),
                ),
                if (step.caption != null) ...[
                  const SizedBox(height: HopeV2Spacing.xs),
                  Text(step.caption!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
