import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/database/sheet_state.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/excel/domain/import/column_mapping.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';
import 'package:sanad/features/sheet/domain/sheet_link.dart';
import 'package:sanad/features/sheet/domain/sheet_ops.dart';
import 'package:sanad/features/sheet/domain/sheet_sync.dart';

import '../../helpers/fakes.dart';

ServiceRecord record({
  String id = 'r1',
  String? patient,
  String? notes,
  LocalTime? time = const LocalTime(21, 0),
  PaymentMethod payment = PaymentMethod.cash,
  bool archived = false,
}) => ServiceRecord(
  id: id,
  customerId: 'c1',
  customerName: 'عميل أول',
  customerPhone: '01011111111',
  customerAddress: 'شارع 1',
  areaName: 'سموحة',
  nurseId: 'n1',
  nurseName: 'ممرض أول',
  serviceId: 's1',
  serviceName: 'حقن عضل',
  price: Money.pounds(75),
  paymentMethod: payment,
  serviceDate: DateTime(2026, 10, 5),
  serviceTime: time,
  patientName: patient,
  notes: notes,
  isArchived: archived,
  createdAt: testNow,
);

PendingRecord pending(ServiceRecord r, {int state = SheetState.changed, int? row}) =>
    PendingRecord(record: r, state: state, version: 'v-${r.id}', sheetRow: row);

