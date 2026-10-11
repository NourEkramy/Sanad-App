import '../../../core/database/sheet_state.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/local_time.dart';
import '../../excel/domain/import/column_mapping.dart';
import '../../records/domain/entities/service_record.dart';
import 'sheet_link.dart';
import 'sheet_sync.dart';

/// Write requests for a batch of local changes, and how to read back the
/// connector's answer into a [SheetReceipt].
class SheetBatch {
  const SheetBatch(this.ops, this._changes);

  final List<SheetOp> ops;
  final SheetChanges _changes;

  /// Rows written per ID; everything in the batch counts as written.
  SheetReceipt receipt(List<SheetWriteResult> results) {
    final rows = <String, int?>{for (final r in results) ...r.rows};
    return SheetReceipt(
      records: {
        for (final p in _changes.records)
          p.record.id: (p.version, rows.containsKey(p.record.id) ? rows[p.record.id] : p.sheetRow),
      },
      customers: {for (final p in _changes.customers) p.customer.id: (p.version, rows[p.customer.id])},
      items: [for (final i in _changes.items) (i.kind, i.id, i.version)],
      removals: _changes.removals,
    );
  }
}

/// Builds the connector requests for local changes (pure, no I/O).
class SheetOpsBuilder {
  const SheetOpsBuilder();

  /// Text the original workbook uses for a received payment.
  static const received = 'تم الاستلام';
  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  SheetBatch build(SheetLayout layout, SheetChanges changes) => SheetBatch([
    if (_visits(layout.visits, changes) case final op? when !op.isEmpty) op,
    if (_cases(layout.cases, changes) case final op? when !op.isEmpty) op,
    if (_lists(layout.lists, changes) case final op? when !op.isEmpty) op,
  ], changes);

  // -------------------------------------------------------------- visits

  SheetOp? _visits(VisitsLayout v, SheetChanges changes) {
    if (changes.records.isEmpty && changes.removals.isEmpty) return null;
    final dataHeaders = [
      for (final MapEntry(key: field, value: header) in v.headers.entries)
        if (field != ImportField.legacyRef) header,
    ];
    final upserts = <Map<String, Object?>>[];
    final stamps = <Map<String, Object?>>[];
    final clears = <Map<String, Object?>>[];
    for (final p in changes.records) {
      final r = p.record;
      if (r.isArchived) {
        clears.add({'id': r.id, 'cols': dataHeaders});
      } else if (p.state == SheetState.linked) {
        if (p.sheetRow != null) stamps.add({'id': r.id, 'row': p.sheetRow});
      } else {
        upserts.add({
          'id': r.id,
          'row': ?p.sheetRow,
          'cells': recordCells(v, r),
          if (v.headers[ImportField.legacyRef] case final h?) 'ifBlank': {h: '#'},
          'unlessFormula': {
            ?v.weekdayHeader: _weekdays[r.serviceDate.weekday - 1],
            ?v.monthHeader: Dates.toJson(r.serviceDate).substring(0, 7),
          },
        });
      }
    }
    for (final id in changes.removals) {
      clears.add({'id': id, 'cols': dataHeaders});
    }
    return SheetOp(
      sheet: v.sheet,
      headerRow: v.headerRow,
      create: v.create,
      ensureHeaders: [?v.headers[ImportField.paymentMethod]],
      anchor: v.headers[ImportField.serviceDate],
      upserts: upserts,
      stamps: stamps,
      clears: clears,
    );
  }

  /// The visits row of [r], keyed by header.
  static Map<String, Object?> recordCells(VisitsLayout v, ServiceRecord r) {
    final cells = <String, Object?>{};
    void put(ImportField field, Object? value) {
      final header = v.headers[field];
      if (header != null) cells[header] = value ?? '';
    }

    put(ImportField.serviceDate, {'d': Dates.toJson(r.serviceDate)});
    put(ImportField.serviceTime, r.serviceTime == null ? null : legacyTime(r.serviceTime!));
    if (v.headers.containsKey(ImportField.patientName)) {
      put(ImportField.customerName, r.customerName);
      put(ImportField.patientName, r.patientName);
    } else {
      // The original workbook has one name column: the person who was treated.
      put(ImportField.customerName, r.patientName ?? r.customerName);
    }
    put(ImportField.phone, r.customerPhone);
    put(ImportField.address, r.customerAddress);
    put(ImportField.area, r.areaName);
    put(ImportField.nurse, r.nurseName);
    put(ImportField.service, r.serviceName);
    put(ImportField.price, r.price.toJson());
    put(ImportField.paymentMethod, paymentText(r.paymentMethod));
    put(ImportField.status, received);
    put(ImportField.notes, r.notes);
    return cells;
  }

  /// Times as the workbook writes them: `9م`, `7:30م`, `12ص`.
  static String legacyTime(LocalTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final suffix = t.hour < 12 ? 'ص' : 'م';
    return t.minute == 0 ? '$hour$suffix' : '$hour:${t.minute.toString().padLeft(2, '0')}$suffix';
  }

  static String paymentText(PaymentMethod method) => switch (method) {
    PaymentMethod.cash => 'نقدي',
    PaymentMethod.electronic => 'إلكتروني',
    PaymentMethod.unspecified => '',
  };

  // -------------------------------------------------------------- customers

  SheetOp? _cases(CasesLayout c, SheetChanges changes) {
    if (changes.customers.isEmpty) return null;
    return SheetOp(
      sheet: c.sheet,
      headerRow: c.headerRow,
      create: c.create,
      anchor: c.name,
      upserts: [
        for (final p in changes.customers)
          // Customers loaded from the sheet without a phone cannot be matched
          // to their row: they are left as they are there.
          if (p.state == SheetState.changed || p.customer.phone != null)
            {
              'id': p.customer.id,
              if (p.customer.phone case final phone?) 'match': {'col': c.phone, 'value': phone},
              if (p.state == SheetState.linked) 'overwrite': false,
              'cells': {
                c.name: p.customer.fullName,
                c.phone: p.customer.phone ?? '',
                ?c.address: p.customer.address ?? '',
                ?c.area: p.customer.areaName,
              },
            },
      ],
    );
  }

  // -------------------------------------------------------------- lists

  SheetOp? _lists(ListsLayout l, SheetChanges changes) {
    // Names loaded from the sheet are already in it.
    final items = changes.items.where((i) => i.state == SheetState.changed).toList();
    if (items.isEmpty) return null;
    return SheetOp(
      sheet: l.sheet,
      headerRow: l.headerRow,
      create: l.create,
      ensureHeaders: [l.services, l.price, l.nurses, l.areas],
      appends: [
        for (final i in items)
          switch (i.kind) {
            ListKind.service => {
              'col': l.services,
              'value': i.name,
              'also': {l.price: i.price?.toJson() ?? '**'},
              'update': true,
            },
            ListKind.nurse => {'col': l.nurses, 'value': i.name},
            ListKind.area => {'col': l.areas, 'value': i.name},
          },
      ],
    );
  }
}
