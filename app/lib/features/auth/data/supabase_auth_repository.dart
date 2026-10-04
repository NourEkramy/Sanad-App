import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/secure_store.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, this._store);

  final SupabaseClient _client;

  /// Caches the last known profile so the app opens offline.
  final KeyValueStore _store;
  static const _profileKey = 'sanad.auth.profile';

  bool _signingOut = false;
  bool _hadSession = false;

  static AppUser userFromRow(Map<String, dynamic> row) => AppUser(
    id: row['id'] as String,
    email: row['email'] as String? ?? '',
    fullName: row['full_name'] as String? ?? '',
    role: UserRole.fromJson(row['role'] as String?),
    isActive: row['is_active'] as bool? ?? true,
    createdAt: row['created_at'] == null ? null : DateTime.parse(row['created_at'] as String).toLocal(),
  );

  static Map<String, Object?> _toRow(AppUser u) => {
    'id': u.id,
    'email': u.email,
    'full_name': u.fullName,
    'role': u.role.name,
    'is_active': u.isActive,
  };

  Future<AppUser> _loadProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).single();
    final user = userFromRow(row);
    await _store.write(_profileKey, jsonEncode(_toRow(user)));
    return user;
  }

  Future<AppUser?> _cachedProfile(String userId) async {
    final raw = await _store.read(_profileKey);
    if (raw == null) return null;
    final user = userFromRow((jsonDecode(raw) as Map).cast<String, dynamic>());
    return user.id == userId ? user : null;
  }

  @override
  Stream<AuthStatus> watchStatus() async* {
    await for (final state in _client.auth.onAuthStateChange) {
      final session = state.session;
      switch (state.event) {
        case AuthChangeEvent.passwordRecovery:
          yield const PasswordRecovery();
        case AuthChangeEvent.signedOut:
          final expired = _hadSession && !_signingOut;
          _signingOut = false;
          _hadSession = false;
          await _store.delete(_profileKey);
          yield Unauthenticated(sessionExpired: expired);
        default:
          if (session == null) {
            yield const Unauthenticated();
            continue;
          }
          _hadSession = true;
          AppUser? user;
          try {
            user = await _loadProfile(session.user.id);
          } catch (error) {
            final failure = ErrorMapper.map(error);
            if (failure is SessionExpiredFailure) {
              yield const Unauthenticated(sessionExpired: true);
              continue;
            }
            // Offline start: fall back to the cached profile.
            user = await _cachedProfile(session.user.id);
          }
          if (user == null) {
            yield const Unauthenticated();
          } else if (!user.isActive) {
            await signOut();
          } else {
            yield Authenticated(user);
          }
      }
    }
  }

  @override
  Future<Result<AppUser>> signIn({required String email, required String password}) async {
    final result = await guard(() async {
      final response = await _client.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw const AuthFailure(AuthFailureReason.invalidCredentials);
      return _loadProfile(user.id);
    });
    if (result.valueOrNull case final user? when !user.isActive) {
      await signOut();
      return const Result.failure(AuthFailure(AuthFailureReason.accountDisabled));
    }
    return result;
  }

  @override
  Future<VoidResult> signOut() => guard(() async {
    _signingOut = true;
    await _store.delete(_profileKey);
    await _client.auth.signOut();
  });

  @override
  Future<VoidResult> sendPasswordReset(String email) => guard(() async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: Env.authRedirectUrl);
  });

  @override
  Future<VoidResult> updatePassword(String newPassword) => guard(() async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  });

  @override
  Future<Result<AppUser>> updateProfile({required String fullName}) => guard(() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    await _client.from('profiles').update({'full_name': fullName.trim()}).eq('id', id);
    return _loadProfile(id);
  });

  @override
  Future<Result<AppUser>> refreshCurrentUser() => guard(() async {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SessionExpiredFailure();
    return _loadProfile(id);
  });
}
