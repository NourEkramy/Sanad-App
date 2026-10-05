/// Helpers for building search conditions (always used with `?` parameters,
/// never concatenated into SQL).
abstract final class Sql {
  static const _eastern = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  /// The digits of [query] in local phone format when it looks like a phone
  /// number (`010 123`, `+20 10…`, Arabic digits), otherwise null.
  static String? phoneQuery(String query) {
    final buffer = StringBuffer();
    for (final rune in query.runes) {
      final char = String.fromCharCode(rune);
      final i = _eastern.contains(char) ? _eastern.indexOf(char) : _persian.indexOf(char);
      buffer.write(i >= 0 ? '$i' : char);
    }
    var digits = buffer.toString().replaceAll(RegExp(r'[\s\-().]'), '');
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(digits)) return null;
    digits = digits.replaceFirst(RegExp(r'^(\+?20|0020)'), '0').replaceAll('+', '');
    return digits;
  }

  /// `%value%` for `LIKE … ESCAPE '\'`, with LIKE wildcards in [value] escaped.
  static String contains(String value) => '%${value.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
}
