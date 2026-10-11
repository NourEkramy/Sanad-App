import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/sanad_database.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../areas/data/local_area_repository.dart';
import '../../care_services/data/local_care_service_repository.dart';
import '../../customers/data/local_customer_repository.dart';
import '../../nurses/data/local_nurse_repository.dart';
import '../../records/data/record_mapper.dart';
import '../../records/domain/entities/record_filter.dart';
import '../domain/excel_repositories.dart';
import '../domain/export/export_models.dart';
import '../domain/import/import_plan.dart';

class LocalImportRepository implements ImportRepository {
  LocalImportRepository(this._db);

  final SanadDatabase _db;

  @override
  Future<Result<ExistingData>> existingData() => guard(() async {
    final reader = _db.reader;
    Future<Set<String>> keys(String table) async =>
        (await reader.query(table, columns: ['name_normalized'])).map((r) => r['name_normalized']! as String).toSet();

    final phones = await reader.query('customers', columns: ['phone'], where: 'phone IS NOT NULL');
    final committed = await reader.rawQuery("SELECT COUNT(*) AS n FROM import_batches WHERE status = 'committed'");
    return ExistingData(
      areaKeys: await keys('areas'),
      nurseKeys: await keys('nurses'),
      serviceKeys: await keys('services'),
      phones: phones.map((r) => r['phone']! as String).toSet(),
      committedImports: committed.first['n']! as int,
    );
  });

  /// Everything in one transaction: either the whole file is imported or
  /// nothing is. Areas, nurses, services and customers that already exist
  /// (same normalised name / same phone) are reused and never modified; what
  /// is created is tagged with the batch so [rollback] can remove it.
  @override
  Future<Result<ImportResult>> commit(ImportPlan plan, {required String fileName, required String fileSha256}) =>
      guard(() async {
        final payload = plan.toPayload(fileName: fileName, fileSha256: fileSha256);
        final result = await _db.write((txn) => _import(txn, payload));
        return ImportResult.fromJson(result);
      });

