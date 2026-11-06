import 'package:flutter/material.dart';

import '../theme/hope_v2_design.dart';

enum HopeFeedbackTone { info, success, warning, error }

/// Canonical transient acknowledgement surface.
///
/// This helper is intentionally limited to short-lived acknowledgement and
/// recoverable action feedback. Critical field errors and durable operation
/// failures should remain in the owning screen state and expose recovery UI.
///
/// [bottomClearance] reserves extra space below floating feedback when a
/// screen owns a persistent action dock, preventing the message from covering
/// controls needed to recover from the feedback.
class HopeFeedback {
  const HopeFeedback._();

  static void show(
    BuildContext context,
    String message, {
    HopeFeedbackTone tone = HopeFeedbackTone.info,
    Duration duration = const Duration(seconds: 4),
    double bottomClearance = 0,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || message.trim().isEmpty) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: duration,
          margin: bottomClearance > 0
              ? EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomClearance)
              : null,
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
        HopeFeedbackTone.info => HopeV2Icons.info,
        HopeFeedbackTone.success => HopeV2Icons.success,
        HopeFeedbackTone.warning => HopeV2Icons.warning,
        HopeFeedbackTone.error => HopeV2Icons.error,
      };
}
