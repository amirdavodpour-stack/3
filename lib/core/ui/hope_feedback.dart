import 'package:flutter/material.dart';

enum HopeFeedbackTone { info, success, warning, error }

/// Canonical transient acknowledgement surface.
///
/// This helper is intentionally limited to short-lived acknowledgement and
/// recoverable action feedback. Critical field errors and durable operation
/// failures should remain in the owning screen state and expose recovery UI.
class HopeFeedback {
  const HopeFeedback._();

  static void show(
    BuildContext context,
    String message, {
    HopeFeedbackTone tone = HopeFeedbackTone.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || message.trim().isEmpty) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          content: Row(
            children: [
              ExcludeSemantics(child: Icon(_iconFor(tone))),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  static IconData _iconFor(HopeFeedbackTone tone) => switch (tone) {
        HopeFeedbackTone.info => Icons.info_outline_rounded,
        HopeFeedbackTone.success => Icons.check_circle_outline_rounded,
        HopeFeedbackTone.warning => Icons.warning_amber_rounded,
        HopeFeedbackTone.error => Icons.error_outline_rounded,
      };
}
