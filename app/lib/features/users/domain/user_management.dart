import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/validation/validators.dart';
import '../../auth/domain/entities/app_user.dart';

abstract interface class UserRepository {
  Future<Result<List<AppUser>>> listUsers();
  Future<Result<AppUser>> setRole(String userId, UserRole role);
  Future<Result<AppUser>> setActive(String userId, {required bool active});

  /// Sends an invitation e-mail (server-side, admin only).
  Future<VoidResult> invite({required String email, required String fullName, required UserRole role});
}

class ListUsers {
  const ListUsers(this._repository);
  final UserRepository _repository;

  Future<Result<List<AppUser>>> call() => _repository.listUsers();
}

class ChangeUserAccess {
  const ChangeUserAccess(this._repository);
  final UserRepository _repository;

  /// Administrators cannot remove their own admin rights or deactivate
  /// themselves (also enforced by the database).
  Future<Result<AppUser>> call({required AppUser actor, required AppUser target, UserRole? role, bool? active}) async {
    if (!actor.can(Permission.manageUsers)) return const Result.failure(PermissionFailure());
    if (actor.id == target.id && (role == UserRole.staff || active == false)) {
      return const Result.failure(BusinessRuleFailure('self_demotion'));
    }
    if (role != null && role != target.role) return _repository.setRole(target.id, role);
    if (active != null && active != target.isActive) return _repository.setActive(target.id, active: active);
    return Result.success(target);
  }
}

class InviteUser {
  const InviteUser(this._repository);
  final UserRepository _repository;

  Future<VoidResult> call({required String email, required String fullName, required UserRole role}) async {
    final errors = <String, String>{
      'email': ?Validators.email(email),
      'fullName': ?Validators.requiredText(fullName, maxLength: 120),
    };
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));
    return _repository.invite(email: email.trim().toLowerCase(), fullName: fullName.trim(), role: role);
  }
}
