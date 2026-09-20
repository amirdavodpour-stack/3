import 'package:flutter/material.dart';

import '../theme/hope_v2_design.dart';

enum HopeStateKind {
  initial,
  loading,
  refreshing,
  empty,
  partial,
  error,
  offline,
  unauthorized,
  forbidden,
  conflict,
  validation,
  rateLimited,
  retrying,
  permission,
  pending,
  submitting,
  success,
}

/// Shared semantic state presentation for async/product surfaces.
/// Screens should provide truthful copy and an action only when one exists.
class HopeAsyncState extends StatelessWidget {
  const HopeAsyncState({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.action,
  });

  final HopeStateKind kind;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final config = switch (kind) {
      HopeStateKind.initial => (Icons.hourglass_empty_rounded, Theme.of(context).colorScheme.onSurfaceVariant),
      HopeStateKind.loading => (Icons.hourglass_empty_rounded, Theme.of(context).colorScheme.primary),
      HopeStateKind.refreshing => (Icons.refresh_rounded, Theme.of(context).colorScheme.primary),
      HopeStateKind.empty => (Icons.inbox_outlined, Theme.of(context).colorScheme.onSurfaceVariant),
      HopeStateKind.partial => (Icons.incomplete_circle_rounded, Theme.of(context).colorScheme.secondary),
      HopeStateKind.error => (Icons.error_outline_rounded, Theme.of(context).colorScheme.error),
      HopeStateKind.offline => (Icons.cloud_off_rounded, Theme.of(context).colorScheme.error),
      HopeStateKind.unauthorized => (Icons.login_rounded, Theme.of(context).colorScheme.secondary),
      HopeStateKind.forbidden => (Icons.lock_outline_rounded, Theme.of(context).colorScheme.secondary),
      HopeStateKind.conflict => (Icons.sync_problem_rounded, Theme.of(context).colorScheme.error),
      HopeStateKind.validation => (Icons.rule_rounded, Theme.of(context).colorScheme.error),
      HopeStateKind.rateLimited => (Icons.hourglass_top_rounded, Theme.of(context).colorScheme.secondary),
      HopeStateKind.retrying => (Icons.sync_rounded, Theme.of(context).colorScheme.primary),
      HopeStateKind.permission => (Icons.lock_outline_rounded, Theme.of(context).colorScheme.secondary),
      HopeStateKind.pending => (Icons.schedule_rounded, HopeV2SemanticColors.warning(context)),
      HopeStateKind.submitting => (Icons.hourglass_empty_rounded, Theme.of(context).colorScheme.primary),
      HopeStateKind.success => (Icons.check_circle_outline_rounded, Theme.of(context).colorScheme.tertiary),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(HopeV2Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind == HopeStateKind.loading || kind == HopeStateKind.refreshing || kind == HopeStateKind.retrying || kind == HopeStateKind.submitting)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Icon(config.$1, size: 38, color: config.$2),
                const SizedBox(height: HopeV2Spacing.md),
                Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: HopeV2Spacing.xs),
                Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                if (action != null) ...[
                  const SizedBox(height: HopeV2Spacing.lg),
                  ConstrainedBox(constraints: const BoxConstraints(minHeight: HopeV2Touch.minimum), child: action!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
