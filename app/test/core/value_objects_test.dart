import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/core/utils/phone_number.dart';
import 'package:sanad/core/utils/text_normalizer.dart';
import 'package:sanad/core/validation/validators.dart';

void main() {
  group('PhoneNumber', () {
    test('normalises separators, Arabic digits and country code', () {
      expect(PhoneNumber.normalize(' 010-1234 5678 '), '01012345678');
      expect(PhoneNumber.normalize('٠١٠١٢٣٤٥٦٧٨'), '01012345678');
      expect(PhoneNumber.normalize('+20 101 234 5678'), '01012345678');
      expect(PhoneNumber.normalize('00201012345678'), '01012345678');
      // Excel drops the leading zero of numeric cells.
      expect(PhoneNumber.normalize('1012345678'), '01012345678');
    });

    test('validates Egyptian mobiles and landlines', () {
      for (final valid in ['01012345678', '01112345678', '01212345678', '01512345678', '034567890', '0223456789']) {
        expect(PhoneNumber.isValid(valid), isTrue, reason: valid);
      }
      for (final invalid in ['0101234567', '01312345678', '12345', '**', '0', '', 'abc']) {
        expect(PhoneNumber.isValid(invalid), isFalse, reason: invalid);
      }
    });

    test('formats mobiles for display', () {
      expect(PhoneNumber.format('01012345678'), '010 1234 5678');
    });
  });

  group('Money', () {
    test('parses user input without floating point drift', () {
      expect(Money.tryParse('500'), const Money.piasters(50000));
      expect(Money.tryParse('1,250.50'), const Money.piasters(125050));
      expect(Money.tryParse('٥٠٠'), const Money.piasters(50000));
      expect(Money.tryParse('45ج'), const Money.piasters(4500));
      expect(Money.tryParse('abc'), isNull);
      expect(Money.pounds(0.1) + Money.pounds(0.2), Money.pounds(0.3));
    });

    test('formats and serialises', () {
      expect(const Money.piasters(125050).format(), '1,250.50');
      expect(const Money.piasters(50000).format(), '500');
      expect(const Money.piasters(50000).toJson(), 500);
      expect(const Money.piasters(125050).toJson(), 1250.5);
    });
  });

  group('TextNormalizer', () {
    test('treats Arabic spelling variants as the same name', () {
      expect(TextNormalizer.sameName('أسماء منصور', 'اسماء  منصور'), isTrue);
      expect(TextNormalizer.sameName('غيار عادى', 'غيار عادي'), isTrue);
      expect(TextNormalizer.sameName('الخدمة المُقدَّمة', 'الخدمه المقدمه'), isTrue);
      expect(TextNormalizer.sameName('Smouha', ' smouha '), isTrue);
      expect(TextNormalizer.sameName('سلطان', 'يوسف'), isFalse);
    });
  });

  group('LocalTime', () {
    test('parses database times', () {
      expect(LocalTime.tryParse('19:30:00'), const LocalTime(19, 30));
      expect(LocalTime.tryParse('7:05'), const LocalTime(7, 5));
      expect(LocalTime.tryParse('25:00'), isNull);
      expect(const LocalTime(9, 5).toJson(), '09:05:00');
    });
  });

  group('Validators', () {
    test('price', () {
      expect(Validators.price(''), ValidationCodes.required);
      expect(Validators.price('abc'), ValidationCodes.invalidPrice);
      expect(Validators.price('-5'), ValidationCodes.negativePrice);
      expect(Validators.price('2000000'), ValidationCodes.priceTooHigh);
      expect(Validators.price('500'), isNull);
      expect(Validators.price('0'), isNull);
    });

    test('phone', () {
      expect(Validators.phone(''), ValidationCodes.required);
      expect(Validators.phone('0101'), ValidationCodes.invalidPhone);
      expect(Validators.phone('01012345678'), isNull);
    });
  });
}
