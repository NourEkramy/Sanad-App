import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../../auth/domain/entities/app_user.dart';
import '../domain/user_management.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<AppUser>>> listUsers() => guard(() async {
        final rows = await _client.from('profiles').select().order('created_at');
        return rows.map(SupabaseAuthRepository.userFromRow).toList();
      });

  @override
  Future<Result<AppUser>> setRole(String userId, UserRole role) => _update(userId, {'role': role.name});

  @override
  Future<Result<AppUser>> setActive(String userId, {required bool active}) => _update(userId, {'is_active': active});

  Future<Result<AppUser>> _update(String userId, Map<String, Object> values) => guard(() async {
        final row = await _client.from('profiles').update(values).eq('id', userId).select().single();
        return SupabaseAuthRepository.userFromRow(row);
      });

  @override
  Future<VoidResult> invite({required String email, required String fullName, required UserRole role}) =>
      guard(() async {
        await _client.functions.invoke(
          'invite-user',
          body: {'email': email, 'full_name': fullName, 'role': role.name},
        );
      });
}
