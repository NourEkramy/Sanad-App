import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../domain/entities/area.dart';
import '../domain/repositories/area_repository.dart';

class SupabaseAreaRepository implements AreaRepository {
  SupabaseAreaRepository(this._client);

  final SupabaseClient _client;

  static Area fromRow(Map<String, dynamic> row) =>
      Area(id: row['id'] as String, name: row['name'] as String, isActive: row['is_active'] as bool? ?? true);

  @override
  Future<Result<List<Area>>> getAreas({bool includeInactive = false}) => guard(() async {
    var query = _client.from('areas').select('id, name, is_active');
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('name', ascending: true);
    return rows.map(fromRow).toList();
  });

  @override
  Future<Result<Area>> createArea(String name) => guard(() async {
    final row = await _client.from('areas').insert({'name': name}).select('id, name, is_active').single();
    return fromRow(row);
  });

  @override
  Future<Result<Area>> updateArea(Area area) => guard(() async {
    final row = await _client
        .from('areas')
        .update({'name': area.name, 'is_active': area.isActive})
        .eq('id', area.id)
        .select('id, name, is_active')
        .single();
    return fromRow(row);
  });
}
