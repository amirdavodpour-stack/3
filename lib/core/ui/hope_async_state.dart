import 'package:flutter/material.dart';

import '../network/api_client.dart';
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

HopeStateKind hopeStateKindForError(Object error) {
  if (error is ApiException) {
    return switch (error.code) {
      'UNAUTHENTICATED' || 'INVALID_TOKEN' => HopeStateKind.unauthorized,
      'FORBIDDEN' => HopeStateKind.forbidden,
      'VALIDATION_ERROR' => HopeStateKind.validation,
      'RATE_LIMITED' => HopeStateKind.rateLimited,
      'NETWORK_ERROR' || 'TIMEOUT' => HopeStateKind.offline,
      _ => HopeStateKind.error,
    };
  }
  return HopeStateKind.error;
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final config = switch (kind) {
      HopeStateKind.initial => (HopeV2Icons.pending, Theme.of(context).colorScheme.onSurfaceVariant),
      HopeStateKind.loading => (HopeV2Icons.pending, Theme.of(context).colorScheme.primary),
      HopeStateKind.refreshing => (HopeV2Icons.refresh, Theme.of(context).colorScheme.primary),
      HopeStateKind.empty => (HopeV2Icons.empty, Theme.of(context).colorScheme.onSurfaceVariant),
      HopeStateKind.partial => (HopeV2Icons.partial, Theme.of(context).colorScheme.secondary),
      HopeStateKind.error => (HopeV2Icons.error, Theme.of(context).colorScheme.error),
      HopeStateKind.offline => (HopeV2Icons.offline, Theme.of(context).colorScheme.error),
      HopeStateKind.unauthorized => (HopeV2Icons.login, Theme.of(context).colorScheme.secondary),
      HopeStateKind.forbidden => (HopeV2Icons.secure, Theme.of(context).colorScheme.secondary),
      HopeStateKind.conflict => (HopeV2Icons.conflict, Theme.of(context).colorScheme.error),
      HopeStateKind.validation => (HopeV2Icons.validation, Theme.of(context).colorScheme.error),
      HopeStateKind.rateLimited => (HopeV2Icons.rateLimit, Theme.of(context).colorScheme.secondary),
      HopeStateKind.retrying => (HopeV2Icons.retry, Theme.of(context).colorScheme.primary),
      HopeStateKind.permission => (HopeV2Icons.secure, Theme.of(context).colorScheme.secondary),
      HopeStateKind.pending => (HopeV2Icons.pending, HopeV2SemanticColors.warning(context)),
      HopeStateKind.submitting => (HopeV2Icons.pending, Theme.of(context).colorScheme.primary),
      HopeStateKind.success => (HopeV2Icons.success, Theme.of(context).colorScheme.tertiary),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      label: '$title. $message',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(HopeV2Spacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!reduceMotion &&
                        (kind == HopeStateKind.loading ||
                            kind == HopeStateKind.refreshing ||
                            kind == HopeStateKind.retrying ||
                            kind == HopeStateKind.submitting))
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      SizedBox(
                        width: 52,
                        height: 48,
                        child: CustomPaint(
                          painter: _HopeKineticStatePainter(
                            color: config.$2,
                            kind: kind,
                          ),
                          child: Center(
                            child: Icon(
                              config.$1,
                              size: 30,
                              color: config.$2,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: HopeV2Spacing.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: HopeV2Spacing.xs),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (action != null) ...[
                      const SizedBox(height: HopeV2Spacing.lg),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: HopeV2Touch.minimum,
                        ),
                        child: action!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );

          // Async content lives inside Expanded/compact page viewports on some
          // screens. Large text can make even a short loading/error message
          // taller than that viewport; keep it scrollable instead of overflowing.
          if (!constraints.hasBoundedHeight) return content;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        },
      ),
    );
  }
}


/// A compact kinetic editorial frame that gives semantic state icons a
/// distinct HOPE rhythm without enlarging the page's hero or card geometry.
class _HopeKineticStatePainter extends CustomPainter {
  const _HopeKineticStatePainter({required this.color, required this.kind});

  final Color color;
  final HopeStateKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final soft = Paint()..color = color.withValues(alpha: .12);
    final bright = Paint()
      ..color = color.withValues(alpha: .48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final fine = Paint()
      ..color = color.withValues(alpha: .27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final ring = Rect.fromCircle(
      center: Offset(size.width * .5, size.height * .5),
      radius: 17,
    );
    canvas.drawArc(ring, -.8, 2.15, false, bright);
    canvas.drawArc(ring, 2.75, 1.15, false, fine);
    canvas.drawCircle(Offset(size.width - 7, 9), 3.1, soft);
    canvas.drawCircle(Offset(7, size.height - 8), 2.1, bright);

    final slashes = Path()
      ..moveTo(2, 9)
      ..lineTo(7, 4)
      ..moveTo(size.width - 13, size.height - 4)
      ..lineTo(size.width - 5, size.height - 11);
    canvas.drawPath(slashes, fine);

    if (kind == HopeStateKind.error ||
        kind == HopeStateKind.offline ||
        kind == HopeStateKind.conflict) {
      final cut = Path()
        ..moveTo(size.width - 15, 3)
        ..lineTo(size.width - 8, 3)
        ..lineTo(size.width - 8, 10);
      canvas.drawPath(cut, bright);
    }
  }

  @override
  bool shouldRepaint(covariant _HopeKineticStatePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.kind != kind;
}
