import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/local_time.dart';
import '../../../core/utils/money.dart';
import '../domain/entities/sheet_table.dart';
import '../domain/excel_repositories.dart';
import '../../records/domain/entities/service_record.dart';
import '../domain/export/export_models.dart';

/// [WorkbookCodec] backed by the `excel` package. This is the only file that
/// knows about the package, so it can be swapped without touching the domain.
class ExcelWorkbookCodec implements WorkbookCodec {
  const ExcelWorkbookCodec();

  // ----------------------------------------------------------------- decode

  @override
  Result<List<SheetTable>> decode(Uint8List bytes) {
    try {
      final book = xl.Excel.decodeBytes(bytes);
      final tables = <SheetTable>[];
      for (final MapEntry(key: name, value: sheet) in book.tables.entries) {
        final rows = [
          for (final row in sheet.rows) [for (final cell in row) SheetCell(_value(cell?.value))],
        ];
        tables.add(SheetTable(name: name, rows: rows));
      }
      return Result.success(tables);
    } catch (_) {
      return const Result.failure(FileFailure(FileFailureReason.unreadable));
    }
  }

  static Object? _value(xl.CellValue? v) => switch (v) {
    null => null,
    xl.TextCellValue() => v.value.toString(),
    xl.IntCellValue() => v.value,
    xl.DoubleCellValue() => v.value,
    xl.BoolCellValue() => v.value,
    xl.DateCellValue() => DateTime(v.year, v.month, v.day),
    xl.DateTimeCellValue() => DateTime(v.year, v.month, v.day, v.hour, v.minute, v.second),
    xl.TimeCellValue() => LocalTime(v.hour % 24, v.minute % 60),
    // Formula results are not cached by the package; keep the formula text.
    xl.FormulaCellValue() => null,
  };

  // ----------------------------------------------------------------- encode

  static final _brand = xl.ExcelColor.fromHexString('#1A56DB');
  static final _zebra = xl.ExcelColor.fromHexString('#F3F7FF');
  static final _totalFill = xl.ExcelColor.fromHexString('#E8F0FE');

  static xl.CellStyle _header() => xl.CellStyle(
    bold: true,
    fontColorHex: xl.ExcelColor.white,
    backgroundColorHex: _brand,
    horizontalAlign: xl.HorizontalAlign.Center,
    verticalAlign: xl.VerticalAlign.Center,
    textWrapping: xl.TextWrapping.WrapText,
  );

  static const _dateFormat = xl.CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd');
  static const _dateTimeFormat = xl.CustomDateTimeNumFormat(formatCode: 'yyyy-mm-dd hh:mm');

