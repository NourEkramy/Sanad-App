/// Egyptian phone-number handling shared by validation, search and import.
///
/// Numbers are stored in local format, digits only (`01012345678`).
/// Mirrors `public.sanad_is_valid_phone` in the database.
class PhoneNumber {
  const PhoneNumber._();

  static final _mobile = RegExp(r'^01[0125]\d{8}$');
  static final _landline = RegExp(r'^0[2-9]\d{7,8}$');
  static final _separators = RegExp(r'[\s\-().]');

  static const _easternDigits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  /// Converts Arabic-Indic digits, removes separators and the +20/0020
  /// country prefix. Returns the input unchanged (trimmed) when it contains
  /// characters other than digits.
  static String normalize(String? input) {
    if (input == null) return '';
    final buffer = StringBuffer();
    for (final rune in input.trim().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_easternDigits[char] ?? char);
    }
    var value = buffer.toString().replaceAll(_separators, '');
    if (value.startsWith('+20')) {
      value = '0${value.substring(3)}';
    } else if (value.startsWith('0020')) {
      value = '0${value.substring(4)}';
    } else if (value.startsWith('20') && value.length == 12) {
      value = '0${value.substring(2)}';
    } else if (value.length == 10 && value.startsWith('1')) {
      // Excel often drops the leading zero of numeric phone cells.
      value = '0$value';
    }
    return value;
  }

  static bool isValid(String? input) {
    final value = normalize(input);
    return _mobile.hasMatch(value) || _landline.hasMatch(value);
  }

  /// True when [input] looks like (part of) a phone number rather than a name.
  static bool looksLikeDigits(String input) {
    final value = normalize(input).replaceFirst('+', '');
    return value.isNotEmpty && RegExp(r'^\d+$').hasMatch(value);
  }

  /// `01012345678` → `010 1234 5678` for display.
  static String format(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    if (_mobile.hasMatch(phone)) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 7)} ${phone.substring(7)}';
    }
    return phone;
  }
}
