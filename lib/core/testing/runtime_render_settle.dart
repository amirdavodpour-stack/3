import 'package:flutter/material.dart';

/// A determinate progress ring is visual data, not a loading state.
///
/// Runtime screenshot settling must only block on genuinely indeterminate
/// progress indicators so match-score rings cannot be mistaken for spinners.
bool isBlockingRuntimeProgressIndicator(Widget widget) =>
    widget is CircularProgressIndicator && widget.value == null;
