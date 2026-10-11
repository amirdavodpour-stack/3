class HopeTomanFormatter {
  const HopeTomanFormatter._();

  static String grouped(Object value) {
    var raw = '$value'.trim();

    final match = RegExp(r'^([+-]?)(\d+)(?:\.0+)?
}
).firstMatch(raw);
    if (match == null) return raw;

    final sign = match.group(1) ?? '';
    var digits = match.group(2) ?? '';
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      groups.insert(0, digits.substring(start, end));
    }
    raw = groups.join(',');
    return '$sign$raw';
  }

  /// Formats an exact integer amount for a locale without numeric conversion.
  /// Non-integral or malformed input remains unchanged for upstream handling.
  static String groupedForLocale(Object value, {required String locale}) {
    final groupedValue = grouped(value);
    if (!locale.toLowerCase().startsWith('fa')) return groupedValue;
    if (!RegExp(r'^[+-]?\d{1,3}(?:,\d{3})*
}
).hasMatch(groupedValue)) {
      return groupedValue;
    }

    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    return groupedValue.replaceAllMapped(RegExp(r'[0-9,]'), (match) {
      final char = match.group(0)!;
      if (char == ',') return '٬';
      return persianDigits[int.parse(char)];
    });
  }
}
