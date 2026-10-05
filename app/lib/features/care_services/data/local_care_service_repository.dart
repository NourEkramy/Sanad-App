import '../../../core/database/sanad_database.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/text_normalizer.dart';
import '../domain/entities/care_service.dart';
import '../domain/repositories/care_service_repository.dart';

class LocalCareServiceRepository implements CareServiceRepository {
  LocalCareServiceRepository(this._db);

  final SanadDatabase _db;

  static CareService fromRow(Map<String, Object?> row) => CareService(
    id: row['id']! as String,
    name: row['name']! as String,
    defaultPrice: row['default_price'] == null ? null : Money.piasters(row['default_price']! as int),
    isActive: row['is_active'] == 1,
  );

  @override
  Future<Result<List<CareService>>> getServices({bool includeInactive = false}) => guard(() async {
    final rows = await _db.reader.query('services', where: includeInactive ? null : 'is_active = 1', orderBy: 'name');
    return rows.map(fromRow).toList();
  });

  @override
  Future<Result<CareService>> createService({required String name, Money? defaultPrice}) => guard(() async {
    final id = _db.newId();
    final at = _db.timestamp();
    await _db.write(
      (txn) => txn.insert('services', {
        'id': id,
        'name': name,
        'name_normalized': TextNormalizer.key(name),
        'default_price': defaultPrice?.piasters,
        'created_at': at,
        'updated_at': at,
      }),
    );
    return CareService(id: id, name: name, defaultPrice: defaultPrice);
  });

  /// Changing the default price only affects new records: every record keeps
  /// the price it was saved with.
  @override
  Future<Result<CareService>> updateService(CareService service) => guard(() async {
    await _db.write(
      (txn) => txn.update(
        'services',
        {
          'name': service.name,
          'name_normalized': TextNormalizer.key(service.name),
          'default_price': service.defaultPrice?.piasters,
          'is_active': service.isActive ? 1 : 0,
          'updated_at': _db.timestamp(),
        },
        where: 'id = ?',
        whereArgs: [service.id],
      ),
    );
    return service;
  });
}
