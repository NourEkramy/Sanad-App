import 'package:sqflite/sqflite.dart';

import '../../../core/database/sanad_database.dart';
import '../../../core/database/sheet_state.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../customers/data/local_customer_repository.dart';
import '../../records/data/record_mapper.dart';
import '../domain/sheet_sync.dart';

class LocalSheetStore implements SheetStore {
  LocalSheetStore(this._db);

  final SanadDatabase _db;

  static const _lists = {ListKind.service: 'services', ListKind.nurse: 'nurses', ListKind.area: 'areas'};

  @override
  Stream<void> get changes => _db.changes;

  @override
  Future<Result<SheetChanges>> pending({int limit = 100}) => guard(() async {
    final reader = _db.reader;
    final records = await reader.rawQuery(
      '${RecordMapper.details} WHERE r.sheet_state <> ? ORDER BY r.service_date, r.created_at LIMIT ?',
      [SheetState.synced, limit],
    );
    final customers = await reader.rawQuery(
      '${LocalCustomerRepository.overview} WHERE c.sheet_state <> ? ORDER BY c.created_at LIMIT ?',
      [SheetState.synced, limit],
    );
    final items = <PendingListItem>[];
    for (final MapEntry(key: kind, value: table) in _lists.entries) {
      final rows = await reader.query(table, where: 'sheet_state <> ?', whereArgs: [SheetState.synced], limit: limit);
      for (final row in rows) {
        items.add(
          PendingListItem(
            kind: kind,
            id: row['id']! as String,
            name: row['name']! as String,
            price: row['default_price'] == null ? null : Money.piasters(row['default_price']! as int),
            state: row['sheet_state']! as int,
            version: row['updated_at']! as String,
          ),
        );
      }
    }
    final removals = await reader.query('sheet_removals', columns: ['record_id'], limit: limit);
    return SheetChanges(
      records: [
        for (final row in records)
          PendingRecord(
            record: RecordMapper.fromRow(row),
            state: row['sheet_state']! as int,
            version: row['updated_at']! as String,
            sheetRow: row['sheet_row'] as int?,
          ),
      ],
      customers: [
        for (final row in customers)
          PendingCustomer(
            customer: LocalCustomerRepository.fromRow(row),
            state: row['sheet_state']! as int,
            version: row['updated_at']! as String,
          ),
      ],
      items: items,
      removals: [for (final row in removals) row['record_id']! as String],
    );
  });

  @override
  Future<Result<int>> pendingCount() => guard(() async {
    final rows = await _db.reader.rawQuery(
      'SELECT (SELECT COUNT(*) FROM service_records WHERE sheet_state <> ?1) '
      '+ (SELECT COUNT(*) FROM customers WHERE sheet_state <> ?1) '
      '+ (SELECT COUNT(*) FROM services WHERE sheet_state = ?2) '
      '+ (SELECT COUNT(*) FROM nurses WHERE sheet_state = ?2) '
      '+ (SELECT COUNT(*) FROM areas WHERE sheet_state = ?2) '
      '+ (SELECT COUNT(*) FROM sheet_removals) AS n',
      [SheetState.synced, SheetState.changed],
    );
    return rows.first['n']! as int;
  });

