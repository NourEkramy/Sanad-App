import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/dates.dart';
import '../domain/dashboard.dart';

class SupabaseDashboardRepository implements DashboardRepository {
  SupabaseDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<DashboardStats>> getStats(DateTime day) => guard(() async {
    final json = await _client.rpc<Map<String, dynamic>>('dashboard_stats', params: {'for_day': Dates.toJson(day)});
    return DashboardStats.fromJson(json);
  });
}
