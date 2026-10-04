import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/money.dart';
import '../domain/entities/care_service.dart';
import '../domain/repositories/care_service_repository.dart';

class SupabaseCareServiceRepository implements CareServiceRepository {
  SupabaseCareServiceRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, name, default_price, is_active';

  static CareService fromRow(Map<String, dynamic> row) => CareService(
        id: row['id'] as String,
        name: row['name'] as String,
        defaultPrice: row['default_price'] == null ? null : Money.fromJson(row['default_price']),
        isActive: row['is_active'] as bool? ?? true,
      );

  @override
  Future<Result<List<CareService>>> getServices({bool includeInactive = false}) => guard(() async {
        var query = _client.from('services').select(_columns);
        if (!includeInactive) query = query.eq('is_active', true);
        final rows = await query.order('name');
        return rows.map(fromRow).toList();
      });

  @override
  Future<Result<CareService>> createService({required String name, Money? defaultPrice}) => guard(() async {
        final row = await _client
            .from('services')
            .insert({'name': name, 'default_price': defaultPrice?.toJson()})
            .select(_columns)
            .single();
        return fromRow(row);
      });

  @override
  Future<Result<CareService>> updateService(CareService service) => guard(() async {
        final row = await _client
            .from('services')
            .update({
              'name': service.name,
              'default_price': service.defaultPrice?.toJson(),
              'is_active': service.isActive,
            })
            .eq('id', service.id)
            .select(_columns)
            .single();
        return fromRow(row);
      });
}