  @override
  Future<VoidResult> markWritten(SheetReceipt receipt) => guard(() async {
    await _db.write((txn) async {
      final batch = txn.batch();
      // Only if the row did not change again while it was being written.
      for (final MapEntry(key: id, value: (version, row)) in receipt.records.entries) {
        batch.update(
          'service_records',
          {'sheet_state': SheetState.synced, 'sheet_row': row},
          where: 'id = ? AND updated_at = ?',
          whereArgs: [id, version],
        );
      }
      for (final MapEntry(key: id, value: (version, row)) in receipt.customers.entries) {
        batch.update(
          'customers',
          {'sheet_state': SheetState.synced, 'sheet_row': row},
          where: 'id = ? AND updated_at = ?',
          whereArgs: [id, version],
        );
      }
      for (final (kind, id, version) in receipt.items) {
        batch.update(
          _lists[kind]!,
          {'sheet_state': SheetState.synced},
          where: 'id = ? AND updated_at = ?',
          whereArgs: [id, version],
        );
      }
      for (final id in receipt.removals) {
        batch.delete('sheet_removals', where: 'record_id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    }, notify: false);
  });

  @override
  Future<Result<bool>> hasOwnData() => guard(() async {
    final rows = await _db.reader.rawQuery(
      'SELECT (SELECT COUNT(*) FROM customers) + (SELECT COUNT(*) FROM service_records) AS n',
    );
    return (rows.first['n']! as int) > 0;
  });

  @override
  Future<VoidResult> clearAll() => guard(_db.reset);

  @override
  Future<VoidResult> linkImported(String batchId, Map<int, String> sheetIdsByRow) => guard(() async {
    await _db.write((txn) async {
      final rows = await txn.query(
        'import_rows',
        columns: ['row_number', 'record_id'],
        where: "batch_id = ? AND outcome = 'imported' AND record_id IS NOT NULL",
        whereArgs: [batchId],
      );
      final batch = txn.batch();
      for (final row in rows) {
        final sheetRow = row['row_number']! as int;
        final id = row['record_id']! as String;
        batch.update(
          'service_records',
          {
            'sheet_row': sheetRow,
            // A row that already carries this record's ID needs nothing more.
            'sheet_state': sheetIdsByRow[sheetRow] == id ? SheetState.synced : SheetState.linked,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      for (final table in ['customers', 'areas', 'nurses', 'services']) {
        batch.update(table, {'sheet_state': SheetState.linked}, where: 'import_batch_id = ?', whereArgs: [batchId]);
      }
      await batch.commit(noResult: true);
    }, notify: false);
  });

  @override
  Future<VoidResult> addExtras(SheetExtras extras, {required String unspecifiedArea}) => guard(() async {
    await _db.write((txn) async {
      final at = _db.timestamp();
      // [inList]: the name is in the sheet's lists, so the sheet's [values]
      // win and it must not be added there again.
      Future<String> ensure(
        String table,
        String name, {
        bool inList = false,
        Map<String, Object?> values = const {},
      }) async {
        final key = TextNormalizer.key(name);
        final found = await txn.query(
          table,
          columns: ['id', 'sheet_state'],
          where: 'name_normalized = ?',
          whereArgs: [key],
        );
        if (found.isNotEmpty) {
          final id = found.first['id']! as String;
          final update = {
            if (inList) ...values,
            if (inList && found.first['sheet_state'] == SheetState.changed) 'sheet_state': SheetState.linked,
          };
          if (update.isNotEmpty) await txn.update(table, update, where: 'id = ?', whereArgs: [id]);
          return id;
        }
        final id = _db.newId();
        await txn.insert(table, {
          'id': id,
          'name': TextNormalizer.clean(name),
          'name_normalized': key,
          ...values,
          'created_at': at,
          'updated_at': at,
          'sheet_state': SheetState.linked,
        });
        return id;
      }

      for (final (name, price) in extras.services) {
        await ensure(
          'services',
          name,
          inList: true,
          values: {if (extras.hasServicePrices) 'default_price': price?.piasters},
        );
      }
      for (final name in extras.nurses) {
        await ensure('nurses', name, inList: true);
      }
      for (final name in extras.areas) {
        await ensure('areas', name, inList: true);
      }
      for (final (name, phone, address, area) in extras.customers) {
        final exists = await txn.query('customers', columns: ['id'], where: 'phone = ?', whereArgs: [phone]);
        if (exists.isNotEmpty) continue;
        final cleanName = TextNormalizer.clean(name);
        await txn.insert('customers', {
          'id': _db.newId(),
          'full_name': cleanName,
          'name_normalized': TextNormalizer.key(cleanName),
          'phone': phone,
          'address': address,
          'area_id': await ensure('areas', area ?? unspecifiedArea),
          'created_at': at,
          'updated_at': at,
          'sheet_state': SheetState.linked,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  });

  @override
  Future<VoidResult> markAllChanged() => guard(() async {
    await _db.write((txn) async {
      for (final table in ['service_records', 'customers', 'areas', 'nurses', 'services']) {
        await txn.update(table, {'sheet_state': SheetState.changed});
      }
    });
  });
}