void main() {
  const builder = SheetOpsBuilder();
  final layout = SheetLayout(
    visits: VisitsLayout.standard(),
    cases: CasesLayout.standard(),
    lists: ListsLayout.standard(),
  );
  final visits = layout.visits;

  group('cells', () {
    test('times are written the way the workbook writes them', () {
      expect(SheetOpsBuilder.legacyTime(const LocalTime(21, 0)), '9م');
      expect(SheetOpsBuilder.legacyTime(const LocalTime(19, 30)), '7:30م');
      expect(SheetOpsBuilder.legacyTime(const LocalTime(9, 5)), '9:05ص');
      expect(SheetOpsBuilder.legacyTime(const LocalTime(0, 0)), '12ص');
      expect(SheetOpsBuilder.legacyTime(const LocalTime(12, 0)), '12م');
    });

    test('a record fills every column of the original visits sheet', () {
      expect(SheetOpsBuilder.recordCells(visits, record(notes: 'بعد الظهر')), {
        'تاريخ الزيارة': {'d': '2026-10-05'},
        'وقت الزيارة': '9م',
        'اسم المريض / الحالة': 'عميل أول',
        'رقم التليفون': '01011111111',
        'العنوان التفصيلي': 'شارع 1',
        'المنطقة': 'سموحة',
        'اسم الممرض / الفني': 'ممرض أول',
        'الخدمة المُقدَّمة': 'حقن عضل',
        'ثمن الزيارة (ج.م)': 75,
        'حالة الاستلام': SheetOpsBuilder.received,
        'ملاحظات': 'بعد الظهر',
        paymentHeader: 'نقدي',
      });
    });

    test('the one name column holds the person treated; empty values clear the cell', () {
      final cells = SheetOpsBuilder.recordCells(
        visits,
        record(patient: 'ابن العميل', time: null, payment: PaymentMethod.unspecified),
      );
      expect(cells['اسم المريض / الحالة'], 'ابن العميل');
      expect(cells['وقت الزيارة'], '');
      expect(cells['ملاحظات'], '');
      expect(cells[paymentHeader], '');
    });

    test('a sheet with separate customer and patient columns gets both', () {
      const split = VisitsLayout(
        sheet: 'Visits',
        headerRow: 1,
        headers: {
          ImportField.serviceDate: 'Date',
          ImportField.customerName: 'Customer',
          ImportField.patientName: 'Patient',
          ImportField.price: 'Price',
        },
      );
      expect(SheetOpsBuilder.recordCells(split, record(patient: 'ابن العميل')), {
        'Date': {'d': '2026-10-05'},
        'Customer': 'عميل أول',
        'Patient': 'ابن العميل',
        'Price': 75,
      });
    });
  });

  group('visits', () {
    test('new and changed records are upserted, keeping the running number and formulas', () {
      final batch = builder.build(
        layout,
        SheetChanges(
          records: [
            pending(record()),
            pending(record(id: 'r2'), row: 7),
          ],
        ),
      );
      final op = batch.ops.single;
      expect(op.sheet, 'سجل الزيارات');
      expect(op.headerRow, 1);
      expect(op.anchor, 'تاريخ الزيارة', reason: 'new rows go below the last dated row');
      expect(op.ensureHeaders, [paymentHeader]);
      expect(op.create, visits.create);
      expect(op.upserts.first, {
        'id': 'r1',
        'cells': SheetOpsBuilder.recordCells(visits, record()),
        'ifBlank': {'م': '#'},
        'unlessFormula': {'اليوم': 'Monday', 'الشهر': '2026-10'},
      });
      expect(op.upserts.last['row'], 7);
      expect(() => jsonEncode([for (final o in batch.ops) o.toJson()]), returnsNormally);
    });

    test('rows loaded from the sheet only get their ID; archived and deleted records are cleared', () {
      final op = builder
          .build(
            layout,
            SheetChanges(
              records: [
                pending(record(id: 'loaded'), state: SheetState.linked, row: 12),
                pending(record(id: 'loaded-no-row'), state: SheetState.linked),
                pending(record(id: 'archived', archived: true), row: 9),
              ],
              removals: const ['rolled-back'],
            ),
          )
          .ops
          .single;
      expect(op.upserts, isEmpty);
      expect(op.stamps, [
        {'id': 'loaded', 'row': 12},
      ]);
      final cleared = [for (final h in visits.headers.values) h]..remove('م');
      expect(op.clears, [
        {'id': 'archived', 'cols': cleared},
        {'id': 'rolled-back', 'cols': cleared},
      ]);
    });

    test('the answer marks every row of the batch as written, with its row number', () {
      final batch = builder.build(
        layout,
        SheetChanges(
          records: [
            pending(record()),
            pending(record(id: 'archived', archived: true), row: 9),
            pending(record(id: 'loaded-no-row'), state: SheetState.linked),
          ],
          removals: const ['rolled-back'],
        ),
      );
      final receipt = batch.receipt(const [
        SheetWriteResult(sheet: 'سجل الزيارات', rows: {'r1': 15, 'archived': null}),
      ]);
      expect(receipt.records, {
        'r1': ('v-r1', 15),
        'archived': ('v-archived', null),
        'loaded-no-row': ('v-loaded-no-row', null),
      });
      expect(receipt.removals, ['rolled-back']);
    });
  });

  group('customers and lists', () {
    PendingCustomer pc(String id, {String? phone, int state = SheetState.changed}) => PendingCustomer(
      customer: customer(id: id, phone: phone, name: 'Customer $id', areaName: 'سموحة', address: null),
      state: state,
      version: 'v-$id',
    );

    test('customers are matched by phone; those loaded from the sheet only fill blanks', () {
      final op = builder
          .build(
            layout,
            SheetChanges(
              customers: [
                pc('new', phone: '01011111111'),
                pc('loaded', phone: '01022222222', state: SheetState.linked),
                pc('loaded-no-phone', state: SheetState.linked),
                pc('new-no-phone'),
              ],
            ),
          )
          .ops
          .single;
      expect(op.sheet, 'بيانات الحالات');
      expect(op.anchor, 'اسم المريض / الحالة');
      expect(op.upserts.map((u) => u['id']), ['new', 'loaded', 'new-no-phone']);
      expect(op.upserts.first, {
        'id': 'new',
        'match': {'col': 'رقم التليفون', 'value': '01011111111'},
        'cells': {
          'اسم المريض / الحالة': 'Customer new',
          'رقم التليفون': '01011111111',
          'العنوان التفصيلي': '',
          'المنطقة': 'سموحة',
        },
      });
      expect(op.upserts[1]['overwrite'], isFalse);
      expect(op.upserts.last.containsKey('match'), isFalse);
    });

    test('new list entries are appended; a service also gets its price ("**" when it varies)', () {
      PendingListItem item(ListKind kind, String name, {Money? price, int state = SheetState.changed}) =>
          PendingListItem(kind: kind, id: name, name: name, price: price, state: state, version: 'v');
      final batch = builder.build(
        layout,
        SheetChanges(
          items: [
            item(ListKind.service, 'حقن عضل', price: Money.pounds(75)),
            item(ListKind.service, 'صيدلية'),
            item(ListKind.nurse, 'ممرض جديد'),
            item(ListKind.area, 'العجمي'),
            item(ListKind.area, 'من الشيت', state: SheetState.linked),
          ],
        ),
      );
      final op = batch.ops.single;
      expect(op.sheet, 'قوائم');
      expect(op.ensureHeaders, ['الخدمات', 'السعر', 'الممرضين', 'المناطق']);
      expect(op.appends, [
        {
          'col': 'الخدمات',
          'value': 'حقن عضل',
          'also': {'السعر': 75},
          'update': true,
        },
        {
          'col': 'الخدمات',
          'value': 'صيدلية',
          'also': {'السعر': '**'},
          'update': true,
        },
        {'col': 'الممرضين', 'value': 'ممرض جديد'},
        {'col': 'المناطق', 'value': 'العجمي'},
      ]);
      expect(batch.receipt(const []).items, hasLength(5), reason: 'entries from the sheet are marked as written');
    });

    test('nothing to write, no request', () {
      expect(builder.build(layout, const SheetChanges()).ops, isEmpty);
      const onlyLoaded = SheetChanges(
        items: [PendingListItem(kind: ListKind.nurse, id: 'n', name: 'n', state: SheetState.linked, version: 'v')],
      );
      expect(builder.build(layout, onlyLoaded).ops, isEmpty);
    });
  });
}
