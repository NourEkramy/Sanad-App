import '../../../../core/utils/dates.dart';
import '../../../../core/utils/local_time.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../records/domain/entities/service_record.dart';
import '../entities/sheet_table.dart';

/// Result of parsing one cell: a value and/or an issue code.
class Parsed<T> {
  const Parsed(this.value, [this.issue]);
  const Parsed.issue(this.issue) : value = null;

  final T? value;
  final String? issue;
}

/// Issue codes reported per row in the import preview.
abstract final class ImportIssue {
  // Errors — the row is skipped.
  static const dateMissing = 'date_missing';
  static const dateInvalid = 'date_invalid';
  static const priceMissing = 'price_missing';
  static const priceInvalid = 'price_invalid';
  static const customerMissing = 'customer_missing';

  // Warnings — the row is imported.
  static const dateAmbiguous = 'date_ambiguous';
  static const timeMissing = 'time_missing';
  static const timeInvalid = 'time_invalid';
  static const timeAmbiguous = 'time_ambiguous';
  static const phoneInvalid = 'phone_invalid';
  static const phoneShared = 'phone_shared';
  static const nurseMissing = 'nurse_missing';
  static const serviceMissing = 'service_missing';
  static const areaMissing = 'area_missing';
  static const priceCleaned = 'price_cleaned';
  static const paymentUnknown = 'payment_unknown';
  static const customerDetailsChanged = 'customer_details_changed';

  static const errors = {dateMissing, dateInvalid, priceMissing, priceInvalid, customerMissing};
}

/// Lenient parsers for the free-text values found in the legacy workbook.
abstract final class ValueParsers {
  static const _eastern = '٠١٢٣٤٥٦٧٨٩';

