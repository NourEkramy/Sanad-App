import 'package:equatable/equatable.dart';

import '../../../../core/utils/local_time.dart';

/// A spreadsheet cell reduced to plain Dart values so that the import logic
/// does not depend on any Excel library.
///
/// [value] is one of: `null`, [String], [num], [DateTime] (date or
/// date-time), [LocalTime] (time-only cells) or [bool].
class SheetCell extends Equatable {
  const SheetCell(this.value);

  static const empty = SheetCell(null);

  final Object? value;

  bool get isEmpty => value == null || (value is String && (value! as String).trim().isEmpty);

  /// Text representation (used for names, notes and the audit copy).
  String get text {
    final v = value;
    return switch (v) {
      null => '',
      String() => v.trim(),
      DateTime() => v.hour == 0 && v.minute == 0
          ? '${v.year}-${_two(v.month)}-${_two(v.day)}'
          : '${v.year}-${_two(v.month)}-${_two(v.day)} ${_two(v.hour)}:${_two(v.minute)}',
      LocalTime() => v.hhmm,
      double() when v == v.roundToDouble() => v.toInt().toString(),
      _ => v.toString(),
    };
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  List<Object?> get props => [value];
}

class SheetTable extends Equatable {
  const SheetTable({required this.name, required this.rows});

  final String name;

  /// Rows in sheet order; index 0 is spreadsheet row 1.
  final List<List<SheetCell>> rows;

  SheetCell cell(int row, int column) {
    if (row < 0 || row >= rows.length) return SheetCell.empty;
    final r = rows[row];
    if (column < 0 || column >= r.length) return SheetCell.empty;
    return r[column];
  }

  int get nonEmptyRowCount => rows.where((r) => r.any((c) => !c.isEmpty)).length;

  @override
  List<Object?> get props => [name, rows];
}
