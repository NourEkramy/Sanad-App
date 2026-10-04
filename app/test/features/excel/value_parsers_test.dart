import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/excel/domain/entities/sheet_table.dart';
import 'package:sanad/features/excel/domain/import/value_parsers.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';

SheetCell c(Object? v) => SheetCell(v);

void main() {
  group('time (formats found in the legacy workbook)', () {
    final cases = <String, LocalTime>{
      '9م': const LocalTime(21, 0),
      '11.30م': const LocalTime(23, 30),
      '10.39م ': const LocalTime(22, 39),
      '5.30 ص': const LocalTime(5, 30),
      '12ص': const LocalTime(0, 0),
      '12م': const LocalTime(12, 0),
      '12.30ص': const LocalTime(0, 30),
      '1.40 م': const LocalTime(13, 40),
      '7:30 PM': const LocalTime(19, 30),
      '21:15': const LocalTime(21, 15),
      '٩م': const LocalTime(21, 0),
    };
    for (final MapEntry(key: input, value: expected) in cases.entries) {
      test(input, () {
        final parsed = ValueParsers.time(c(input));
        expect(parsed.value, expected);
        expect(parsed.issue, isNull);
      });
    }

    test('placeholders are reported as missing', () {
      expect(ValueParsers.time(c('**')).issue, ImportIssue.timeMissing);
      expect(ValueParsers.time(c(null)).issue, ImportIssue.timeMissing);
    });

    test('hours without AM/PM are not guessed', () {
      final parsed = ValueParsers.time(c('11.3'));
      expect(parsed.value, isNull);
      expect(parsed.issue, ImportIssue.timeAmbiguous);
    });

    test('real time cells and day fractions', () {
      expect(ValueParsers.time(c(const LocalTime(8, 15))).value, const LocalTime(8, 15));
      expect(ValueParsers.time(c(0.75)).value, const LocalTime(18, 0));
    });
  });

  group('date', () {
    test('ISO strings and date cells', () {
      expect(ValueParsers.date(c('2026-06-18')).value, DateTime(2026, 6, 18));
      expect(ValueParsers.date(c(DateTime(2026, 6, 18, 10))).value, DateTime(2026, 6, 18));
    });

    test('unambiguous slashed dates (m/d as used in the expenses sheet)', () {
      expect(ValueParsers.date(c('6/20/2026')).value, DateTime(2026, 6, 20));
      expect(ValueParsers.date(c('20/6/2026')).value, DateTime(2026, 6, 20));
    });

    test('ambiguous slashed dates are read day-first with a warning', () {
      final parsed = ValueParsers.date(c('3/4/2026'));
      expect(parsed.value, DateTime(2026, 4, 3));
      expect(parsed.issue, ImportIssue.dateAmbiguous);
    });

    test('Excel serial numbers', () {
      expect(ValueParsers.date(c(46191)).value, DateTime(2026, 6, 18));
    });

    test('invalid and missing dates', () {
      expect(ValueParsers.date(c('31/02/2026')).issue, ImportIssue.dateInvalid);
      expect(ValueParsers.date(c('soon')).issue, ImportIssue.dateInvalid);
      expect(ValueParsers.date(c('')).issue, ImportIssue.dateMissing);
    });
  });

  group('price', () {
    test('formatted currency strings', () {
      expect(ValueParsers.price(c('500 ج.م')).value, Money.pounds(500));
      expect(ValueParsers.price(c('1,500 ج.م.‏')).value, Money.pounds(1500));
      expect(ValueParsers.price(c(155)).value, Money.pounds(155));
      expect(ValueParsers.price(c('500 ج.م')).issue, isNull);
    });

    test('free text is cleaned and flagged (e.g. "45ج")', () {
      final parsed = ValueParsers.price(c('45ج'));
      expect(parsed.value, Money.pounds(45));
      expect(parsed.issue, ImportIssue.priceCleaned);
    });

    test('missing and invalid prices', () {
      expect(ValueParsers.price(c('**')).issue, ImportIssue.priceMissing);
      expect(ValueParsers.price(c('free')).issue, ImportIssue.priceInvalid);
      expect(ValueParsers.price(c(-5)).issue, ImportIssue.priceInvalid);
    });
  });

  group('payment method', () {
    test('Arabic and English labels', () {
      expect(ValueParsers.payment(c('نقدي')).value, PaymentMethod.cash);
      expect(ValueParsers.payment(c('كاش')).value, PaymentMethod.cash);
      expect(ValueParsers.payment(c('محفظة إلكترونية')).value, PaymentMethod.electronic);
      expect(ValueParsers.payment(c('InstaPay')).value, PaymentMethod.electronic);
      expect(ValueParsers.payment(c('Electronic')).value, PaymentMethod.electronic);
      expect(ValueParsers.payment(c('غير محدد')).value, PaymentMethod.unspecified);
    });

    test('missing column → unspecified (legacy workbook has none)', () {
      final parsed = ValueParsers.payment(c(null));
      expect(parsed.value, PaymentMethod.unspecified);
      expect(parsed.issue, isNull);
    });

    test('unknown text is flagged', () {
      expect(ValueParsers.payment(c('later')).issue, ImportIssue.paymentUnknown);
    });
  });
}
