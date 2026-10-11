import 'package:sqflite/sqflite.dart';

import '../../../core/database/sanad_database.dart';
import '../../../core/database/sheet_state.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/local_time.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/text_normalizer.dart';
import '../domain/entities/record_draft.dart';
import '../domain/entities/record_filter.dart';
import '../domain/entities/service_record.dart';
import '../domain/repositories/record_repository.dart';
import 'record_mapper.dart';

class LocalRecordRepository implements RecordRepository {
  LocalRecordRepository(this._db);

  final SanadDatabase _db;

  @override
  Future<Result<ServiceRecord>> add(NewServiceRecord record) => guard(() async {
    await _db.write((txn) async {
      // Saving the same record twice (double tap) is a no-op.
      final existing = await txn.query('service_records', columns: ['id'], where: 'id = ?', whereArgs: [record.id]);
      if (existing.isNotEmpty) return;

      final customer = await _single(
        txn,
        'SELECT c.full_name, c.phone, c.address, c.area_id, c.deleted_at, a.name AS area_name '
        'FROM customers c JOIN areas a ON a.id = c.area_id WHERE c.id = ?',
        record.customerId,
      );
      if (customer['deleted_at'] != null) throw const BusinessRuleFailure('customer_archived');
      final nurse = await _activeName(txn, 'nurses', record.nurseId, 'nurse_inactive');
      final service = await _activeName(txn, 'services', record.serviceId, 'service_inactive');
      final at = _db.timestamp();

      await txn.insert('service_records', {
        'id': record.id,
        'customer_id': record.customerId,
        'nurse_id': record.nurseId,
        'service_id': record.serviceId,
        'patient_name': record.patientName,
        'patient_name_normalized': _normalized(record.patientName),
        'price': record.price.piasters,
        'payment_method': record.paymentMethod.toJson(),
        'service_date': Dates.toJson(record.serviceDate),
        'service_time': record.serviceTime.toJson(),
        'notes': record.notes,
        // Snapshot: the record keeps reading the same even if the customer
        // moves or a nurse/service/area is renamed later.
        'area_id': customer['area_id'],
        'customer_name_snapshot': customer['full_name'],
        'customer_phone_snapshot': customer['phone'],
        'address_snapshot': customer['address'],
        'area_name_snapshot': customer['area_name'],
        'nurse_name_snapshot': nurse,
        'service_name_snapshot': service,
        'created_at': at,
        'updated_at': at,
      });
    });
    return _get(record.id);
  });

  @override
  Future<Result<ServiceRecord>> getById(String id) => guard(() => _get(id));

  Future<ServiceRecord> _get(String id) async {
    final rows = await _db.reader.rawQuery('${RecordMapper.details} WHERE r.id = ?', [id]);
    if (rows.isEmpty) throw const NotFoundFailure();
    return RecordMapper.fromRow(rows.first);
  }

  @override
  Future<Result<List<ServiceRecord>>> customerHistory(String customerId) => guard(() async {
    final (where, args) = RecordMapper.where(const RecordFilter(), customerId: customerId);
    final rows = await _db.reader.rawQuery(
      '${RecordMapper.details} $where ORDER BY ${RecordMapper.orderBy(RecordSort.newest)}',
      args,
    );
    return rows.map(RecordMapper.fromRow).toList();
  });

  @override
  Future<Result<List<ServiceRecord>>> list(RecordFilter filter, {int offset = 0, int limit = 30}) => guard(() async {
    final (where, args) = RecordMapper.where(filter);
    final rows = await _db.reader.rawQuery(
      '${RecordMapper.details} $where ORDER BY ${RecordMapper.orderBy(filter.sort)} LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );
    return rows.map(RecordMapper.fromRow).toList();
  });

  @override
  Future<Result<RecordTotals>> totals(RecordFilter filter) => guard(() async {
    final (where, args) = RecordMapper.where(filter);
    final rows = await _db.reader.rawQuery(
      'SELECT COUNT(*) AS n, COALESCE(SUM(r.price), 0) AS revenue FROM service_records r '
      'JOIN customers c ON c.id = r.customer_id $where',
      args,
    );
    return RecordTotals(count: rows.first['n']! as int, revenuePiasters: rows.first['revenue']! as int);
  });

  @override
  Future<Result<ServiceRecord>> update(
    String id, {
    required String nurseId,
    required String serviceId,
    required Money price,
    required PaymentMethod paymentMethod,
    required DateTime serviceDate,
    required LocalTime serviceTime,
    String? patientName,
    String? notes,
  }) => guard(() async {
    await _db.write((txn) async {
      final current = await _single(txn, 'SELECT nurse_id, service_id FROM service_records WHERE id = ?', id);
      final changes = <String, Object?>{
        'price': price.piasters,
        'payment_method': paymentMethod.toJson(),
        'service_date': Dates.toJson(serviceDate),
        'service_time': serviceTime.toJson(),
        'patient_name': patientName,
        'patient_name_normalized': _normalized(patientName),
        'notes': notes,
        'updated_at': _db.timestamp(),
        'sheet_state': SheetState.changed,
      };
      // Only a newly chosen nurse/service must be active; its current name
      // becomes the record's snapshot.
      if (current['nurse_id'] != nurseId) {
        changes['nurse_id'] = nurseId;
        changes['nurse_name_snapshot'] = await _activeName(txn, 'nurses', nurseId, 'nurse_inactive');
      }
      if (current['service_id'] != serviceId) {
        changes['service_id'] = serviceId;
        changes['service_name_snapshot'] = await _activeName(txn, 'services', serviceId, 'service_inactive');
      }
      await txn.update('service_records', changes, where: 'id = ?', whereArgs: [id]);
    });
    return _get(id);
  });

  @override
  Future<VoidResult> archive(String id) => guard(() async {
    final at = _db.timestamp();
    await _db.write(
      (txn) => txn.update(
        'service_records',
        {'deleted_at': at, 'updated_at': at, 'sheet_state': SheetState.changed},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      ),
    );
  });

  static String? _normalized(String? value) => value == null ? null : TextNormalizer.key(value);

  static Future<Map<String, Object?>> _single(Transaction txn, String sql, String id) async {
    final rows = await txn.rawQuery(sql, [id]);
    if (rows.isEmpty) throw const NotFoundFailure();
    return rows.first;
  }

  static Future<String> _activeName(Transaction txn, String table, String id, String rule) async {
    final row = await _single(txn, 'SELECT name, is_active FROM $table WHERE id = ?', id);
    if (row['is_active'] != 1) throw BusinessRuleFailure(rule);
    return row['name']! as String;
  }
}