  Future<Map<String, dynamic>> _import(Transaction txn, Map<String, Object?> payload) async {
    final already = await txn.query(
      'import_batches',
      columns: ['id'],
      where: "file_sha256 = ? AND status = 'committed'",
      whereArgs: [payload['file_sha256']],
    );
    if (already.isNotEmpty) throw const BusinessRuleFailure('already_imported');

    final batchId = _db.newId();
    final at = _db.timestamp();
    await txn.insert('import_batches', {
      'id': batchId,
      'file_name': payload['file_name'],
      'file_sha256': payload['file_sha256'],
      'sheet_name': payload['sheet_name'],
      'summary': jsonEncode(payload['summary'] ?? const {}),
      'created_at': at,
    });

    final created = {'areas': 0, 'nurses': 0, 'services': 0, 'customers': 0, 'records': 0};
    List<Map<String, Object?>> items(String key) => ((payload[key] as List?) ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, Object?>())
        .toList();

    // Reference data: match by normalised name, create only what is missing.
    Future<Map<String, String>> reference(String table, String counter, {bool withPrice = false}) async {
      final ids = <String, String>{};
      for (final item in items(counter)) {
        final name = TextNormalizer.clean(item['name'] as String?);
        final key = TextNormalizer.key(name);
        final existing = await txn.query(table, columns: ['id'], where: 'name_normalized = ?', whereArgs: [key]);
        var id = existing.isEmpty ? null : existing.first['id']! as String;
        if (id == null) {
          id = _db.newId();
          await txn.insert(table, {
            'id': id,
            'name': name,
            'name_normalized': key,
            if (withPrice) 'default_price': _piasters(item['default_price']),
            'import_batch_id': batchId,
            'created_at': at,
            'updated_at': at,
          });
          created[counter] = created[counter]! + 1;
        }
        ids[item['key']! as String] = id;
      }
      return ids;
    }

    final areas = await reference('areas', 'areas');
    final nurses = await reference('nurses', 'nurses');
    final services = await reference('services', 'services', withPrice: true);

    // Customers: the phone is the identity; existing customers are untouched.
    final customers = <String, String>{};
    var matched = 0;
    for (final item in items('customers')) {
      final phone = _blankToNull(item['phone']);
      String? id;
      if (phone != null) {
        final existing = await txn.query('customers', columns: ['id'], where: 'phone = ?', whereArgs: [phone]);
        if (existing.isNotEmpty) id = existing.first['id']! as String;
      }
      if (id == null) {
        id = _db.newId();
        final name = TextNormalizer.clean(item['full_name'] as String?);
        await txn.insert('customers', {
          'id': id,
          'full_name': name,
          'name_normalized': TextNormalizer.key(name),
          'phone': phone,
          'address': _blankToNull(item['address']),
          'area_id': areas[item['area_key']],
          'notes': _blankToNull(item['notes']),
          'needs_review': item['needs_review'] == true ? 1 : 0,
          'import_batch_id': batchId,
          'created_at': at,
          'updated_at': at,
        });
        created['customers'] = created['customers']! + 1;
      } else {
        matched++;
      }
      customers[item['key']! as String] = id;
    }

    // Records keep the legacy row's own address/area and the names of that
    // time; the customer's name/phone come from the customer row.
    for (final item in items('records')) {
      final customerId = customers[item['customer_key']]!;
      final customer = (await txn.query(
        'customers',
        columns: ['full_name', 'phone', 'address', 'area_id'],
        where: 'id = ?',
        whereArgs: [customerId],
      )).first;
      final areaId = areas[item['area_key']] ?? customer['area_id'];
      final areaName =
          _blankToNull(item['area_name']) ??
          (await txn.query('areas', columns: ['name'], where: 'id = ?', whereArgs: [areaId])).first['name'];
      final patient = _blankToNull(item['patient_name']);
      // A record loaded back from a connected Google Sheet keeps its ID there.
      final sheetId = item['id'] as String?;
      final taken =
          sheetId == null ||
          (await txn.query('service_records', columns: ['id'], where: 'id = ?', whereArgs: [sheetId])).isNotEmpty;
      final recordId = taken ? _db.newId() : sheetId;
      await txn.insert('service_records', {
        'id': recordId,
        'customer_id': customerId,
        'nurse_id': nurses[item['nurse_key']],
        'service_id': services[item['service_key']],
        'patient_name': patient,
        'patient_name_normalized': patient == null ? null : TextNormalizer.key(patient),
        'price': _piasters(item['price']),
        'payment_method': item['payment_method'],
        'service_date': item['service_date'],
        'service_time': _blankToNull(item['service_time']),
        'notes': _blankToNull(item['notes']),
        'legacy_ref': item['legacy_ref'],
        'import_batch_id': batchId,
        'area_id': areaId,
        'customer_name_snapshot': customer['full_name'],
        'customer_phone_snapshot': customer['phone'],
        'address_snapshot': _blankToNull(item['address']) ?? customer['address'],
        'area_name_snapshot': areaName ?? '',
        'nurse_name_snapshot': await _name(txn, 'nurses', nurses[item['nurse_key']]),
        'service_name_snapshot': await _name(txn, 'services', services[item['service_key']]),
        'created_at': at,
        'updated_at': at,
      });
      await txn.insert('import_rows', {
        'batch_id': batchId,
        'row_number': item['row_number'],
        'outcome': 'imported',
        'record_id': recordId,
        'raw': jsonEncode(item['raw'] ?? const {}),
        'messages': jsonEncode(item['messages'] ?? const []),
      });
      created['records'] = created['records']! + 1;
    }

    for (final item in items('skipped')) {
      await txn.insert('import_rows', {
        'batch_id': batchId,
        'row_number': item['row_number'],
        'outcome': 'skipped',
        'raw': jsonEncode(item['raw'] ?? const {}),
        'messages': jsonEncode(item['messages'] ?? const []),
      });
    }

    final summary = {
      ...((payload['summary'] as Map?)?.cast<String, Object?>() ?? const {}),
      'created': created,
      'matched_customers': matched,
    };
    await txn.update('import_batches', {'summary': jsonEncode(summary)}, where: 'id = ?', whereArgs: [batchId]);
    return {'batch_id': batchId, 'created': created, 'matched_customers': matched};
  }

  @override
  Future<Result<List<ImportBatch>>> batches() => guard(() async {
    final rows = await _db.reader.query('import_batches', orderBy: 'created_at DESC');
    return [
      for (final r in rows)
        ImportBatch(
          id: r['id']! as String,
          fileName: r['file_name']! as String,
          sheetName: r['sheet_name']! as String,
          createdAt: DateTime.parse(r['created_at']! as String).toLocal(),
          isRolledBack: r['status'] == 'rolled_back',
          recordCount: _createdRecords(r['summary'] as String?),
        ),
    ];
  });

