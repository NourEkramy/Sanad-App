import 'package:equatable/equatable.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/phone_number.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../excel/domain/entities/sheet_table.dart';
import '../../excel/domain/import/column_mapping.dart';
import '../../excel/domain/import/value_parsers.dart';
import 'sheet_link.dart';
import 'sheet_sync.dart';

/// What was found in a spreadsheet being connected.
class DetectedSheet extends Equatable {
  const DetectedSheet({required this.layout, required this.extras, this.visitsTable, this.visitsMapping});

  final SheetLayout layout;

  /// The visits sheet and its columns (null when Sanad will create one).
  final SheetTable? visitsTable;
  final ColumnMapping? visitsMapping;

  /// Customers and list entries of the other sheets.
  final SheetExtras extras;

  /// Number of rows below the visits header that hold any data.
  int get visitRows {
    final table = visitsTable;
    final mapping = visitsMapping;
    if (table == null || mapping == null) return 0;
    final date = mapping[ImportField.serviceDate];
    return table.rows
        .skip(mapping.headerRow + 1)
        .where((r) => date != null && date < r.length && !r[date].isEmpty)
        .length;
  }

  @override
  List<Object?> get props => [layout, extras, visitsTable, visitsMapping];
}

/// Finds the visits log, the customers sheet and the lists sheet by their
/// headers (the original workbook, Sanad's own export, or an empty sheet).
class SheetLayoutDetector {
  const SheetLayoutDetector([this._columns = const ColumnDetector()]);

  final ColumnDetector _columns;

  static const _weekday = ['اليوم', 'day', 'weekday'];
  static const _month = ['الشهر', 'الشهر (تلقائي)', 'month'];
  static const _services = ['الخدمات', 'الخدمة', 'services', 'service'];
  static const _price = ['السعر', 'الاسعار', 'price'];
  static const _nurses = ['الممرضين', 'الممرضون', 'الممرض', 'nurses'];
  static const _areas = ['المناطق', 'المنطقة', 'areas'];

  DetectedSheet detect(SheetSnapshot snapshot) {
    // Visits: the sheet that maps the most columns (date + customer at least).
    SheetTable? visits;
    ColumnMapping? mapping;
    var best = -1;
    for (final table in snapshot.tables) {
      final m = _columns.detect(table);
      if (m == null) continue;
      final score = m.columns.length * 1000 + table.rows.length;
      if (score > best) {
        best = score;
        visits = table;
        mapping = m;
      }
    }

    final others = snapshot.tables.where((t) => t != visits).toList();
    final cases = _cases(others);
    final lists = _lists(others.where((t) => t != cases?.$1).toList());

    return DetectedSheet(
      layout: SheetLayout(
        visits: visits == null ? VisitsLayout.standard() : _visitsLayout(visits, mapping!),
        cases: cases?.$2 ?? CasesLayout.standard(),
        lists: lists?.$2 ?? ListsLayout.standard(),
      ),
      visitsTable: visits,
      visitsMapping: mapping,
      extras: SheetExtras(
        customers: cases == null ? const [] : _caseRows(cases.$1, cases.$2),
        services: lists == null ? const [] : _services_(lists.$1, lists.$2),
        hasServicePrices: lists != null && _col(lists.$1, lists.$2.headerRow, lists.$2.price) != null,
        nurses: lists == null ? const [] : _column(lists.$1, lists.$2.headerRow, lists.$2.nurses),
        areas: lists == null ? const [] : _column(lists.$1, lists.$2.headerRow, lists.$2.areas),
      ),
    );
  }

  VisitsLayout _visitsLayout(SheetTable table, ColumnMapping mapping) {
    final headers = <ImportField, String>{
      for (final MapEntry(key: field, value: col) in mapping.columns.entries)
        if (field != ImportField.sanadId && mapping.headers[col] != null) field: mapping.headers[col]!,
    };
    headers.putIfAbsent(ImportField.paymentMethod, () => paymentHeader);
    String? find(List<String> names) {
      final keys = names.map(TextNormalizer.key).toSet();
      return mapping.headers.values.where((h) => keys.contains(TextNormalizer.key(h))).firstOrNull;
    }

    return VisitsLayout(
      sheet: table.name,
      headerRow: mapping.headerRow + 1,
      headers: headers,
      weekdayHeader: find(_weekday),
      monthHeader: find(_month),
    );
  }

