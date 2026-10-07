import 'package:intl/intl.dart';

class HopeDisplayFormatter {
  const HopeDisplayFormatter._();

  static const _faDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const _arDigits = '٠١٢٣٤٥٦٧٨٩';

  static String _asciiDigits(String value) {
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(_faDigits[i], '$i').replaceAll(_arDigits[i], '$i');
    }
    return result;
  }

  static String localizeDigits(String value, {required String locale}) {
    if (!locale.toLowerCase().startsWith('fa')) return value;
    return value
        .replaceAll('0', '۰')
        .replaceAll('1', '۱')
        .replaceAll('2', '۲')
        .replaceAll('3', '۳')
        .replaceAll('4', '۴')
        .replaceAll('5', '۵')
        .replaceAll('6', '۶')
        .replaceAll('7', '۷')
        .replaceAll('8', '۸')
        .replaceAll('9', '۹')
        .replaceAll(',', '٬')
        .replaceAll('.', '٫');
  }

  /// Formats a server-issued public reference; never derives one from an internal ID.
  /// Returns null for UUIDs, database IDs and unknown reference formats.
  static String? humanRef(Object? value, {required String locale}) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.startsWith('#') ? raw.substring(1) : raw;
    if (!RegExp(r'^HP-\d{4,}$', caseSensitive: false).hasMatch(normalized)) {
      return null;
    }
    return '#${localizeDigits(normalized.toUpperCase(), locale: locale)}';
  }

  static int? parseInteger(Object? value) {
    if (value == null) return null;
    final normalized = _asciiDigits(value.toString()).trim().replaceAll(',', '').replaceAll('٬', '');
    if (!RegExp(r'^[+-]?\d+$').hasMatch(normalized)) return null;
    return int.tryParse(normalized);
  }
  static String integer(Object? value, {required String locale}) {
    final parsed = parseInteger(value);
    if (parsed == null) return '—';
    return localizeDigits(NumberFormat.decimalPattern('en_US').format(parsed), locale: locale);
  }

  static String money(Object? value, {required String locale, bool short = false}) {
    final parsed = parseInteger(value);
    if (parsed == null) return '—';
    final fa = locale.toLowerCase().startsWith('fa');
    if (short) {
      final abs = parsed.abs();
      final sign = parsed < 0 ? '-' : '';
      if (abs >= 1000000) {
        final whole = abs ~/ 1000000;
        final decimal = (abs % 1000000) ~/ 100000;
        final compact = decimal == 0 ? whole.toString() : whole.toString() + '.' + decimal.toString();
        return localizeDigits(sign + compact, locale: locale) + ' ' + (fa ? 'میلیون تومان' : 'million TOMAN');
      }
    }
    return integer(parsed, locale: locale) + ' ' + (fa ? 'تومان' : 'TOMAN');
  }

  static String amount(Object? value, {required String locale, bool short = false}) {
    final raw = value?.toString().trim() ?? '';
    final normalized = _asciiDigits(raw).replaceAll('٬', ',');
    if (!RegExp(
      r'^\s*[+-]?\d[\d,]*(?:\s*[–-]\s*[+-]?\d[\d,]*)?\s*$',
    ).hasMatch(normalized)) {
      return '—';
    }
    final parts = normalized
        .split(RegExp(r'\s*[–-]\s*'))
        .map(parseInteger)
        .whereType<int>()
        .toList();
    if (parts.length == 2) {
      parts.sort();
      final separator = locale.toLowerCase().startsWith('fa') ? 'تا' : '–';
      return money(parts.first, locale: locale, short: short) + ' ' + separator + ' ' +
          money(parts.last, locale: locale, short: short);
    }
    final single = parseInteger(normalized);
    return single == null ? '—' : money(single, locale: locale, short: short);
  }

  static String? relativeDateTime(String? raw, {required String locale, DateTime? now}) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final current = now ?? DateTime.now();
    final diff = current.difference(parsed);
    final fa = locale.toLowerCase().startsWith('fa');
    if (diff.inSeconds.abs() < 60) return fa ? 'همین حالا' : 'Just now';
    if (diff.isNegative) {
      final minutes = (-diff.inMinutes).clamp(1, 59);
      return fa ? 'در ' + localizeDigits(minutes.toString(), locale: locale) + ' دقیقه' : 'in ' + minutes.toString() + ' min';
    }
    if (diff.inMinutes < 60) {
      return fa ? localizeDigits(diff.inMinutes.toString(), locale: locale) + ' دقیقه پیش' : diff.inMinutes.toString() + 'm ago';
    }
    if (diff.inHours < 24) {
      return fa ? localizeDigits(diff.inHours.toString(), locale: locale) + ' ساعت پیش' : diff.inHours.toString() + 'h ago';
    }
    if (diff.inHours < 48) return fa ? 'دیروز' : 'Yesterday';
    if (diff.inDays < 7) {
      return fa ? localizeDigits(diff.inDays.toString(), locale: locale) + ' روز پیش' : diff.inDays.toString() + 'd ago';
    }
    if (!fa) return DateFormat('MMM d, y', 'en').format(parsed);
    final j = _gregorianToJalali(parsed.year, parsed.month, parsed.day);
    const months = ['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'];
    return localizeDigits(j.year.toString(), locale: locale) + ' ' + months[j.month - 1] + ' ' +
        localizeDigits(j.day.toString(), locale: locale);
  }

  static ({int year, int month, int day}) _gregorianToJalali(int gy, int gm, int gd) {
    final gdm = [0,31,59,90,120,151,181,212,243,273,304,334];
    var jy = gy <= 1600 ? 0 : 979;
    var gy2 = gm > 2 ? gy + 1 : gy;
    var days = 365 * gy + (gy2 + 3) ~/ 4 - (gy2 + 99) ~/ 100 + (gy2 + 399) ~/ 400 - 80 + gd + gdm[gm - 1];
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);
    return (year: jy, month: jm, day: jd);
  }
}