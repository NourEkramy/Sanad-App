import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../domain/entities/nurse.dart';
import '../domain/repositories/nurse_repository.dart';

class SupabaseNurseRepository implements NurseRepository {
  SupabaseNurseRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, name, phone, is_active, notes';

  static Nurse fromRow(Map<String, dynamic> row) => Nurse(
        id: row['id'] as String,
        name: row['name'] as String,
        phone: row['phone'] as String?,
        isActive: row['is_active'] as bool? ?? true,
        notes: row['notes'] as String?,
      );

  @override
  Future<Result<List<Nurse>>> getNurses({bool includeInactive = false}) => guard(() async {
        var query = _client.from('nurses').select(_columns);
        if (!includeInactive) query = query.eq('is_active', true);
        final rows = await query.order('name');
        return rows.map(fromRow).toList();
      });

  @override
  Future<Result<Nurse>> createNurse({required String name, String? phone, String? notes}) => guard(() async {
        final row = await _client
            .from('nurses')
            .insert({'name': name, 'phone': phone, 'notes': notes})
            .select(_columns)
            .single();
        return fromRow(row);
      });

  @override
  Future<Result<Nurse>> updateNurse(Nurse nurse) => guard(() async {
        final row = await _client
            .from('nurses')
            .update({'name': nurse.name, 'phone': nurse.phone, 'notes': nurse.notes, 'is_active': nurse.isActive})
            .eq('id', nurse.id)
            .select(_columns)
            .single();
        return fromRow(row);
      });
}
