import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../l10n/app_localizations.dart';
import '../utils/dates.dart';
import '../utils/local_time.dart';
import '../utils/money.dart';
import '../utils/phone_number.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeName => l10n.localeName;
  bool get isArabic => localeName.startsWith('ar');
}

/// Locale-aware display formatting (presentation only).
class Fmt {
  Fmt(this.context);
  final BuildContext context;

  String get _locale => context.localeName;

  /// `500 EGP` / `500 ج.م`, digits kept Western for readability of prices
  /// and phone numbers across both languages.
  String money(Money m) => context.l10n.currencyAmount(m.format());

  String phone(String? phone) => PhoneNumber.format(phone);

  /// `12 September 2026`
  String date(DateTime d) => DateFormat.yMMMMd(_locale).format(d);

  /// `12 Sep 2026`
  String shortDate(DateTime d) => DateFormat.yMMMd(_locale).format(d);

  /// Today / Yesterday / `12 Sep 2026`
  String relativeDate(DateTime d) {
    final today = Dates.today();
    final day = Dates.dateOnly(d);
    if (day == today) return context.l10n.commonToday;
    if (day == today.subtract(const Duration(days: 1))) return context.l10n.commonYesterday;
    return shortDate(d);
  }

  /// `7:30 PM` / `7:30 م`
  String time(LocalTime t) => DateFormat.jm(_locale).format(DateTime(2000, 1, 1, t.hour, t.minute));

  String dateTime(DateTime d) => '${shortDate(d)} · ${DateFormat.jm(_locale).format(d)}';

  String monthYear(DateTime d) => DateFormat.yMMMM(_locale).format(d);

  String weekday(DateTime d) => DateFormat.EEEE(_locale).format(d);
}

/// Direction of a user-entered value (names, addresses, notes), so Latin text
/// inside the Arabic UI (and vice versa) is not reordered.
TextDirection textDirectionOf(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;

extension FmtX on BuildContext {
  Fmt get fmt => Fmt(this);
}
