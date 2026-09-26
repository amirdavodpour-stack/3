import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/finance/toman_formatter.dart';

void main() {
  group('HopeTomanFormatter', () {
    test('groups exact integer strings without numeric conversion', () {
      expect(
        HopeTomanFormatter.grouped('6000000000000000'),
        '6,000,000,000,000,000',
      );
      expect(
        HopeTomanFormatter.grouped('9007199254740993'),
        '9,007,199,254,740,993',
      );
    });

    test('preserves a signed exact integer while grouping magnitude', () {
      expect(HopeTomanFormatter.grouped('-125000'), '-125,000');
      expect(HopeTomanFormatter.grouped('+125000'), '+125,000');
    });

    test('normalizes an integer-valued decimal string without using double',
        () {
      expect(HopeTomanFormatter.grouped('125000.0'), '125,000');
      expect(HopeTomanFormatter.grouped('125000.00'), '125,000');
    });

    test('leaves non-integral values unchanged for explicit upstream handling',
        () {
      expect(HopeTomanFormatter.grouped('125000.50'), '125000.50');
      expect(HopeTomanFormatter.grouped('1e3'), '1e3');
      expect(HopeTomanFormatter.grouped('invalid'), 'invalid');
    });

    test('supports integer runtime values', () {
      expect(HopeTomanFormatter.grouped(125000), '125,000');
    });
  });
}
