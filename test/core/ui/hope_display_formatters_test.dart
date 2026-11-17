import 'package:flutter_test/flutter_test.dart';
import 'package:hope_mobile/core/ui/hope_display_formatters.dart';

void main() {
  group('HopeDisplayFormatter', () {
    test('formats exact Toman integers in Persian digits', () {
      expect(
        HopeDisplayFormatter.money('1500000', locale: 'fa'),
        '۱٬۵۰۰٬۰۰۰ تومان',
      );
    });

    test('orders reversed ranges from minimum to maximum', () {
      expect(
        HopeDisplayFormatter.amount('2500000 – 1500000', locale: 'fa'),
        '۱٬۵۰۰٬۰۰۰ تومان تا ۲٬۵۰۰٬۰۰۰ تومان',
      );
    });

    test('formats English money without Persian digits', () {
      expect(
        HopeDisplayFormatter.money('1500000', locale: 'en'),
        '1,500,000 Toman',
      );
    });

    test('short money never rounds above the actual value', () {
      expect(
        HopeDisplayFormatter.money('1599999', locale: 'fa', short: true),
        '۱٫۵ میلیون تومان',
      );
    });

    test('formats relative dates and uses Jalali for older Persian dates', () {
      final now = DateTime.parse('2026-10-07T12:00:00Z');
      expect(
        HopeDisplayFormatter.relativeDateTime(
          '2026-10-07T10:00:00Z',
          locale: 'fa',
          now: now,
        ),
        '۲ ساعت پیش',
      );
      expect(
        HopeDisplayFormatter.relativeDateTime(
          '2026-09-01T10:00:00Z',
          locale: 'fa',
          now: now,
        ),
        isNot(contains('T')),
      );
    });
  });
}
