import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// App-wide authentication state. `null` means "not known yet" (splash).
class AuthCubit extends Cubit<AuthStatus?> {
  AuthCubit(this._repository) : super(null) {
    _subscription = _repository.watchStatus().listen(emit);
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthStatus> _subscription;

  AppUser? get user => switch (state) {
    Authenticated(:final user) => user,
    _ => null,
  };

  bool can(Permission permission) => user?.can(permission) ?? false;

  Future<void> signOut() => _repository.signOut();

  /// Applies a profile change made elsewhere (e.g. name edited).
  void userUpdated(AppUser user) {
    if (state is Authenticated) emit(Authenticated(user));
  }

  Future<void> refresh() async {
    final result = await _repository.refreshCurrentUser();
    final user = result.valueOrNull;
    if (user != null) userUpdated(user);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
