import 'package:flutter/services.dart';

class Utf16CodeUnitLengthLimitingTextInputFormatter extends TextInputFormatter {
  const Utf16CodeUnitLengthLimitingTextInputFormatter({
    required this.maxLength,
  });

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) return newValue;

    // Let an active IME composition finish; the committed value is bounded
    // on the next formatter pass. This avoids interrupting CJK/Persian input.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    var end = maxLength;
    if (end > 0 && end < newValue.text.length) {
      final beforeBoundary = newValue.text.codeUnitAt(end - 1);
      final afterBoundary = newValue.text.codeUnitAt(end);
      final splitsSurrogatePair =
          beforeBoundary >= 0xD800 &&
          beforeBoundary <= 0xDBFF &&
          afterBoundary >= 0xDC00 &&
          afterBoundary <= 0xDFFF;
      if (splitsSurrogatePair) end--;
    }

    int clampOffset(int offset) => offset.clamp(0, end).toInt();
    return newValue.copyWith(
      text: newValue.text.substring(0, end),
      selection: TextSelection(
        baseOffset: clampOffset(newValue.selection.baseOffset),
        extentOffset: clampOffset(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
      composing: TextRange.empty,
    );
  }
}
