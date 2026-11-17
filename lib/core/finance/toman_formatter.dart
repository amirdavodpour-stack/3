class HopeTomanFormatter {
  const HopeTomanFormatter._();

  static String grouped(Object value) {
    var raw = '$value'.trim();

    final match = RegExp(r'^([+-]?)(\d+)(?:\.0+)?$').firstMatch(raw);
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
}