  /// Removes everything the batch created, unless it has been used since:
  /// a customer with records added later becomes a regular customer, and an
  /// area/nurse/service still referenced is kept.
  @override
  Future<VoidResult> rollback(String batchId) => guard(() async {
    await _db.write((txn) async {
      final batch = await txn.query(
        'import_batches',
        columns: ['summary', 'file_sha256'],
        where: "id = ? AND status = 'committed'",
        whereArgs: [batchId],
      );
      if (batch.isEmpty) throw const BusinessRuleFailure('batch_not_found');

      final args = [batchId];
      // Rows Sanad already wrote into the connected Google Sheet are cleared
      // there too — except for data that was loaded from that sheet.
      if (!(batch.first['file_sha256']! as String).startsWith(sheetImportPrefix)) {
        await txn.rawInsert(
          'INSERT OR REPLACE INTO sheet_removals (record_id, sheet_row, created_at) '
          'SELECT id, sheet_row, ? FROM service_records WHERE import_batch_id = ? AND sheet_row IS NOT NULL',
          [_db.timestamp(), batchId],
        );
      }
      final records = await txn.delete('service_records', where: 'import_batch_id = ?', whereArgs: args);
      final customers = await txn.delete(
        'customers',
        where:
            'import_batch_id = ? AND NOT EXISTS (SELECT 1 FROM service_records r WHERE r.customer_id = customers.id)',
        whereArgs: args,
      );
      final areas = await txn.delete(
        'areas',
        where:
            'import_batch_id = ? AND NOT EXISTS (SELECT 1 FROM customers c WHERE c.area_id = areas.id) '
            'AND NOT EXISTS (SELECT 1 FROM service_records r WHERE r.area_id = areas.id)',
        whereArgs: args,
      );
      final nurses = await txn.delete(
        'nurses',
        where: 'import_batch_id = ? AND NOT EXISTS (SELECT 1 FROM service_records r WHERE r.nurse_id = nurses.id)',
        whereArgs: args,
      );
      final services = await txn.delete(
        'services',
        where: 'import_batch_id = ? AND NOT EXISTS (SELECT 1 FROM service_records r WHERE r.service_id = services.id)',
        whereArgs: args,
      );
      for (final table in ['customers', 'areas', 'nurses', 'services']) {
        await txn.update(table, {'import_batch_id': null}, where: 'import_batch_id = ?', whereArgs: args);
      }

      final summary = (jsonDecode(batch.first['summary']! as String) as Map).cast<String, Object?>();
      summary['rollback'] = {
        'records': records,
        'customers': customers,
        'areas': areas,
        'nurses': nurses,
        'services': services,
      };
      await txn.update(
        'import_batches',
        {'status': 'rolled_back', 'rolled_back_at': _db.timestamp(), 'summary': jsonEncode(summary)},
        where: 'id = ?',
        whereArgs: args,
      );
    });
  });

  static int _createdRecords(String? summary) {
    if (summary == null) return 0;
    final created = (jsonDecode(summary) as Map)['created'];
    return created is Map ? (created['records'] as num?)?.toInt() ?? 0 : 0;
  }

  static int? _piasters(Object? pounds) => pounds == null ? null : Money.fromJson(pounds).piasters;

  static String? _blankToNull(Object? value) {
    final text = (value as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static Future<String> _name(Transaction txn, String table, String? id) async =>
      (await txn.query(table, columns: ['name'], where: 'id = ?', whereArgs: [id])).first['name']! as String;
}

class LocalExportRepository implements ExportRepository {
  LocalExportRepository(this._db);

  final SanadDatabase _db;

  @override
  Future<Result<ExportData>> load(ExportRequest request) => guard(() async {
    final reader = _db.reader;
    final sheets = request.sheets;

    Future<List<Map<String, Object?>>> records() async {
      final filter = RecordFilter(from: request.from, to: request.to, sort: RecordSort.oldest);
      final (where, args) = RecordMapper.where(filter);
      return reader.rawQuery('${RecordMapper.details} $where ORDER BY ${RecordMapper.orderBy(filter.sort)}', args);
    }

    const none = <Map<String, Object?>>[];
    final recordRows = sheets.contains(ExportSheet.records) ? await records() : none;
    final customerRows = sheets.contains(ExportSheet.customers)
        ? await reader.rawQuery('${LocalCustomerRepository.overview} WHERE c.deleted_at IS NULL ORDER BY c.full_name')
        : none;
    final nurseRows = sheets.contains(ExportSheet.nurses) ? await reader.query('nurses', orderBy: 'name') : none;
    final serviceRows = sheets.contains(ExportSheet.services) ? await reader.query('services', orderBy: 'name') : none;
    final areaRows = sheets.contains(ExportSheet.areas) ? await reader.query('areas', orderBy: 'name') : none;

    return ExportData(
      records: recordRows.map(RecordMapper.fromRow).toList(),
      customers: customerRows.map(LocalCustomerRepository.fromRow).toList(),
      nurses: nurseRows.map(LocalNurseRepository.fromRow).toList(),
      services: serviceRows.map(LocalCareServiceRepository.fromRow).toList(),
      areas: areaRows.map(LocalAreaRepository.fromRow).toList(),
    );
  });
}
