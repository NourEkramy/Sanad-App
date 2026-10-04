import 'package:equatable/equatable.dart';

/// Time of day without a date or time zone (Flutter-independent so it can be
/// used in the domain layer).
class LocalTime extends Equatable implements Comparable<LocalTime> {
  const LocalTime(this.hour, this.minute) : assert(hour >= 0 && hour < 24), assert(minute >= 0 && minute < 60);

  factory LocalTime.fromDateTime(DateTime dt) => LocalTime(dt.hour, dt.minute);

  final int hour;
  final int minute;

  /// Parses `HH:mm` or `HH:mm:ss` (database format).
  static LocalTime? tryParse(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$').firstMatch(value.trim());
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    if (h > 23 || m > 59) return null;
    return LocalTime(h, m);
  }

  /// `HH:mm:ss` for the database.
  String toJson() => '${_two(hour)}:${_two(minute)}:00';

  String get hhmm => '${_two(hour)}:${_two(minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  int compareTo(LocalTime other) => (hour * 60 + minute).compareTo(other.hour * 60 + other.minute);

  @override
  List<Object?> get props => [hour, minute];

  @override
  String toString() => hhmm;
}
