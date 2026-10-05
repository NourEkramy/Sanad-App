import '../../../core/database/sanad_database.dart';
import '../../../core/database/sql.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/text_normalizer.dart';
import '../domain/entities/customer.dart';
import '../domain/repositories/customer_repository.dart';

class LocalCustomerRepository implements CustomerRepository {
  LocalCustomerRepository(this._db);

  final SanadDatabase _db;

  /// A customer with area name, number of visits and last visit date.
  static const overview = '''
    SELECT c.*, a.name AS area_name,
           (SELECT COUNT(*) FROM service_records r WHERE r.customer_id = c.id AND r.deleted_at IS NULL) AS record_count,
           (SELECT MAX(r.service_date) FROM service_records r
             WHERE r.customer_id = c.id AND r.deleted_at IS NULL) AS last_service_date
      FROM customers c
      JOIN areas a ON a.id = c.area_id''';

  static Customer fromRow(Map<String, Object?> row) => Customer(
    id: row['id']! as String,
    fullName: row['full_name']! as String,
    phone: row['phone'] as String?,
    address: row['address'] as String?,
    areaId: row['area_id']! as String,
    areaName: row['area_name'] as String? ?? '',
    notes: row['notes'] as String?,
    needsReview: row['needs_review'] == 1,
    isArchived: row['deleted_at'] != null,
    createdAt: DateTime.parse(row['created_at']! as String).toLocal(),
    recordCount: row['record_count'] as int? ?? 0,
    lastServiceDate: row['last_service_date'] == null ? null : DateTime.parse(row['last_service_date']! as String),
  );

  /// Phone-first search: a query made of digits matches the phone (prefix
  /// first, then anywhere once 4 digits are typed); anything else matches
  /// the normalised name.
  @override
  Future<Result<List<Customer>>> search(String query, {int limit = 20}) => guard(() async {
    final q = query.trim();
    if (q.isEmpty) return const <Customer>[];
    final lim = limit.clamp(1, 50);
    final digits = Sql.phoneQuery(q);
    if (digits != null) {
      final rows = await _db.reader.rawQuery(
        '$overview WHERE c.deleted_at IS NULL AND (c.phone LIKE ? OR (? >= 4 AND c.phone LIKE ?)) '
        'ORDER BY (c.phone = ?) DESC, (c.phone LIKE ?) DESC, c.phone LIMIT ?',
        ['$digits%', digits.length, '%$digits%', digits, '$digits%', lim],
      );
      return rows.map(fromRow).toList();
    }
    final rows = await _db.reader.rawQuery(
      "$overview WHERE c.deleted_at IS NULL AND c.name_normalized LIKE ? ESCAPE '\\' ORDER BY c.full_name LIMIT ?",
      [Sql.contains(TextNormalizer.key(q)), lim],
    );
    return rows.map(fromRow).toList();
  });

  @override
  Future<Result<Customer?>> findByPhone(String normalizedPhone) => guard(() async {
    final rows = await _db.reader.rawQuery('$overview WHERE c.phone = ?', [normalizedPhone]);
    return rows.isEmpty ? null : fromRow(rows.first);
  });

  @override
  Future<Result<Customer>> getById(String id) => guard(() => _get(id));

  Future<Customer> _get(String id) async {
    final rows = await _db.reader.rawQuery('$overview WHERE c.id = ?', [id]);
    if (rows.isEmpty) throw const NotFoundFailure();
    return fromRow(rows.first);
  }

  @override
  Future<Result<List<Customer>>> list({int offset = 0, int limit = 30, String? areaId, bool needsReviewOnly = false}) =>
      guard(() async {
        final rows = await _db.reader.rawQuery(
          '$overview WHERE c.deleted_at IS NULL'
          '${areaId != null ? ' AND c.area_id = ?' : ''}'
          '${needsReviewOnly ? ' AND c.needs_review = 1' : ''}'
          ' ORDER BY c.created_at DESC LIMIT ? OFFSET ?',
          [?areaId, limit, offset],
        );
        return rows.map(fromRow).toList();
      });

  @override
  Future<Result<Customer>> create({
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  }) => guard(() async {
    final id = _db.newId();
    final at = _db.timestamp();
    await _db.write(
      (txn) => txn.insert('customers', {
        'id': id,
        'full_name': fullName,
        'name_normalized': TextNormalizer.key(fullName),
        'phone': phone,
        'area_id': areaId,
        'address': address,
        'notes': notes,
        'created_at': at,
        'updated_at': at,
      }),
    );
    return _get(id);
  });

  @override
  Future<Result<Customer>> update(
    String id, {
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  }) => guard(() async {
    final changed = await _db.write(
      (txn) => txn.update(
        'customers',
        {
          'full_name': fullName,
          'name_normalized': TextNormalizer.key(fullName),
          'phone': phone,
          'area_id': areaId,
          'address': address,
          'notes': notes,
          // A corrected legacy customer no longer needs review.
          'needs_review': 0,
          'updated_at': _db.timestamp(),
        },
        where: 'id = ?',
        whereArgs: [id],
      ),
    );
    if (changed == 0) throw const NotFoundFailure();
    return _get(id);
  });

  @override
  Future<VoidResult> setArchived(String id, {required bool archived}) => guard(() async {
    final at = _db.timestamp();
    await _db.write(
      (txn) => txn.update(
        'customers',
        {'deleted_at': archived ? at : null, 'updated_at': at},
        where: 'id = ?',
        whereArgs: [id],
      ),
    );
  });
}
