import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../entities/app_user.dart';

/// Authentication state as seen by the app.
sealed class AuthStatus extends Equatable {
  const AuthStatus();

  @override
  List<Object?> get props => const [];
}

final class Authenticated extends AuthStatus {
  const Authenticated(this.user);
  final AppUser user;

  @override
  List<Object?> get props => [user];
}

final class Unauthenticated extends AuthStatus {
  const Unauthenticated({this.sessionExpired = false});

  /// True when the session ended without the user signing out.
  final bool sessionExpired;

  @override
  List<Object?> get props => [sessionExpired];
}

/// The user opened a password-reset link and must choose a new password.
final class PasswordRecovery extends AuthStatus {
  const PasswordRecovery();
}

abstract interface class AuthRepository {
  /// Emits the current status immediately and then on every change.
  Stream<AuthStatus> watchStatus();

  Future<Result<AppUser>> signIn({required String email, required String password});

  Future<VoidResult> signOut();

  Future<VoidResult> sendPasswordReset(String email);

  Future<VoidResult> updatePassword(String newPassword);

  Future<Result<AppUser>> updateProfile({required String fullName});

  /// Reloads the profile (role / active flag) of the signed-in user.
  Future<Result<AppUser>> refreshCurrentUser();
}
