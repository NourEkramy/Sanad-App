import 'package:equatable/equatable.dart';

import '../../../../core/utils/text_normalizer.dart';
import '../entities/sheet_table.dart';

/// Application fields a spreadsheet column can be mapped to.
enum ImportField {
  legacyRef,
  serviceDate,
  serviceTime,
  customerName,
  phone,
  address,
  area,
  nurse,
  service,
  price,
  paymentMethod,
  patientName,
  notes,
  status;

  bool get isRequired => this == serviceDate || this == price;
}

/// Which column (0-based) holds which field, and where the data starts.
class ColumnMapping extends Equatable {
  const ColumnMapping({required this.headerRow, required this.columns, required this.headers});

  /// 0-based index of the header row; data starts on the next row.
  final int headerRow;
  final Map<ImportField, int> columns;

  /// Header text of every column (for display and for the audit copy).
  final Map<int, String> headers;

  int? operator [](ImportField field) => columns[field];

  /// Missing mappings that prevent an import.
  List<ImportField> get missingRequired => [
    for (final f in ImportField.values)
      if (f.isRequired && !columns.containsKey(f)) f,
    if (!columns.containsKey(ImportField.customerName) && !columns.containsKey(ImportField.phone))
      ImportField.customerName,
  ];

  bool get isUsable => missingRequired.isEmpty;

  ColumnMapping withColumn(ImportField field, int? column) {
    final next = Map<ImportField, int>.from(columns)..remove(field);
    if (column != null) {
      next.removeWhere((_, c) => c == column);
      next[field] = column;
    }
    return ColumnMapping(headerRow: headerRow, columns: next, headers: headers);
  }

  @override
  List<Object?> get props => [headerRow, columns, headers];
}

/// Detects the header row and maps columns by their (Arabic or English)
/// header text. Works for the legacy "سجل الزيارات" sheet and for Sanad's own
/// export, so an exported workbook can be imported back.
class ColumnDetector {
  const ColumnDetector();

  /// Exact header names (normalised) per field. Checked first.
  static const Map<ImportField, List<String>> _exact = {
    ImportField.legacyRef: ['م', '#', 'no', 'record id', 'legacy ref', 'رقم السجل', 'المرجع'],
    ImportField.serviceDate: ['service date', 'date', 'تاريخ الخدمة', 'التاريخ', 'تاريخ الزيارة'],
    ImportField.serviceTime: ['service time', 'time', 'وقت الخدمة', 'الوقت', 'وقت الزيارة'],
    ImportField.customerName: ['customer name', 'customer', 'name', 'اسم العميل', 'العميل', 'الاسم'],
    ImportField.phone: ['customer phone', 'phone', 'mobile', 'رقم التليفون', 'رقم الهاتف', 'هاتف العميل'],
    ImportField.address: ['customer address', 'address', 'العنوان', 'العنوان التفصيلي', 'عنوان العميل'],
    ImportField.area: ['customer area', 'area', 'المنطقة', 'منطقة العميل'],
    ImportField.nurse: ['nurse', 'الممرض', 'اسم الممرض / الفني'],
    ImportField.service: ['service', 'الخدمة', 'الخدمة المقدمة'],
    ImportField.price: ['price', 'price (egp)', 'amount', 'السعر', 'السعر (ج.م)', 'ثمن الزيارة (ج.م)'],
    ImportField.paymentMethod: ['payment method', 'payment', 'طريقة الدفع'],
    ImportField.patientName: ['patient (if different)', 'المريض (إن اختلف)'],
    ImportField.notes: ['notes', 'ملاحظات'],
    ImportField.status: ['status', 'حالة الاستلام'],
  };

  /// Substrings (normalised), checked for still-unmapped columns in this
  /// order — date/time before service so "Service Date" is not taken as
  /// "Service".
  static const List<(ImportField, List<String>)> _contains = [
    (ImportField.serviceDate, ['تاريخ', 'date']),
    (ImportField.serviceTime, ['وقت', 'time']),
    (ImportField.phone, ['تليفون', 'هاتف', 'موبايل', 'جوال', 'phone', 'mobile']),
    (ImportField.price, ['ثمن', 'سعر', 'المبلغ', 'price', 'amount']),
    (ImportField.paymentMethod, ['الدفع', 'payment']),
    (ImportField.status, ['الاستلام', 'status']),
    (ImportField.notes, ['ملاحظ', 'note']),
    (ImportField.nurse, ['ممرض', 'الفني', 'nurse']),
    (ImportField.area, ['منطق', 'area']),
    (ImportField.address, ['عنوان', 'address']),
    (ImportField.customerName, ['اسم المريض', 'اسم العميل', 'customer', 'name']),
    (ImportField.service, ['خدم', 'service']),
  ];

  /// Columns that are known to be derived/irrelevant (e.g. weekday, month).
  static const _ignored = [
    'اليوم',
    'day',
    'الشهر',
    'الشهر (تلقائي)',
    'month',
    'created at',
    'تاريخ الإنشاء',
    'كود الحالة',
  ];

  ColumnMapping? detect(SheetTable table, {int scanRows = 20}) {
    ColumnMapping? best;
    var bestScore = 0;
    for (var r = 0; r < table.rows.length && r < scanRows; r++) {
      final mapping = mapRow(table, r);
      final score = mapping.columns.length;
      final plausible =
          mapping.columns.containsKey(ImportField.serviceDate) &&
          (mapping.columns.containsKey(ImportField.customerName) || mapping.columns.containsKey(ImportField.phone));
      if (plausible && score > bestScore) {
        best = mapping;
        bestScore = score;
      }
    }
    return best;
  }

  ColumnMapping mapRow(SheetTable table, int row) {
    final headers = <int, String>{};
    final keys = <int, String>{};
    final cells = table.rows[row];
    for (var c = 0; c < cells.length; c++) {
      final text = TextNormalizer.clean(cells[c].text);
      if (text.isEmpty) continue;
      headers[c] = text;
      keys[c] = _key(text);
    }

    final columns = <ImportField, int>{};
    final ignored = _ignored.map(_key).toSet();
    final free = keys.keys.where((c) => !ignored.contains(keys[c])).toSet();

    for (final MapEntry(key: field, value: names) in _exact.entries) {
      final wanted = names.map(_key).toSet();
      final hit = free.where((c) => wanted.contains(keys[c])).firstOrNull;
      if (hit != null) {
        columns[field] = hit;
        free.remove(hit);
      }
    }
    for (final (field, parts) in _contains) {
      if (columns.containsKey(field)) continue;
      final wanted = parts.map(_key).toList();
      final hit = (free.toList()..sort()).where((c) => wanted.any((p) => keys[c]!.contains(p))).firstOrNull;
      if (hit != null) {
        columns[field] = hit;
        free.remove(hit);
      }
    }
    return ColumnMapping(headerRow: row, columns: columns, headers: headers);
  }

  static String _key(String text) => TextNormalizer.key(text);
}
