import '../../../core/database/sanad_database.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/text_normalizer.dart';
import '../domain/entities/nurse.dart';
import '../domain/repositories/nurse_repository.dart';

class LocalNurseRepository implements NurseRepository {
  LocalNurseRepository(this._db);

  final SanadDatabase _db;

  static Nurse fromRow(Map<String, Object?> row) => Nurse(
    id: row['id']! as String,
    name: row['name']! as String,
    phone: row['phone'] as String?,
    isActive: row['is_active'] == 1,
    notes: row['notes'] as String?,
  );

  @override
  Future<Result<List<Nurse>>> getNurses({bool includeInactive = false}) => guard(() async {
    final rows = await _db.reader.query('nurses', where: includeInactive ? null : 'is_active = 1', orderBy: 'name');
    return rows.map(fromRow).toList();
  });

  @override
  Future<Result<Nurse>> createNurse({required String name, String? phone, String? notes}) => guard(() async {
    final id = _db.newId();
    final at = _db.timestamp();
    await _db.write(
      (txn) => txn.insert('nurses', {
        'id': id,
        'name': name,
        'name_normalized': TextNormalizer.key(name),
        'phone': phone,
        'notes': notes,
        'created_at': at,
        'updated_at': at,
      }),
    );
    return Nurse(id: id, name: name, phone: phone, notes: notes);
  });

  @override
  Future<Result<Nurse>> updateNurse(Nurse nurse) => guard(() async {
    await _db.write(
      (txn) => txn.update(
        'nurses',
        {
          'name': nurse.name,
          'name_normalized': TextNormalizer.key(nurse.name),
          'phone': nurse.phone,
          'notes': nurse.notes,
          'is_active': nurse.isActive ? 1 : 0,
          'updated_at': _db.timestamp(),
        },
        where: 'id = ?',
        whereArgs: [nurse.id],
      ),
    );
    return nurse;
  });
}