  static String westernDigits(String input) {
    final b = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      final i = _eastern.indexOf(ch);
      b.write(i >= 0 ? i : ch);
    }
    return b.toString();
  }

  static bool _isPlaceholder(String text) => RegExp(r'^[\s*.\-_؟?]*$').hasMatch(text);

  // ---------------------------------------------------------------- dates

  /// Accepts real date cells, ISO strings, `d/m/yyyy` / `m/d/yyyy`
  /// (unambiguous only, otherwise day-first with a warning) and Excel serials.
  static Parsed<DateTime> date(SheetCell cell) {
    final v = cell.value;
    if (cell.isEmpty) return const Parsed.issue(ImportIssue.dateMissing);
    if (v is DateTime) return Parsed(Dates.dateOnly(v));
    if (v is num) return _serial(v);
    final text = westernDigits(cell.text);
    if (_isPlaceholder(text)) return const Parsed.issue(ImportIssue.dateMissing);
    final iso = Dates.tryParseIso(text);
    if (iso != null) return Parsed(iso);
    final m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(text);
    if (m != null) {
      final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      if (a > 12) return _orInvalid(Dates.fromParts(y, b, a));
      if (b > 12) return _orInvalid(Dates.fromParts(y, a, b));
      final dayFirst = Dates.fromParts(y, b, a);
      if (a == b) return _orInvalid(dayFirst);
      return dayFirst == null
          ? const Parsed.issue(ImportIssue.dateInvalid)
          : Parsed(dayFirst, ImportIssue.dateAmbiguous);
    }
    final asNumber = num.tryParse(text);
    if (asNumber != null) return _serial(asNumber);
    return const Parsed.issue(ImportIssue.dateInvalid);
  }

  static Parsed<DateTime> _orInvalid(DateTime? d) =>
      d == null ? const Parsed.issue(ImportIssue.dateInvalid) : Parsed(d);

  static Parsed<DateTime> _serial(num serial) {
    // Excel day 1 = 1900-01-01 (with the 1900 leap-year bug → base 1899-12-30).
    if (serial < 20000 || serial > 80000) return const Parsed.issue(ImportIssue.dateInvalid);
    final d = DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    return Parsed(Dates.dateOnly(d));
  }

  // ---------------------------------------------------------------- times

  static final _timePattern = RegExp(
    r'^(\d{1,2})(?:[.:،,](\d{1,2}))?\s*(ص|م|صباحا|مساء|مساءا|am|pm|a|p)?$',
    caseSensitive: false,
  );

  /// Parses times such as `9م`, `11.30م`, `5.30 ص`, `12ص`, `21:15`, `7:30 PM`
  /// and real time cells. Without AM/PM, hours 1–12 are ambiguous and are
  /// *not* guessed.
  static Parsed<LocalTime> time(SheetCell cell) {
    final v = cell.value;
    if (cell.isEmpty) return const Parsed.issue(ImportIssue.timeMissing);
    if (v is LocalTime) return Parsed(v);
    if (v is DateTime) return Parsed(LocalTime(v.hour, v.minute));
    if (v is double && v >= 0 && v < 1) {
      final minutes = (v * 24 * 60).round() % (24 * 60);
      return Parsed(LocalTime(minutes ~/ 60, minutes % 60));
    }
    final text = westernDigits(cell.text).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (_isPlaceholder(text)) return const Parsed.issue(ImportIssue.timeMissing);
    final m = _timePattern.firstMatch(text.replaceAll(' ', ''));
    if (m == null) return const Parsed.issue(ImportIssue.timeInvalid);
    var hour = int.parse(m.group(1)!);
    final minuteText = m.group(2);
    // "11.3" is written like a decimal: 11:30.
    final minute = minuteText == null
        ? 0
        : (minuteText.length == 1 ? int.parse(minuteText) * 10 : int.parse(minuteText));
    final suffix = m.group(3);
    if (minute > 59 || hour > 23) return const Parsed.issue(ImportIssue.timeInvalid);

    if (suffix == null) {
      if (hour == 0 || hour > 12) return Parsed(LocalTime(hour, minute));
      return const Parsed.issue(ImportIssue.timeAmbiguous);
    }
    final pm = const {'م', 'مساء', 'مساءا', 'pm', 'p'}.contains(suffix);
    if (hour > 12) return Parsed(LocalTime(hour, minute));
    if (hour == 12) hour = 0;
    return Parsed(LocalTime(pm ? hour + 12 : hour, minute));
  }

  // ---------------------------------------------------------------- price

  static final _cleanPrice = RegExp(r'^\s*[\d,٬.]+\s*(ج\.?\s?م\.?|جنيه|egp|le|l\.e\.?)?\s*$', caseSensitive: false);

  static Parsed<Money> price(SheetCell cell) {
    final v = cell.value;
    if (cell.isEmpty) return const Parsed.issue(ImportIssue.priceMissing);
    if (v is num) {
      return v < 0 ? const Parsed.issue(ImportIssue.priceInvalid) : Parsed(Money.pounds(v));
    }
    final text = westernDigits(cell.text.replaceAll('‏', '').replaceAll('‎', ''));
    if (_isPlaceholder(text)) return const Parsed.issue(ImportIssue.priceMissing);
    final money = Money.tryParse(text);
    if (money == null || money.isNegative) return const Parsed.issue(ImportIssue.priceInvalid);
    return Parsed(money, _cleanPrice.hasMatch(text) ? null : ImportIssue.priceCleaned);
  }

  // ---------------------------------------------------------------- payment

  static const _cash = ['نقدي', 'نقدا', 'نقد', 'كاش', 'cash'];
  static const _electronic = [
    'الكتروني',
    'إلكتروني',
    'electronic',
    'محفظه',
    'محفظة',
    'wallet',
    'instapay',
    'انستاباي',
    'انستا',
    'فودافون',
    'vodafone',
    'visa',
    'فيزا',
    'card',
    'كارت',
    'تحويل',
    'transfer',
  ];
  static const _unspecified = ['غير محدد', 'unspecified', 'unknown'];

  static Parsed<PaymentMethod> payment(SheetCell cell) {
    if (cell.isEmpty) return const Parsed(PaymentMethod.unspecified);
    final key = TextNormalizer.key(cell.text);
    bool any(List<String> words) => words.any((w) => key.contains(TextNormalizer.key(w)));
    if (any(_unspecified)) return const Parsed(PaymentMethod.unspecified);
    if (any(_electronic)) return const Parsed(PaymentMethod.electronic);
    if (any(_cash)) return const Parsed(PaymentMethod.cash);
    return const Parsed(PaymentMethod.unspecified, ImportIssue.paymentUnknown);
  }

  /// Text value, or null for blanks and placeholders such as `**` / `...`.
  static String? text(SheetCell cell) {
    final t = TextNormalizer.clean(cell.text);
    return t.isEmpty || _isPlaceholder(t) ? null : t;
  }

  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  /// A Sanad record ID (UUID) from a connected sheet, or null.
  static String? sheetId(SheetCell cell) {
    final t = cell.text.toLowerCase();
    return _uuid.hasMatch(t) ? t : null;
  }

  /// Free text kept verbatim (only trimmed); placeholders become null.
  static String? notes(SheetCell cell) {
    final t = cell.text.trim();
    return t.isEmpty || _isPlaceholder(t) ? null : t;
  }
}