  (SheetTable, CasesLayout)? _cases(List<SheetTable> tables) {
    for (final table in tables) {
      for (var r = 0; r < table.rows.length && r < 20; r++) {
        final m = _columns.mapRow(table, r);
        final name = m[ImportField.customerName];
        final phone = m[ImportField.phone];
        if (name == null || phone == null || m[ImportField.serviceDate] != null) continue;
        String? header(ImportField f) => m[f] == null ? null : m.headers[m[f]!];
        return (
          table,
          CasesLayout(
            sheet: table.name,
            headerRow: r + 1,
            name: m.headers[name]!,
            phone: m.headers[phone]!,
            address: header(ImportField.address),
            area: header(ImportField.area),
          ),
        );
      }
    }
    return null;
  }

  (SheetTable, ListsLayout)? _lists(List<SheetTable> tables) {
    for (final table in tables) {
      for (var r = 0; r < table.rows.length && r < 10; r++) {
        String? header(List<String> names) {
          final keys = names.map(TextNormalizer.key).toSet();
          return table.rows[r]
              .map((c) => TextNormalizer.clean(c.text))
              .where((t) => keys.contains(TextNormalizer.key(t)))
              .firstOrNull;
        }

        final services = header(_services);
        final nurses = header(_nurses);
        final areas = header(_areas);
        if ([services, nurses, areas].where((h) => h != null).length < 2) continue;
        final standard = ListsLayout.standard();
        return (
          table,
          ListsLayout(
            sheet: table.name,
            headerRow: r + 1,
            services: services ?? standard.services,
            price: header(_price) ?? standard.price,
            nurses: nurses ?? standard.nurses,
            areas: areas ?? standard.areas,
          ),
        );
      }
    }
    return null;
  }

  // -------------------------------------------------------------- extras

  static int? _col(SheetTable table, int headerRow, String header) {
    final cells = table.rows[headerRow - 1];
    final key = TextNormalizer.key(header);
    for (var c = 0; c < cells.length; c++) {
      if (TextNormalizer.key(cells[c].text) == key) return c;
    }
    return null;
  }

  static List<String> _column(SheetTable table, int headerRow, String header) {
    final col = _col(table, headerRow, header);
    if (col == null) return const [];
    return [for (var r = headerRow; r < table.rows.length; r++) ?ValueParsers.text(table.cell(r, col))];
  }

  static List<(String, Money?)> _services_(SheetTable table, ListsLayout layout) {
    final col = _col(table, layout.headerRow, layout.services);
    if (col == null) return const [];
    final priceCol = _col(table, layout.headerRow, layout.price);
    return [
      for (var r = layout.headerRow; r < table.rows.length; r++)
        if (ValueParsers.text(table.cell(r, col)) case final name?)
          (name, priceCol == null ? null : ValueParsers.price(table.cell(r, priceCol)).value),
    ];
  }

  static List<(String, String, String?, String?)> _caseRows(SheetTable table, CasesLayout layout) {
    final name = _col(table, layout.headerRow, layout.name);
    final phone = _col(table, layout.headerRow, layout.phone);
    if (name == null || phone == null) return const [];
    final address = layout.address == null ? null : _col(table, layout.headerRow, layout.address!);
    final area = layout.area == null ? null : _col(table, layout.headerRow, layout.area!);
    return [
      for (var r = layout.headerRow; r < table.rows.length; r++)
        if ((ValueParsers.text(table.cell(r, name)), ValueParsers.text(table.cell(r, phone))) case (final n?, final p?)
            when PhoneNumber.isValid(p))
          (
            n,
            PhoneNumber.normalize(p),
            address == null ? null : ValueParsers.text(table.cell(r, address)),
            area == null ? null : ValueParsers.text(table.cell(r, area)),
          ),
    ];
  }
}
