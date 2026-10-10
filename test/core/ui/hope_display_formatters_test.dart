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

    test('collapses equal ranges to one value', () {
      expect(
        HopeDisplayFormatter.amount('2500000 – 2500000', locale: 'fa'),
        '۲٬۵۰۰٬۰۰۰ تومان',
      );
    });

    test('isolates signed Persian Toman amounts and preserves English display', () {
      expect(
        HopeDisplayFormatter.signedMoney(500000, positive: true, locale: 'fa'),
        '\u2066+۵۰۰٬۰۰۰ تومان\u2069',
      );
      expect(
        HopeDisplayFormatter.signedMoney(500000, positive: false, locale: 'fa'),
        '\u2066-۵۰۰٬۰۰۰ تومان\u2069',
      );
      expect(
        HopeDisplayFormatter.signedMoney(500000, positive: true, locale: 'en'),
        '+500,000 TOMAN',
      );
    });

    test('localizes percentage digits, decimal separators, and percent sign', () {
      expect(HopeDisplayFormatter.percent(96, locale: 'fa'), '۹۶٪');
      expect(
        HopeDisplayFormatter.percent(91.4, locale: 'fa', fractionDigits: 1),
        '۹۱٫۴٪',
      );
      expect(
        HopeDisplayFormatter.percent(91.4, locale: 'en', fractionDigits: 1),
        '91.4%',
      );
    });

    test('formats English money without Persian digits', () {
      expect(
        HopeDisplayFormatter.money('1500000', locale: 'en'),
        '1,500,000 TOMAN',
      );
    });

    test('short money never rounds above the actual value', () {
      expect(
        HopeDisplayFormatter.money('1599999', locale: 'fa', short: true),
        '۱٫۵ میلیون تومان',
      );
    });

    test('rejects fractional TOMAN values and malformed money text', () {
      expect(HopeDisplayFormatter.money(12.5, locale: 'fa'), '—');
      expect(HopeDisplayFormatter.integer(12.5, locale: 'en'), '—');
      expect(HopeDisplayFormatter.amount('2026-09-21T06:00:00Z', locale: 'fa'), '—');
    });

    test('formats only server-issued public references', () {
      expect(HopeDisplayFormatter.humanRef('HP-1042', locale: 'fa'), '#HP-1042');
      expect(HopeDisplayFormatter.humanRef('#hp-1042', locale: 'en'), '#HP-1042');
      expect(HopeDisplayFormatter.humanRef('payment-runtime-1', locale: 'fa'), isNull);
      expect(HopeDisplayFormatter.humanRef('550e8400-e29b-41d4-a716-446655440000', locale: 'en'), isNull);
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
        '۱۴۰۵ شهریور ۱۰',
      );
      expect(
        HopeDisplayFormatter.relativeDateTime(
          '2026-10-08T00:00:00Z',
          locale: 'fa',
          now: now,
        ),
        'در ۱۲ ساعت',
      );
      expect(
        HopeDisplayFormatter.relativeDateTime(
          '2026-10-08T00:00:00Z',
          locale: 'en',
          now: now,
        ),
        'in 12 hours',
      );
      expect(
        HopeDisplayFormatter.relativeDateTime(
          '2026-09-01T10:00:00Z',
          locale: 'en',
          now: now,
        ),
        'Sep 1, 2026',
      );
    });
  });
}
