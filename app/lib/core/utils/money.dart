import 'package:equatable/equatable.dart';

/// An amount in Egyptian pounds, stored as integer piasters to avoid
/// floating-point rounding in totals.
class Money extends Equatable implements Comparable<Money> {
  const Money.piasters(this.piasters);

  factory Money.pounds(num pounds) => Money.piasters((pounds * 100).round());

  static const zero = Money.piasters(0);

  /// Maximum accepted price for a single record (matches the DB constraint).
  static const max = Money.piasters(100000000);

  final int piasters;

  double get pounds => piasters / 100;

  bool get isNegative => piasters < 0;

  Money operator +(Money other) => Money.piasters(piasters + other.piasters);

  /// Parses user input such as `500`, `1,250.50`, `٥٠٠` or `500 EGP`.
  /// Returns null when no number can be read.
  static Money? tryParse(String? input) {
    if (input == null) return null;
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final idx = eastern.indexOf(char);
      if (idx >= 0) {
        buffer.write(idx);
      } else if (char == '٫') {
        buffer.write('.');
      } else {
        buffer.write(char);
      }
    }
    final cleaned = buffer.toString().replaceAll(RegExp(r'[,\s٬]'), '');
    final match = RegExp(r'-?\d+(\.\d{1,2})?').firstMatch(cleaned);
    if (match == null) return null;
    final value = double.tryParse(match.group(0)!);
    if (value == null) return null;
    return Money.pounds(value);
  }

  /// Value for the database / JSON (`numeric(12,2)`).
  num toJson() => piasters % 100 == 0 ? piasters ~/ 100 : piasters / 100;

  static Money fromJson(Object? value) {
    if (value is num) return Money.pounds(value);
    if (value is String) return tryParse(value) ?? Money.zero;
    return Money.zero;
  }

  /// Plain number without currency, e.g. `1,250` or `1,250.50`.
  String format() {
    final whole = (piasters ~/ 100).abs().toString();
    final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    final fraction = (piasters % 100).abs();
    final sign = piasters < 0 ? '-' : '';
    return fraction == 0 ? '$sign$grouped' : '$sign$grouped.${fraction.toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(Money other) => piasters.compareTo(other.piasters);

  @override
  List<Object?> get props => [piasters];

  @override
  String toString() => '${format()} EGP';
}