  @override
  Result<Uint8List> encodeExport(ExportData data, ExportLabels labels, Set<ExportSheet> sheets) {
    try {
      final book = xl.Excel.createExcel();
      final defaultSheet = book.getDefaultSheet() ?? 'Sheet1';
      final written = <String>[];

      void sheet(
        ExportSheet kind,
        List<String> headers,
        List<List<xl.CellValue?>> rows,
        List<double> widths, {
        Map<int, xl.NumFormat> formats = const {},
        List<xl.CellValue?>? totals,
      }) {
        final name = labels.sheetNames[kind]!;
        final s = book[name];
        s.isRTL = labels.rtl;
        s.appendRow([for (final h in headers) xl.TextCellValue(h)]);
        for (var c = 0; c < headers.length; c++) {
          s.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = _header();
          s.setColumnWidth(c, widths[c]);
        }
        s.setRowHeight(0, 28);
        for (var r = 0; r < rows.length; r++) {
          s.appendRow(rows[r]);
          for (var c = 0; c < headers.length; c++) {
            final fill = r.isOdd ? _zebra : xl.ExcelColor.none;
            final format = formats[c];
            if (format == null && fill == xl.ExcelColor.none) continue;
            s.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).cellStyle = xl.CellStyle(
              backgroundColorHex: fill,
              numberFormat: format ?? xl.NumFormat.standard_0,
              verticalAlign: xl.VerticalAlign.Center,
            );
          }
        }
        if (totals != null) {
          s.appendRow(totals);
          final rowIndex = rows.length + 1;
          for (var c = 0; c < headers.length; c++) {
            s.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex)).cellStyle = xl.CellStyle(
              bold: true,
              backgroundColorHex: _totalFill,
              numberFormat: formats[c] ?? xl.NumFormat.standard_0,
            );
          }
        }
        written.add(name);
      }

      for (final kind in ExportSheet.values.where(sheets.contains)) {
        switch (kind) {
          case ExportSheet.records:
            final rows = [for (final r in data.records) _recordRow(r, labels)];
            const priceCol = 8;
            final lastRow = rows.length + 1;
            sheet(
              kind,
              labels.recordHeaders,
              rows,
              [38, 24, 16, 36, 16, 20, 18, 30, 12, 16, 13, 11, 40, 18],
              formats: {
                priceCol: xl.NumFormat.standard_4,
                10: _dateFormat,
                11: xl.NumFormat.standard_20,
                13: _dateTimeFormat,
              },
              totals: rows.isEmpty
                  ? null
                  // Label sits in the ID column and the customer columns stay
                  // empty, so re-importing an export ignores this row.
                  : [
                      xl.TextCellValue('${labels.total} (${rows.length})'),
                      null,
                      null,
                      null,
                      null,
                      null,
                      null,
                      null,
                      xl.FormulaCellValue('SUM(I2:I$lastRow)'),
                    ],
            );
          case ExportSheet.customers:
            sheet(
              kind,
              labels.customerHeaders,
              [
                for (final c in data.customers)
                  [
                    xl.TextCellValue(c.id),
                    xl.TextCellValue(c.fullName),
                    _text(c.phone),
                    _text(c.address),
                    xl.TextCellValue(c.areaName),
                    xl.IntCellValue(c.recordCount),
                    c.lastServiceDate == null ? null : xl.DateCellValue.fromDateTime(c.lastServiceDate!),
                    _dateTime(c.createdAt),
                  ],
              ],
              [38, 26, 16, 40, 16, 10, 14, 18],
              formats: {6: _dateFormat, 7: _dateTimeFormat},
            );
          case ExportSheet.nurses:
            sheet(
              kind,
              labels.nurseHeaders,
              [
                for (final n in data.nurses)
                  [xl.TextCellValue(n.id), xl.TextCellValue(n.name), _text(n.phone), _status(n.isActive, labels)],
              ],
              [38, 26, 16, 12],
            );
          case ExportSheet.services:
            sheet(
              kind,
              labels.serviceHeaders,
              [
                for (final s in data.services)
                  [
                    xl.TextCellValue(s.id),
                    xl.TextCellValue(s.name),
                    s.defaultPrice == null ? xl.TextCellValue(labels.variablePrice) : _money(s.defaultPrice!),
                    _status(s.isActive, labels),
                  ],
              ],
              [38, 36, 18, 12],
              formats: {2: xl.NumFormat.standard_4},
            );
          case ExportSheet.areas:
            sheet(
              kind,
              labels.areaHeaders,
              [
                for (final a in data.areas)
                  [xl.TextCellValue(a.id), xl.TextCellValue(a.name), _status(a.isActive, labels)],
              ],
              [38, 26, 12],
            );
        }
      }

      if (written.isEmpty) return const Result.failure(FileFailure(FileFailureReason.empty));
      if (!written.contains(defaultSheet)) book.delete(defaultSheet);
      book.setDefaultSheet(written.first);
      var bytes = book.encode();
      if (bytes == null) return const Result.failure(FileFailure(FileFailureReason.writeFailed));
      if (labels.rtl) {
        // The package only writes `rightToLeft` for sheets that already exist
        // in the file, so re-open the freshly written workbook to apply it.
        final reopened = xl.Excel.decodeBytes(bytes);
        for (final sheet in reopened.tables.values) {
          sheet.isRTL = true;
        }
        bytes = reopened.encode();
        if (bytes == null) return const Result.failure(FileFailure(FileFailureReason.writeFailed));
      }
      return Result.success(Uint8List.fromList(bytes));
    } catch (_) {
      return const Result.failure(FileFailure(FileFailureReason.writeFailed));
    }
  }

  static List<xl.CellValue?> _recordRow(ServiceRecord r, ExportLabels labels) => [
    // Imported records keep their legacy reference so the sheet can be
    // reconciled against the original workbook.
    xl.TextCellValue(r.legacyRef ?? r.id),
    xl.TextCellValue(r.customerName),
    _text(r.customerPhone),
    _text(r.customerAddress),
    _text(r.areaName),
    _text(r.patientName),
    xl.TextCellValue(r.nurseName),
    xl.TextCellValue(r.serviceName),
    _money(r.price),
    xl.TextCellValue(labels.paymentLabels[r.paymentMethod]!),
    xl.DateCellValue.fromDateTime(r.serviceDate),
    if (r.serviceTime case final t?) xl.TimeCellValue(hour: t.hour, minute: t.minute) else null,
    _text(r.notes),
    _dateTime(r.createdAt),
  ];

  static xl.CellValue? _text(String? v) => v == null || v.isEmpty ? null : xl.TextCellValue(v);

  static xl.CellValue _money(Money m) =>
      m.piasters % 100 == 0 ? xl.IntCellValue(m.piasters ~/ 100) : xl.DoubleCellValue(m.pounds);

  static xl.CellValue _status(bool active, ExportLabels labels) =>
      xl.TextCellValue(active ? labels.active : labels.inactive);

  static xl.CellValue _dateTime(DateTime dt) {
    final l = dt.toLocal();
    return xl.DateTimeCellValue(year: l.year, month: l.month, day: l.day, hour: l.hour, minute: l.minute);
  }
}
