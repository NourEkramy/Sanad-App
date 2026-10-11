import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/database/sanad_database.dart';
import 'package:sanad/core/database/sheet_state.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/excel/data/local_excel_repositories.dart';
import 'package:sanad/features/excel/domain/excel_repositories.dart';
import 'package:sanad/features/excel/domain/import/column_mapping.dart';
import 'package:sanad/features/excel/domain/import/import_planner.dart';
import 'package:sanad/features/sheet/data/local_sheet_store.dart';
import 'package:sanad/features/sheet/domain/sheet_sync.dart';

import '../../helpers/database.dart';
import '../../helpers/legacy_sheet.dart';

void main() {
  late SanadDatabase db;
  late LocalSheetStore store;
  var tick = 0;

  setUp(() async {
    db = await openTestDatabase(clock: () => DateTime(2026, 10, 11).add(Duration(milliseconds: tick++)));
    store = LocalSheetStore(db);
  });

  tearDown(() => db.close());

  Future<int> pending() async => (await store.pendingCount()).valueOrNull!;

  /// Marks everything that is waiting as written.
  Future<void> writeAll() async {
    final changes = (await store.pending(limit: 1000)).valueOrNull!;
    await store.markWritten(
      SheetReceipt(
        records: {for (final p in changes.records) p.record.id: (p.version, 10)},
        customers: {for (final p in changes.customers) p.customer.id: (p.version, 5)},
        items: [for (final i in changes.items) (i.kind, i.id, i.version)],
        removals: changes.removals,
      ),
    );
  }

  Future<String> importLegacy({String sha = 'file'}) async {
    final imports = LocalImportRepository(db);
    final table = legacySheet();
    final plan = const ImportPlanner(unspecifiedLabel: 'غير محدد')
        .plan(table, const ColumnDetector().detect(table)!, existing: (await imports.existingData()).valueOrNull!);
    return (await imports.commit(plan, fileName: 'f.xlsx', fileSha256: sha)).valueOrNull!.batchId;
  }

  test('a new install has only the built-in lists to add to a sheet', () async {
    expect(await pending(), 51 + 9);
    expect((await store.hasOwnData()).valueOrNull, isFalse);
    final changes = (await store.pending(limit: 1000)).valueOrNull!;
    expect(changes.items.where((i) => i.kind == ListKind.service), hasLength(51));
    expect(changes.records, isEmpty);
  });

  test('a row changed while it was being written stays waiting', () async {
    await writeAll();
    final batchId = await importLegacy();
    expect(batchId, isNotEmpty);
    final first = (await store.pending()).valueOrNull!;
    expect(first.records, isNotEmpty);

    // One record is corrected after the batch was read, before it was marked.
    final edited = first.records.first.record.id;
    await db.write(
      (txn) => txn.update(
        'service_records',
        {'notes': 'later', 'updated_at': db.timestamp(), 'sheet_state': SheetState.changed},
        where: 'id = ?',
        whereArgs: [edited],
      ),
    );
    await store.markWritten(SheetReceipt(records: {for (final p in first.records) p.record.id: (p.version, 10)}));
    final left = (await store.pending()).valueOrNull!;
    expect(left.records.map((p) => p.record.id), [edited]);
  });

  test('records loaded from the sheet are linked to their row', () async {
    await writeAll();
    final batchId = await importLegacy(sha: 'sheet:abc');
    final rows = (await db.reader.query(
      'import_rows',
      where: "batch_id = ? AND outcome = 'imported'",
      whereArgs: [batchId],
    ));
    final withId = rows.first;
    await store.linkImported(batchId, {withId['row_number']! as int: withId['record_id']! as String});

    final records = (await store.pending(limit: 1000)).valueOrNull!.records;
    expect(records, hasLength(rows.length - 1), reason: 'the row that already has its ID needs nothing');
    expect(records.every((p) => p.state == SheetState.linked && p.sheetRow != null), isTrue);
    expect(await pending(), records.length + (await store.pending(limit: 1000)).valueOrNull!.customers.length);
  });

  test('undoing an Excel import clears the rows it had written; undoing a sheet load does not', () async {
    await writeAll();
    final imports = LocalImportRepository(db);
    final excel = await importLegacy();
    await writeAll();
    await imports.rollback(excel);
    final removals = (await store.pending(limit: 1000)).valueOrNull!.removals;
    expect(removals, isNotEmpty);
    await writeAll();
    expect(await pending(), 0);

    final sheet = await importLegacy(sha: '${sheetImportPrefix}xyz');
    await writeAll();
    await imports.rollback(sheet);
    expect((await store.pending(limit: 1000)).valueOrNull!.removals, isEmpty);
  });

  test("the sheet's lists and customers are added once; its prices win", () async {
    const extras = SheetExtras(
      customers: [('عميل أول', '01011111111', 'شارع 1', 'منطقة جديدة'), ('عميل بلا منطقة', '01022222222', null, null)],
      services: [('حقن عضل', null), ('خدمة جديدة', null)],
      hasServicePrices: true,
      nurses: ['ممرض أول'],
      areas: ['سموحة'],
    );
    await store.addExtras(extras, unspecifiedArea: 'غير محدد');
    await store.addExtras(extras, unspecifiedArea: 'غير محدد');

    final customers = await db.reader.query('customers', orderBy: 'phone');
    expect(customers.map((c) => c['full_name']), ['عميل أول', 'عميل بلا منطقة']);
    expect(customers.every((c) => c['sheet_state'] == SheetState.linked), isTrue);
    final areas = {for (final a in await db.reader.query('areas')) a['name']! as String: a['sheet_state']};
    expect(areas['منطقة جديدة'], SheetState.linked);
    expect(areas['غير محدد'], SheetState.linked);
    expect(areas['سموحة'], SheetState.linked, reason: 'already in the sheet');
    expect(areas['البيطاش'], SheetState.changed, reason: 'built in, not in the sheet: will be added');

    final injection = (await db.reader.query('services', where: 'name = ?', whereArgs: ['حقن عضل'])).single;
    expect(injection['default_price'], isNull, reason: '"**" in the sheet: the price varies');
    expect(injection['sheet_state'], SheetState.linked);

    // Without a price column, the phone's prices are kept.
    await db.write(
      (txn) => txn.update(
        'services',
        {'default_price': Money.pounds(75).piasters, 'sheet_state': SheetState.changed},
        where: 'name = ?',
        whereArgs: ['حقن عضل'],
      ),
    );
    await store.addExtras(const SheetExtras(services: [('حقن عضل', null)]), unspecifiedArea: 'غير محدد');
    final kept = (await db.reader.query('services', where: 'name = ?', whereArgs: ['حقن عضل'])).single;
    expect(kept['default_price'], Money.pounds(75).piasters);
  });

  test('keeping the phone data marks everything for the sheet; clearing resets', () async {
    await importLegacy();
    await writeAll();
    expect(await pending(), 0);
    expect((await store.hasOwnData()).valueOrNull, isTrue);

    await store.markAllChanged();
    expect(await pending(), greaterThan(0));

    await store.clearAll();
    expect((await store.hasOwnData()).valueOrNull, isFalse);
    expect(await pending(), 51 + 9);
  });
}
