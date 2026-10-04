/// Calendar-date helpers. Service dates are plain dates (no time zone), so
/// they are always handled as local midnight values.
class Dates {
  const Dates._();

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime today() => dateOnly(DateTime.now());

  /// `yyyy-MM-dd` for the database.
  static String toJson(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

  static DateTime? tryParseIso(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(value.trim());
    if (match == null) return null;
    return _build(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
  }

  static DateTime? _build(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    // Reject overflow such as 31 February.
    if (date.month != m || date.day != d) return null;
    return date;
  }

  static DateTime? fromParts(int y, int m, int d) => _build(y, m, d);

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

  static String _two(int v) => v.toString().padLeft(2, '0');
}
