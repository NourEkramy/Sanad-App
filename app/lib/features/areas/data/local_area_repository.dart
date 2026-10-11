import '../../../core/database/sanad_database.dart';
import '../../../core/database/sheet_state.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/text_normalizer.dart';
import '../domain/entities/area.dart';
import '../domain/repositories/area_repository.dart';

class LocalAreaRepository implements AreaRepository {
  LocalAreaRepository(this._db);

  final SanadDatabase _db;

  static Area fromRow(Map<String, Object?> row) =>
      Area(id: row['id']! as String, name: row['name']! as String, isActive: row['is_active'] == 1);

  @override
  Future<Result<List<Area>>> getAreas({bool includeInactive = false}) => guard(() async {
    final rows = await _db.reader.query('areas', where: includeInactive ? null : 'is_active = 1', orderBy: 'name');
    return rows.map(fromRow).toList();
  });

  @override
  Future<Result<Area>> createArea(String name) => guard(() async {
    final id = _db.newId();
    final at = _db.timestamp();
    await _db.write(
      (txn) => txn.insert('areas', {
        'id': id,
        'name': name,
        'name_normalized': TextNormalizer.key(name),
        'created_at': at,
        'updated_at': at,
      }),
    );
    return Area(id: id, name: name);
  });

  @override
  Future<Result<Area>> updateArea(Area area) => guard(() async {
    await _db.write(
      (txn) => txn.update(
        'areas',
        {
          'name': area.name,
          'name_normalized': TextNormalizer.key(area.name),
          'is_active': area.isActive ? 1 : 0,
          'updated_at': _db.timestamp(),
          'sheet_state': SheetState.changed,
        },
        where: 'id = ?',
        whereArgs: [area.id],
      ),
    );
    return area;
  });
}
