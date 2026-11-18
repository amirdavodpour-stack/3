import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/auth/password_input_formatters.dart';

void main() {
  const formatter = Utf16CodeUnitLengthLimitingTextInputFormatter(
    maxLength: 128,
  );

  test('limits input to the backend UTF-16 code-unit maximum', () {
    final pasted = List<String>.filled(65, '😀').join();
    final incoming = TextEditingValue(
      text: pasted,
      selection: TextSelection.collapsed(offset: pasted.length),
    );

    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      incoming,
    );

    expect(result.text, List<String>.filled(64, '😀').join());
    expect(result.text.length, 128);
    expect(result.selection.extentOffset, 128);
  });

  test('does not split a surrogate pair at the code-unit boundary', () {
    final pasted = 'a' + List<String>.filled(64, '😀').join();
    expect(pasted.length, 129);
    final incoming = TextEditingValue(
      text: pasted,
      selection: TextSelection.collapsed(offset: pasted.length),
    );

    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      incoming,
    );

    expect(result.text, 'a' + List<String>.filled(63, '😀').join());
    expect(result.text.length, 127);
    expect(result.selection.extentOffset, 127);
  });

  test('allows active IME composition and clamps after composition commits', () {
    final composingText = List<String>.filled(65, '😀').join();
    final composing = TextEditingValue(
      text: composingText,
      selection: TextSelection.collapsed(offset: composingText.length),
      composing: TextRange(start: 0, end: composingText.length),
    );

    final duringComposition = formatter.formatEditUpdate(
      TextEditingValue.empty,
      composing,
    );
    expect(duringComposition, composing);

    final committed = composing.copyWith(composing: TextRange.empty);
    final afterComposition = formatter.formatEditUpdate(
      composing,
      committed,
    );
    expect(afterComposition.text, List<String>.filled(64, '😀').join());
    expect(afterComposition.text.length, 128);
  });
}