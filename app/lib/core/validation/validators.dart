import '../utils/money.dart';
import '../utils/phone_number.dart';
import '../utils/text_normalizer.dart';

/// Stable validation error codes. The UI maps them to localized messages.
abstract final class ValidationCodes {
  static const required = 'required';
  static const tooLong = 'too_long';
  static const invalidPhone = 'invalid_phone';
  static const invalidPrice = 'invalid_price';
  static const negativePrice = 'negative_price';
  static const priceTooHigh = 'price_too_high';
  static const futureDate = 'future_date';
}

/// Pure validation functions. Each returns null when valid or an error code.
abstract final class Validators {
  static String? requiredText(String? value, {int maxLength = 160}) {
    final cleaned = TextNormalizer.clean(value);
    if (cleaned.isEmpty) return ValidationCodes.required;
    if (cleaned.length > maxLength) return ValidationCodes.tooLong;
    return null;
  }

  static String? optionalText(String? value, {int maxLength = 500}) {
    if ((value ?? '').trim().length > maxLength) return ValidationCodes.tooLong;
    return null;
  }

  static String? phone(String? value) {
    if ((value ?? '').trim().isEmpty) return ValidationCodes.required;
    return PhoneNumber.isValid(value) ? null : ValidationCodes.invalidPhone;
  }

  static String? optionalPhone(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    return PhoneNumber.isValid(value) ? null : ValidationCodes.invalidPhone;
  }

  static String? price(String? value) {
    if ((value ?? '').trim().isEmpty) return ValidationCodes.required;
    final money = Money.tryParse(value);
    if (money == null || !RegExp(r'\d').hasMatch(value!)) return ValidationCodes.invalidPrice;
    return priceValue(money);
  }

  static String? priceValue(Money money) {
    if (money.isNegative) return ValidationCodes.negativePrice;
    if (money > Money.max) return ValidationCodes.priceTooHigh;
    return null;
  }

  static String? optionalPrice(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    return price(value);
  }

  static String? required(Object? value) => value == null ? ValidationCodes.required : null;
}

extension on Money {
  bool operator >(Money other) => compareTo(other) > 0;
}
